// Copyright 2012 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_FIRST_RUN_FIRST_RUN_METRICS_H_
#define IOS_CHROME_BROWSER_FIRST_RUN_FIRST_RUN_METRICS_H_

@protocol FirstRunMetricsDelegate
// A callback function to whichever object is keeping track of whether
// a user has attempted to sign in during First Run Sign-in flow.
- (void)setSignInAttempted;
@end

namespace first_run {

// The different ways to interact with the sign-in flow during First Run.
enum SignInAttemptStatus {
  // The user did not attempt to sign in.
  NOT_ATTEMPTED,
  // The user attempted to sign in.
  ATTEMPTED,
  // Sign-in was not shown because it was disabled by policy.
  SKIPPED_BY_POLICY,
  // Sign-in is not supported (Chromium).
  NOT_SUPPORTED,
};

// The different First Run Chrome Login outcomes for users. This is mapped to
// the FirstRunSignInResult enum in enums.xml for metrics.
enum SignInStatus {
  // User skipped sign in by clicking on Skip at the first opportunity.
  SIGNIN_SKIPPED_QUICK,
  // User signed in to Chrome successfully at First Run.
  SIGNIN_SUCCESSFUL,
  // User attempted to sign in, but gave up by clicking on Skip after trying.
  SIGNIN_SKIPPED_GIVEUP,
  // SSO account exists and user skipped sign in by clicking on Skip at the
  // first opportunity.
  HAS_SSO_ACCOUNT_SIGNIN_SKIPPED_QUICK,
  // SSO account exists and user signed in to Chrome successfully at First Run.
  HAS_SSO_ACCOUNT_SIGNIN_SUCCESSFUL,
  // SSO account exists and user attempted to sign in, but gave up by clicking
  // on Skip after trying.
  HAS_SSO_ACCOUNT_SIGNIN_SKIPPED_GIVEUP,
  // Sentinel file marks the successful completion of First Run. This records
  // the cases where sentinel creation failed. In most likelihood, user will
  // go through First Run again at the next launch - deprecated.
  SENTINEL_CREATION_FAILED,
  // Sign-in was skipped because it is disabled by policy.
  SIGNIN_SKIPPED_POLICY,
  // Sign-in is not supported (Chromium).
  SIGNIN_NOT_SUPPORTED,
  // Number of First Run states.
  SIGNIN_SIZE
};

// Starting with iOS 6, Mobile Safari supports Smart App Banners which
// can direct users into AppStore to download another app and then launches
// the freshly installed app. This UMA histogram tracks the number of
// Chrome application launched for the first time (First Run) as the
// result of -openURL: call by another application. Note that there is no
// 100%-sure way of telling if a launch is due to Smart App Banners.
enum ExternalLaunch {
  // Chrome was launched for the first time from Mobile Safari and there is
  // sufficient evidence (e.g. via URL parameters) that it was the result of
  // a Smart App Banner.
  LAUNCH_BY_SMARTAPPBANNER,
  // Chrome was launched for the first time from Mobile Safari, but there is
  // not sufficient indicator to show that it was launched as a result of a
  // click on Smart App Banner.
  LAUNCH_BY_MOBILESAFARI,
  // Chrome was launch for the first time by some other applications.
  LAUNCH_BY_OTHERS,
  // Number of ways that Chrome was launched for the first time.
  LAUNCH_SIZE
};

// The different stages of the first run experience. This is mapped to the
// FirstRunStageResult enum in enums.xml for metrics.
// TODO(crbug.com/1189815): Add welcome stage and record metrics.
enum FirstRunStage {
  // The first run experience has started.
  kStart = 0,
  // The first run experience has completed.
  kComplete = 1,
  // Sync screen is shown.
  kSyncScreenStart = 2,
  // Sync screen is closed with sync.
  kSyncScreenCompletionWithSync = 3,
  // Sync screen is closed without sync.
  kSyncScreenCompletionWithoutSync = 4,
  // Sync screen is closed when user taps on advance sync settings button.
  // Deprecated. This is not used anymore.
  kSyncScreenCompletionWithSyncSettings = 5,
  // SignIn screen is shown.
  kSignInScreenStart = 6,
  // SignIn screen is closed with sign in.
  kSignInScreenCompletionWithSignIn = 7,
  // SignIn screen is closed without sign in.
  kSignInScreenCompletionWithoutSignIn = 8,
  // Default browser screen is shown.
  kDefaultBrowserScreenStart = 9,
  // Default browser screen is closed with opening Settings.app.
  kDefaultBrowserScreenCompletionWithSettings = 10,
  // Default browser screen is closed without opening Settings.app.
  kDefaultBrowserScreenCompletionWithoutSettings = 11,
  // Welcome+SignIn screen is shown.
  kWelcomeAndSigninScreenStart = 12,
  // Welcome+SignIn screen is closed with sign in.
  kWelcomeAndSigninScreenCompletionWithSignIn = 13,
  // Welcome+SignIn screen is closed without sign in.
  kWelcomeAndSigninScreenCompletionWithoutSignIn = 14,
  // Max value of the first run experience stages.
  // kMaxValue should share the value of the highest enumerator.
  kMaxValue = kWelcomeAndSigninScreenCompletionWithoutSignIn,
};

// The different type of screens of the first run experience. This is mapped to
// the variants of the metric IOS.FirstRun.ScrollButtonVisible.* in of
// `tools/metrics/histograms/metadata/ios/histograms.xml`.
enum FirstRunScreenType {
  // The new FRE screen that instructs the user to set default browser to
  // Chrome.
  kDefaultBrowserPromoScreen,
  // The screen that asks the user to sign in when no stored account is
  // detected, with a footer shown at the bottom. Displayed when MICe is enabled
  // without the welcome screen (2-steps MICe FRE), or when forced sign-in is
  // enabled.
  kSignInScreenWithFooter,
  // The screen that asks the user to sign in a stored account, with a footer
  // shown at the bottom. Displayed when MICe is enabled without the welcome
  // screen (2-steps MICe FRE), or when forced sign-in is enabled.
  kSignInScreenWithFooterAndIdentityPicker,
  // The screen that asks the user to sign in a stored account, but with no
  // footer shown at the bottom. Displayed when MICe is enabled with the welcome
  // screen (3-steps MICe FRE).
  kSignInScreenWithIdentityPicker,
  // The screen that asks the user to sign in when no stored account is
  // detected, but with no footer shown at the bottom. Displayed when MICe is
  // enabled with the welcome screen (3-steps MICe FRE).
  kSignInScreenWithoutFooterOrIdentityPicker,
  // The screen that asks the user to turn on sync while no account picker is
  // present. Displayed when MICe is enabled or when no account is detected.
  kSyncScreenWithoutIdentityPicker,
  // The screen that asks the user to turn on sync while showing an account
  // picker. Displayed when MICe is disabled and an account is detected.
  kSyncScreenWithIdentityPicker,
  // Welcome screen without UMA checkbox. Displayed when MICe is enabled.
  kWelcomeScreenWithoutUMACheckbox,
  // Welcome screen with UMA checkbox. Displayed when MICe is disabled.
  kWelcomeScreenWithUMACheckbox,
};

}  // namespace first_run

#endif  // IOS_CHROME_BROWSER_FIRST_RUN_FIRST_RUN_METRICS_H_
