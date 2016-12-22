// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/metrics/first_user_action_recorder.h"

#include "base/bind.h"
#include "base/location.h"
#include "base/metrics/histogram.h"
#include "base/strings/string_util.h"
#include "base/strings/stringprintf.h"
#include "base/threading/thread_task_runner_handle.h"
#include "ios/chrome/browser/ui/ui_util.h"
#include "ios/web/public/web_thread.h"

const char* kFirstUserActionNewTaskHistogramName[] = {
    "FirstUserAction.BackgroundTimeNewTaskHandset",
    "FirstUserAction.BackgroundTimeNewTaskTablet",
};
const char* kFirstUserActionContinuationHistogramName[] = {
    "FirstUserAction.BackgroundTimeContinuationHandset",
    "FirstUserAction.BackgroundTimeContinuationTablet",
};
const char* kFirstUserActionExpirationHistogramName[] = {
    "FirstUserAction.BackgroundTimeExpirationHandset",
    "FirstUserAction.BackgroundTimeExpirationTablet",
};
const char* kFirstUserActionTypeHistogramName[] = {
    "FirstUserAction.HandsetUserActionType",
    "FirstUserAction.TabletUserActionType",
};

namespace {
// A list of actions that don't provide information about the user starting a
// task or continuing an existing task.
const char* kIgnoredActions[] = {
    "MobileOmniboxUse",
    "MobileBreakpadUploadAttempt",
    "MobileFirstUserAction_Continuation",
    "MobileFirstUserAction_Expiration",
    "MobileFirstUserAction_NewTask",
    "MobileMenuCloseAllTabs",
    "MobileMenuCloseAllIncognitoTabs",
    "MobileMenuCloseTab",
    "MobileNewTabOpened",
    "MobileTabClosed",
    "MobileTabStripCloseTab",
    "MobilePageLoaded",
    "MobilePageLoadedWithKeyboard",
    "MobileStackViewCloseTab",
    "MobileToolbarShowMenu",
    "MobileToolbarShowStackView",
};

// A list of actions that should be 'rethrown' because subsequent actions may
// be more indicative of the first user action type. 'Rethrowing' an action
// puts a call to OnUserAction in the message queue so it is processed after
// any other actions currently in the message queue.
const char* kRethrownActions[] = {
    "MobileTabSwitched",
};

// A list of actions that indicate a new task has been started.
const char* kNewTaskActions[] = {
    "MobileMenuAllBookmarks",     "MobileMenuHistory",
    "MobileMenuNewIncognitoTab",  "MobileMenuNewTab",
    "MobileMenuOpenTabs",         "MobileMenuVoiceSearch",
    "MobileNTPBookmark",          "MobileNTPForeignSession",
    "MobileNTPMostVisited",       "MobileNTPShowBookmarks",
    "MobileNTPShowMostVisited",   "MobileNTPShowOpenTabs",
    "MobileNTPSwitchToBookmarks", "MobileNTPSwitchToMostVisited",
    "MobileNTPSwitchToOpenTabs",  "MobileTabStripNewTab",
    "MobileToolbarNewTab",        "MobileToolbarStackViewNewTab",
    "MobileToolbarVoiceSearch",   "OmniboxInputInProgress",
};

// Min and max values (in minutes) for the buckets in the duration histograms.
const int kDurationHistogramMin = 5;
const int kDurationHistogramMax = 48 * 60;

// Number of buckets in the duration histograms.
const int kDurationHistogramBucketCount = 50;

}  // namespace

FirstUserActionRecorder::FirstUserActionRecorder(
    base::TimeDelta background_duration)
    : device_family_(IsIPadIdiom() ? TABLET : HANDSET),
      recorded_action_(false),
      action_pending_(false),
      background_duration_(background_duration),
      action_callback_(base::Bind(&FirstUserActionRecorder::OnUserAction,
                                  base::Unretained(this))) {
  base::AddActionCallback(action_callback_);
}

FirstUserActionRecorder::~FirstUserActionRecorder() {
  base::RemoveActionCallback(action_callback_);
}

void FirstUserActionRecorder::Expire() {
  std::string log_message = "Recording 'Expiration' for first user action type";
  RecordAction(EXPIRATION, log_message);
}

void FirstUserActionRecorder::RecordStartOnNTP() {
  std::string log_message =
      "Recording 'Start on NTP' for first user action type";
  RecordAction(START_ON_NTP, log_message);
}

void FirstUserActionRecorder::OnUserAction(const std::string& action_name) {
  if (ShouldProcessAction(action_name)) {
    if (ArrayContainsString(kNewTaskActions, arraysize(kNewTaskActions),
                            action_name.c_str())) {
      std::string log_message = base::StringPrintf(
          "Recording 'New task' for first user action type"
          " (user action: %s)",
          action_name.c_str());
      RecordAction(NEW_TASK, log_message);
    } else {
      std::string log_message = base::StringPrintf(
          "Recording 'Continuation' for first user action "
          " type (user action: %s)",
          action_name.c_str());
      RecordAction(CONTINUATION, log_message);
    }
  }
}

void FirstUserActionRecorder::RecordAction(
    const FirstUserActionType& action_type,
    const std::string& log_message) {
  if (!recorded_action_) {
    DVLOG(1) << log_message
             << " (background duration: " << background_duration_.InMinutes()
             << " minutes)";
    UMA_HISTOGRAM_ENUMERATION(kFirstUserActionTypeHistogramName[device_family_],
                              action_type, FIRST_USER_ACTION_TYPE_COUNT);
    recorded_action_ = true;
    switch (action_type) {
      case NEW_TASK:
        UMA_HISTOGRAM_CUSTOM_COUNTS(
            kFirstUserActionNewTaskHistogramName[device_family_],
            background_duration_.InMinutes(), kDurationHistogramMin,
            kDurationHistogramMax, kDurationHistogramBucketCount);
        break;
      case CONTINUATION:
        UMA_HISTOGRAM_CUSTOM_COUNTS(
            kFirstUserActionContinuationHistogramName[device_family_],
            background_duration_.InMinutes(), kDurationHistogramMin,
            kDurationHistogramMax, kDurationHistogramBucketCount);
        break;
      case EXPIRATION:
        UMA_HISTOGRAM_CUSTOM_COUNTS(
            kFirstUserActionExpirationHistogramName[device_family_],
            background_duration_.InMinutes(), kDurationHistogramMin,
            kDurationHistogramMax, kDurationHistogramBucketCount);
        break;
      case START_ON_NTP:
        break;
      default:
        NOTREACHED();
        break;
    }
  }
}

bool FirstUserActionRecorder::ShouldProcessAction(
    const std::string& action_name) {
  if (recorded_action_)
    return false;

  if (!action_pending_ &&
      ArrayContainsString(kRethrownActions, arraysize(kRethrownActions),
                          action_name.c_str())) {
    base::ThreadTaskRunnerHandle::Get()->PostTask(
        FROM_HERE, base::Bind(&FirstUserActionRecorder::OnUserAction,
                              base::Unretained(this), action_name));
    action_pending_ = true;
    return false;
  }

  // Processed actions must either start with 'Mobile' or be in the
  // |new_task_actions_| whitelist.
  bool known_mobile_action =
      base::StartsWith(action_name, "Mobile", base::CompareCase::SENSITIVE) ||
      ArrayContainsString(kNewTaskActions, arraysize(kNewTaskActions),
                          action_name.c_str());

  return known_mobile_action &&
         !ArrayContainsString(kIgnoredActions, arraysize(kIgnoredActions),
                              action_name.c_str());
}

bool FirstUserActionRecorder::ArrayContainsString(const char* to_search[],
                                                  const size_t to_search_size,
                                                  const char* to_find) {
  for (size_t i = 0; i < to_search_size; ++i) {
    if (strcmp(to_find, to_search[i]) == 0)
      return true;
  }
  return false;
}
