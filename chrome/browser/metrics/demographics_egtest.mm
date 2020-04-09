// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/macros.h"
#import "base/test/ios/wait_util.h"
#include "base/time/default_clock.h"
#include "base/time/default_tick_clock.h"
#include "base/time/time.h"
#include "components/metrics/demographic_metrics_provider.h"
#include "components/ukm/ukm_service.h"
#import "ios/chrome/browser/metrics/metrics_app_interface.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey_ui.h"
#import "ios/chrome/browser/ui/authentication/signin_earlgrey_utils.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/app_launch_configuration.h"
#import "ios/testing/earl_grey/earl_grey_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

const int kTestBirthYear = 1990;

// TODO(crbug.com/1066910): Use a proto instead.
// Corresponds to GENDER_MALE in UserDemographicsProto::Gender.
const int kTestGender = 1;

}  // namespace

@interface DemographicsTestCase : ChromeTestCase
@end

@implementation DemographicsTestCase

- (void)setUp {
  [super setUp];
  GREYAssertNil([MetricsAppInterface setupHistogramTester],
                @"Failed to set up histogram tester.");
  [MetricsAppInterface overrideMetricsAndCrashReportingForTesting];
  [self addUserDemographicsToSyncServerWithBirthYear:kTestBirthYear
                                              gender:kTestGender];
  [self signInAndSync];
  [self grantMetricsConsent];

  // Set a network time so that SyncPrefs::GetUserNoisedBirthYearAndGender
  // does not return a UserDemographicsResult for the kCannotGetTime status.
  [MetricsAppInterface setNetworkTimeForTesting];
}

- (void)tearDown {
  [ChromeEarlGrey clearSyncServerData];
  [MetricsAppInterface stopOverridingMetricsAndCrashReportingForTesting];
  GREYAssertNil([MetricsAppInterface releaseHistogramTester],
                @"Failed to release histogram tester.");
  [super tearDown];
}

#if defined(CHROME_EARL_GREY_2)
- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config;

  // Features are enabled or disabled based on the name of the test that is
  // running. This is done because (A) parameterized tests do not exist in Earl
  // Grey and (B) it is inefficient to use ensureAppLaunchedWithConfiguration
  // for each test.
  //
  // Note that in the if statements, @selector(testSomething) is used rather
  // than @"testSomething" because the former checks that the testSomething
  // method exists somewhere--but not necessarily in this class.
  if ([self isRunningTest:@selector
            (testUKMDemographicsReportingWithFeatureEnabled)]) {
    config.features_enabled.push_back(
        metrics::DemographicMetricsProvider::kDemographicMetricsReporting);
    config.features_enabled.push_back(
        ukm::UkmService::kReportUserNoisedUserBirthYearAndGender);
  } else if ([self isRunningTest:@selector
                   (testUKMDemographicsReportingWithFeatureDisabled)]) {
    config.features_disabled.push_back(
        metrics::DemographicMetricsProvider::kDemographicMetricsReporting);
    config.features_disabled.push_back(
        ukm::UkmService::kReportUserNoisedUserBirthYearAndGender);
  } else if ([self isRunningTest:@selector
                   (testUMADemographicsReportingWithFeatureEnabled)]) {
    config.features_enabled.push_back(
        metrics::DemographicMetricsProvider::kDemographicMetricsReporting);
  } else if ([self isRunningTest:@selector
                   (testUMADemographicsReportingWithFeatureDisabled)]) {
    config.features_disabled.push_back(
        metrics::DemographicMetricsProvider::kDemographicMetricsReporting);
  }
  return config;
}
#endif  // defined(CHROME_EARL_GREY_2)

#pragma mark - Helpers

// Returns YES if the test method name extracted from |selector| matches the
// name of the currently running test method.
- (BOOL)isRunningTest:(SEL)selector {
  return [[self curentTestMethodName] isEqual:NSStringFromSelector(selector)];
}

// Adds user demographics, which are ModelType::PRIORITY_PREFERENCES, to the
// fake sync server. |rawBirthYear| is the true birth year, pre-noise, and the
// gender corresponds to the options in UserDemographicsProto::Gender.
//
// Also, verifies (A) that before adding the demographics, the server has no
// priority preferences and (B) that after adding the demographics, the server
// has one priority preference.
- (void)addUserDemographicsToSyncServerWithBirthYear:(int)rawBirthYear
                                              gender:(int)gender {
  GREYAssertEqual(
      [ChromeEarlGrey
          numberOfSyncEntitiesWithType:syncer::PRIORITY_PREFERENCES],
      0, @"The fake sync server should have no priority preferences.");

  [ChromeEarlGrey addUserDemographicsToSyncServerWithBirthYear:rawBirthYear
                                                        gender:gender];

  GREYAssertEqual(
      [ChromeEarlGrey
          numberOfSyncEntitiesWithType:syncer::PRIORITY_PREFERENCES],
      1, @"The fake sync server should have one priority preference.");
}

// Signs into Chrome with a fake identity, turns on sync, and then waits up to
// kSyncUKMOperationsTimeout for sync to initialize.
- (void)signInAndSync {
  // Note that there is only one profile on iOS. Additionally, URL-keyed
  // anonymized data collection is turned on as part of the flow to Sign in to
  // Chrome and Turn on sync. This matches the main user flow that enables
  // UKM.
  [SigninEarlGreyUI signinWithFakeIdentity:[SigninEarlGreyUtils fakeIdentity1]];
  [ChromeEarlGrey waitForSyncInitialized:YES
                             syncTimeout:syncher::kSyncUKMOperationsTimeout];
}

// Adds a dummy UKM source to the UKM service's recordings. The presence of this
// dummy source allows UKM reports to be built and logged.
- (void)addDummyUKMSource {
  const uint64_t sourceId = 0x54321;
  [MetricsAppInterface UKMRecordDummySource:sourceId];
  GREYAssert([MetricsAppInterface UKMHasDummySource:sourceId],
             @"Failed to record dummy source.");
}

// Turns on metrics collection for testing and verifies that this has been
// successfully done.
- (void)grantMetricsConsent {
  GREYAssertFalse(
      [MetricsAppInterface setMetricsAndCrashReportingForTesting:YES],
      @"User consent has already been granted.");
  GREYAssert([MetricsAppInterface checkUKMRecordingEnabled:YES],
             @"Failed to assert that UKM recording is enabled.");

  // The client ID is non-zero after metrics uploading permissions are updated.
  GREYAssertNotEqual(0U, [MetricsAppInterface UKMClientID],
                     @"Client ID should be non-zero.");
}

// Returns the method name, e.g. "testSomething" of the test that is currently
// running. The name is extracted from the string for the test's name property,
// e.g. "-[DemographicsTestCase testSomething]".
- (NSString*)curentTestMethodName {
  int testNameStart = [self.name rangeOfString:@"test"].location;
  return [self.name
      substringWithRange:NSMakeRange(testNameStart,
                                     self.name.length - testNameStart - 1)];
}

// Adds dummy data,  stores it in the UKM service's UnsentLogStore, and verifies
// that the UnsentLogStore has an unsent log.
- (void)buildAndStoreUKMLog {
  // Record a source in the UKM service so that there is data with which to
  // generate a UKM Report.
  [self addDummyUKMSource];
  [MetricsAppInterface buildAndStoreUKMLog];
  GREYAssertTrue([MetricsAppInterface hasUnsentUKMLogs],
                 @"The UKM service should have unsent logs.");
}

#pragma mark - Tests

// The tests in this file should correspond to the demographics-related tests in
// //chrome/browser/metrics/ukm_browsertest.cc and
// //chrome/browser/metrics/metrics_service_user_demographics_browsertest.cc.

// Tests that user demographics are synced, recorded by UKM, and logged in
// histograms.
//
// Corresponds to AddSyncedUserBirthYearAndGenderToProtoData in
// //chrome/browser/metrics/ukm_browsertest.cc with features enabled.
#if defined(CHROME_EARL_GREY_2)
- (void)testUKMDemographicsReportingWithFeatureEnabled {
  // See |appConfigurationForTestCase| for feature set-up. The kUkmFeature is
  // enabled by default.
  GREYAssertTrue([ChromeEarlGrey isDemographicMetricsReportingEnabled] &&
                     [MetricsAppInterface
                         isReportUserNoisedUserBirthYearAndGenderEnabled] &&
                     [ChromeEarlGrey isUKMEnabled],
                 @"Failed to enable the requisite features.");

  [self buildAndStoreUKMLog];

  GREYAssertTrue([MetricsAppInterface UKMReportHasBirthYear:kTestBirthYear
                                                     gender:kTestGender],
                 @"The report should contain the specified user demographics");

  const int success =
      static_cast<int>(syncer::UserDemographicsStatus::kSuccess);
  GREYAssertNil([MetricsAppInterface
                    expectUniqueSampleWithCount:1
                                      forBucket:success
                                   forHistogram:@"UKM.UserDemographics.Status"],
                @"Unexpected histogram contents");
}
#endif  // defined(CHROME_EARL_GREY_2)

// Tests that user demographics are neither recorded by UKM nor logged in
// histograms when sync is turned on.
//
// Corresponds to AddSyncedUserBirthYearAndGenderToProtoData in
// //chrome/browser/metrics/ukm_browsertest.cc with features disabled.
#if defined(CHROME_EARL_GREY_2)
- (void)testUKMDemographicsReportingWithFeatureDisabled {
  // See |appConfigurationForTestCase| for feature set-up. The kUkmFeature is
  // enabled by default.
  GREYAssertFalse([ChromeEarlGrey isDemographicMetricsReportingEnabled],
                  @"Failed to disable kDemographicMetricsReporting.");
  GREYAssertFalse(
      [MetricsAppInterface isReportUserNoisedUserBirthYearAndGenderEnabled],
      @"Failed to disable kReportUserNoisedUserBirthYearAndGender.");
  GREYAssertTrue([ChromeEarlGrey isUKMEnabled],
                 @"Failed to enable kUkmFeature.");

  [self buildAndStoreUKMLog];

  GREYAssertFalse([MetricsAppInterface UKMReportHasUserDemographics],
                  @"The report should not contain user demographics.");
  GREYAssertNil([MetricsAppInterface expectSum:0
                                  forHistogram:@"UKM.UserDemographics.Status"],
                @"Unexpected histogram contents.");
}
#endif  // defined(CHROME_EARL_GREY_2)

// Tests that user demographics are synced, recorded by UMA, and logged in
// histograms.
//
// Corresponds to AddSyncedUserBirthYearAndGenderToProtoData in
// //chrome/browser/metrics/metrics_service_user_demographics_browsertest.cc
// with features enabled.
#if defined(CHROME_EARL_GREY_2)
- (void)testUMADemographicsReportingWithFeatureEnabled {
  // See |appConfigurationForTestCase| for feature set-up. The kUkmFeature is
  // enabled by default.
  GREYAssertTrue([ChromeEarlGrey isDemographicMetricsReportingEnabled],
                 @"Failed to enable kDemographicMetricsReporting.");

  [MetricsAppInterface buildAndStoreUMALog];
  GREYAssertTrue([MetricsAppInterface hasUnsentUMALogs],
                 @"The UKM service should have unsent logs.");

  GREYAssertTrue([MetricsAppInterface UMALogHasBirthYear:kTestBirthYear
                                                  gender:kTestGender],
                 @"The report should contain the specified user demographics");

  const int success =
      static_cast<int>(syncer::UserDemographicsStatus::kSuccess);
  GREYAssertNil([MetricsAppInterface
                    expectUniqueSampleWithCount:1
                                      forBucket:success
                                   forHistogram:@"UMA.UserDemographics.Status"],
                @"Unexpected histogram contents");
}
#endif  // defined(CHROME_EARL_GREY_2)

// Tests that user demographics are neither recorded by UMA nor logged in
// histograms when sync is turned on.
//
// Corresponds to AddSyncedUserBirthYearAndGenderToProtoData in
// //chrome/browser/metrics/metrics_service_user_demographics_browsertest.cc
// with features disabled.
#if defined(CHROME_EARL_GREY_2)
- (void)testUMADemographicsReportingWithFeatureDisabled {
  // See |appConfigurationForTestCase| for feature set-up.
  GREYAssertFalse([ChromeEarlGrey isDemographicMetricsReportingEnabled],
                  @"Failed to disable kDemographicMetricsReporting.");

  [MetricsAppInterface buildAndStoreUMALog];
  GREYAssertTrue([MetricsAppInterface hasUnsentUMALogs],
                 @"The UKM service should have unsent logs.");

  GREYAssertNil([MetricsAppInterface expectSum:0
                                  forHistogram:@"UMA.UserDemographics.Status"],
                @"Unexpected histogram contents.");
}
#endif  // defined(CHROME_EARL_GREY_2)

@end
