// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/app/feed_app_agent.h"

#import <BackgroundTasks/BackgroundTasks.h>
#import <UserNotifications/UserNotifications.h>

#import "ios/chrome/app/application_delegate/app_state.h"
#import "ios/chrome/browser/discover_feed/discover_feed_service.h"
#import "ios/chrome/browser/discover_feed/discover_feed_service_factory.h"
#import "ios/chrome/browser/discover_feed/feed_constants.h"
#import "ios/chrome/browser/ntp/features.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation FeedAppAgent

#pragma mark - AppStateObserver

- (void)appState:(AppState*)appState
    didTransitionFromInitStage:(InitStage)previousInitStage {
  if (appState.initStage == InitStageBrowserBasic) {
    // Apple docs say that background tasks must be registered before the
    // end of `application:didFinishLaunchingWithOptions:`.
    // InitStageBrowserBasic fulfills that requirement.
    [self maybeRegisterBackgroundRefreshTask];
    // This is a provisional permission, which does not prompt the user at this
    // point.
    [self maybeRequestUserNotificationPermissions];
  } else if (appState.initStage ==
             InitStageBrowserObjectsForBackgroundHandlers) {
    // Save the value of the feature flag now since 'base::FeatureList' was
    // not available in `InitStageBrowserBasic`.
    // IsFeedBackgroundRefreshEnabled() simply reads the saved value saved by
    // SaveFeedBackgroundRefreshEnabledForNextColdStart(). Do not wrap this in
    // IsFeedBackgroundRefreshEnabled() -- in this case, a new value would
    // never be saved again once we save NO, since the NO codepath would not
    // execute saving a new value.
    SaveFeedBackgroundRefreshEnabledForNextColdStart();
  } else if (appState.initStage == InitStageNormalUI &&
             IsWebChannelsEnabled()) {
    // Starting the DiscoverFeedService is required before users are able to
    // interact with any tab because following a web channel (part of the
    // Following Feed feature which depends on the DiscoverFeedService) is
    // available on any tab, and not just the NTP where the Following Feed
    // lives. This line is intended to crash if DiscoverFeedService is not able
    // to be instantiated here.
    DiscoverFeedServiceFactory::GetForBrowserState(
        self.appState.mainBrowserState);
  }
  [super appState:appState didTransitionFromInitStage:previousInitStage];
}

#pragma mark - SceneObservingAppAgent

- (void)appDidEnterBackground {
  if (IsFeedBackgroundRefreshEnabled()) {
    [self scheduleBackgroundRefresh];
  }
}

- (void)appDidEnterForeground {
  if (IsFeedBackgroundRefreshEnabled()) {
    // This is not strictly necessary, but it makes it more explicit. The OS
    // limits to 1 refresh task at any time, and a new request will replace a
    // previous request. Tasks are only executed in the background.
    // TODO(crbug.com/1344866): Coordinate background tasks when more are added.
    [BGTaskScheduler.sharedScheduler cancelAllTaskRequests];
  }
}

#pragma mark - Helpers

// Returns the DiscoverFeedService.
- (DiscoverFeedService*)feedService {
  // DiscoverFeedService is expected to be available since the startup sequence
  // should create background objects before this method is called. This line is
  // intended to crash if DiscoverFeedService is not available.
  return DiscoverFeedServiceFactory::GetForBrowserState(
      self.appState.mainBrowserState);
}

// Registers handler for the background refresh task. According to
// documentation, this must complete before the end of
// `applicationDidFinishLaunching`.
- (void)maybeRegisterBackgroundRefreshTask {
  if (!IsFeedBackgroundRefreshEnabled()) {
    return;
  }
  __weak FeedAppAgent* weakSelf = self;
  [BGTaskScheduler.sharedScheduler
      registerForTaskWithIdentifier:kFeedBackgroundRefreshTaskIdentifier
                         usingQueue:nil
                      launchHandler:^(BGTask* task) {
                        [weakSelf handleBackgroundRefreshTask:task];
                      }];
}

// Schedules a background refresh task with an earliest begin date in the
// future. The OS limits to 1 refresh task at any time, and a new request will
// replace a previous request. Tasks are only executed in the background.
// TODO(crbug.com/1343695): It is critically important that we do not schedule
// other background fetch tasks (e.g., with other identifiers) anywhere,
// including other files. The OS only allows one fetch task at a time.
// Eventually, background fetches should be managed by a central manager.
- (void)scheduleBackgroundRefresh {
  // Do not DCHECK IsFeedBackgroundRefreshEnabled() because this is also called
  // from the background task handler, and the value could have changed during a
  // cold start.
  if (!IsFeedBackgroundRefreshEnabled()) {
    return;
  }
  BGAppRefreshTaskRequest* request = [[BGAppRefreshTaskRequest alloc]
      initWithIdentifier:kFeedBackgroundRefreshTaskIdentifier];
  request.earliestBeginDate = [self earliestBackgroundRefreshBeginDate];
  // Error in scheduling is intentionally not handled since the fallback is that
  // the user will just refresh in the foreground.
  // TODO(crbug.com/1343695): Consider logging error in histogram.
  [BGTaskScheduler.sharedScheduler submitTaskRequest:request error:nil];
}

// Returns the earliest begin date to set on the refresh task. Either returns a
// date from DiscoverFeedService or an override date created with the override
// interval in Experimental Settings.
- (NSDate*)earliestBackgroundRefreshBeginDate {
  NSDate* earliestBeginDate = nil;
  NSTimeInterval intervalOverride =
      GetBackgroundRefreshIntervalOverrideInSeconds();
  if (intervalOverride > 0) {
    earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:intervalOverride];
  } else {
    // This is expected to crash if FeedService is not available.
    earliestBeginDate =
        [self feedService]->GetEarliestBackgroundRefreshBeginDate();
  }
  return earliestBeginDate;
}

// This method is called when the app is in the background.
- (void)handleBackgroundRefreshTask:(BGTask*)task {
  // Do not DCHECK IsFeedBackgroundRefreshEnabled() because the value could have
  // changed during a cold start.
  if (!IsFeedBackgroundRefreshEnabled()) {
    return;
  }
  if (IsRecurringBackgroundRefreshScheduleEnabled()) {
    [self scheduleBackgroundRefresh];
  }
  task.expirationHandler = ^{
    // This is expected to crash if FeedService is not available.
    [self feedService]->HandleBackgroundRefreshTaskExpiration();
    [self maybeNotifyRefreshSuccess:NO];
  };
  if (IsAttemptFeedBackgroundRefreshEnabled()) {
    // This is expected to crash if FeedService is not available.
    [self feedService]->PerformBackgroundRefreshes(^(BOOL success) {
      [self maybeNotifyRefreshSuccess:success];
      [task setTaskCompletedWithSuccess:success];
    });
  } else {
    [self maybeNotifyFetchTriggered];
    [task setTaskCompletedWithSuccess:YES];
  }
}

#pragma mark - Non-release only - Refresh Completion Notifications

// Request provisional permission, which does not explicitly prompt the user for
// permission. Instead, the OS delivers provisional notifications quietly and
// are visible in the notification center's history. For active debugging, the
// tester can go to the Settings App and turn on full permissions for banners
// and sounds.
- (void)maybeRequestUserNotificationPermissions {
  if (!IsFeedBackgroundRefreshCompletedNotificationEnabled()) {
    return;
  }
  UNUserNotificationCenter* center =
      UNUserNotificationCenter.currentNotificationCenter;
  [center requestAuthorizationWithOptions:(UNAuthorizationOptionProvisional |
                                           UNAuthorizationOptionAlert |
                                           UNAuthorizationOptionSound)
                        completionHandler:^(BOOL granted, NSError* error){
                        }];
}

// Requests OS to send a local user notification with `title`.
- (void)maybeRequestNotification:(NSString*)title {
  if (!IsFeedBackgroundRefreshCompletedNotificationEnabled()) {
    return;
  }
  UNMutableNotificationContent* content =
      [[UNMutableNotificationContent alloc] init];
  content.title = title;
  content.body = @"This is compiled only into non-release versions.";
  UNTimeIntervalNotificationTrigger* trigger =
      [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:(1)
                                                         repeats:NO];
  UNNotificationRequest* request =
      [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                           content:content
                                           trigger:trigger];
  UNUserNotificationCenter* center =
      UNUserNotificationCenter.currentNotificationCenter;
  [center addNotificationRequest:request withCompletionHandler:nil];
}

// Requests OS to send a local user notification when a background fetch is
// triggered, but an actual feed refresh is not attempted.
- (void)maybeNotifyFetchTriggered {
  // Disable triggering notification if actual refresh attempt is enabled so
  // that user doesn't get unnecessary notifications.
  if (IsAttemptFeedBackgroundRefreshEnabled()) {
    return;
  }
  [self maybeRequestNotification:@"Background Fetch Triggered"];
}

// Requests OS to send a local user notification that a feed refresh has been
// attempted in the background. The notification title says 'success' or
// 'failure' based on `success`.
- (void)maybeNotifyRefreshSuccess:(BOOL)success {
  NSString* title = nil;
  if (success) {
    title = @"Feed Bg Refresh Success";
  } else {
    title = @"Feed Bg Refresh Failure";
  }
  [self maybeRequestNotification:title];
}

@end
