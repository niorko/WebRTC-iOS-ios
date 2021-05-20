// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/app/application_delegate/user_activity_handler.h"

#include <memory>

#import <CoreSpotlight/CoreSpotlight.h>

#include "base/memory/ptr_util.h"
#include "base/strings/stringprintf.h"
#include "base/strings/sys_string_conversions.h"
#include "base/test/scoped_command_line.h"
#import "base/test/task_environment.h"
#include "components/handoff/handoff_utility.h"
#import "ios/chrome/app/app_startup_parameters.h"
#import "ios/chrome/app/application_delegate/app_state_observer.h"
#include "ios/chrome/app/application_delegate/fake_startup_information.h"
#include "ios/chrome/app/application_delegate/mock_tab_opener.h"
#include "ios/chrome/app/application_delegate/startup_information.h"
#include "ios/chrome/app/application_delegate/tab_opening.h"
#include "ios/chrome/app/application_mode.h"
#import "ios/chrome/app/intents/OpenInChromeIncognitoIntent.h"
#import "ios/chrome/app/intents/OpenInChromeIntent.h"
#include "ios/chrome/app/main_controller.h"
#include "ios/chrome/app/spotlight/actions_spotlight_manager.h"
#import "ios/chrome/app/spotlight/spotlight_util.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/chrome_switches.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/main/browser_list.h"
#import "ios/chrome/browser/main/browser_list_factory.h"
#import "ios/chrome/browser/main/test_browser.h"
#import "ios/chrome/browser/u2f/u2f_tab_helper.h"
#import "ios/chrome/browser/ui/main/connection_information.h"
#import "ios/chrome/browser/ui/main/test/fake_connection_information.h"
#import "ios/chrome/browser/ui/main/test/stub_browser_interface_provider.h"
#import "ios/chrome/browser/url_loading/url_loading_params.h"
#import "ios/chrome/browser/web/tab_id_tab_helper.h"
#import "ios/chrome/browser/web_state_list/fake_web_state_list_delegate.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/browser/web_state_list/web_state_opener.h"
#import "ios/testing/scoped_block_swizzler.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "net/base/mac/url_conversions.h"
#include "net/test/gtest_util.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"
#include "ui/base/page_transition_types.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Override readonly property for testing.
@interface NSUserActivity (IntentsTesting)
@property(readwrite, nullable, NS_NONATOMIC_IOSONLY) INInteraction* interaction;
@end

// Substitutes U2FTabHelper for testing.
class FakeU2FTabHelper : public U2FTabHelper {
 public:
  static void CreateForWebState(web::WebState* web_state) {
    web_state->SetUserData(U2FTabHelper::UserDataKey(),
                           base::WrapUnique(new FakeU2FTabHelper(web_state)));
  }

  void EvaluateU2FResult(const GURL& url) override { url_ = url; }

  const GURL& url() const { return url_; }

 private:
  FakeU2FTabHelper(web::WebState* web_state) : U2FTabHelper(web_state) {}
  GURL url_;
  DISALLOW_COPY_AND_ASSIGN(FakeU2FTabHelper);
};

#pragma mark - Test class.

// A block that takes as arguments the caller and the arguments from
// UserActivityHandler +handleStartupParameters and returns nothing.
typedef void (^startupParameterBlock)(id,
                                      id<TabOpening>,
                                      id<StartupInformation>,
                                      id<BrowserInterfaceProvider>);

// A block that takes a BOOL argument and returns nothing.
typedef void (^conditionBlock)(BOOL);

class UserActivityHandlerTest : public PlatformTest {
 public:
  UserActivityHandlerTest() {
    interfaceProvider_ = [[StubBrowserInterfaceProvider alloc] init];
  }

 protected:
  void swizzleHandleStartupParameters() {
    handle_startup_parameters_has_been_called_ = NO;
    swizzle_block_ = [^(id self) {
      handle_startup_parameters_has_been_called_ = YES;
    } copy];
    user_activity_handler_swizzler_.reset(new ScopedBlockSwizzler(
        [UserActivityHandler class],
        @selector(handleStartupParametersWithTabOpener:
                                 connectionInformation:startupInformation
                                                      :browserState:initStage:),
        swizzle_block_));
  }

  BOOL getHandleStartupParametersHasBeenCalled() {
    return handle_startup_parameters_has_been_called_;
  }

  void resetHandleStartupParametersHasBeenCalled() {
    handle_startup_parameters_has_been_called_ = NO;
  }

  FakeU2FTabHelper* GetU2FTabHelperForWebState(web::WebState* web_state) {
    return static_cast<FakeU2FTabHelper*>(
        U2FTabHelper::FromWebState(web_state));
  }

  NSString* GetTabIdForWebState(web::WebState* web_state) {
    return TabIdTabHelper::FromWebState(web_state)->tab_id();
  }

  conditionBlock getCompletionHandler() {
    if (!completion_block_) {
      block_executed_ = NO;
      completion_block_ = [^(BOOL arg) {
        block_executed_ = YES;
        block_argument_ = arg;
      } copy];
    }
    return completion_block_;
  }

  BOOL completionHandlerExecuted() { return block_executed_; }

  BOOL completionHandlerArgument() { return block_argument_; }

  StubBrowserInterfaceProvider* GetInterfaceProvider() {
    return interfaceProvider_;
  }

 private:
  __block BOOL block_executed_;
  __block BOOL block_argument_;
  std::unique_ptr<ScopedBlockSwizzler> user_activity_handler_swizzler_;
  startupParameterBlock swizzle_block_;
  conditionBlock completion_block_;
  __block BOOL handle_startup_parameters_has_been_called_;
  StubBrowserInterfaceProvider* interfaceProvider_;
};

#pragma mark - Tests.

// Tests that Chrome notifies the user if we are passing a correct
// userActivityType.
TEST_F(UserActivityHandlerTest, WillContinueUserActivityCorrectActivity) {
  EXPECT_TRUE([UserActivityHandler
      willContinueUserActivityWithType:handoff::kChromeHandoffActivityType]);

  if (spotlight::IsSpotlightAvailable()) {
    EXPECT_TRUE([UserActivityHandler
        willContinueUserActivityWithType:CSSearchableItemActionType]);
  }
}

// Tests that Chrome does not notifies the user if we are passing an incorrect
// userActivityType.
TEST_F(UserActivityHandlerTest, WillContinueUserActivityIncorrectActivity) {
  EXPECT_FALSE([UserActivityHandler
      willContinueUserActivityWithType:[handoff::kChromeHandoffActivityType
                                           stringByAppendingString:@"test"]]);

  EXPECT_FALSE([UserActivityHandler
      willContinueUserActivityWithType:@"it.does.not.work"]);

  EXPECT_FALSE([UserActivityHandler willContinueUserActivityWithType:@""]);

  EXPECT_FALSE([UserActivityHandler willContinueUserActivityWithType:nil]);
}

// Tests that Chrome does not continue the activity is the activity type is
// random.
TEST_F(UserActivityHandlerTest, ContinueUserActivityFromGarbage) {
  // Setup.
  NSString* handoffWithSuffix =
      [handoff::kChromeHandoffActivityType stringByAppendingString:@"test"];
  NSString* handoffWithPrefix =
      [@"test" stringByAppendingString:handoff::kChromeHandoffActivityType];
  NSArray* userActivityTypes = @[
    @"thisIsGarbage", @"it.does.not.work", handoffWithSuffix, handoffWithPrefix
  ];
  for (NSString* userActivityType in userActivityTypes) {
    NSUserActivity* userActivity =
        [[NSUserActivity alloc] initWithActivityType:userActivityType];
    [userActivity setWebpageURL:[NSURL URLWithString:@"http://www.google.com"]];

    // The test will fail is a method of those objects is called.
    id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];
    id startupInformationMock =
        [OCMockObject mockForProtocol:@protocol(StartupInformation)];
    id connectionInformation =
        [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];

    // Action.
    BOOL result = [UserActivityHandler
         continueUserActivity:userActivity
          applicationIsActive:NO
                    tabOpener:tabOpenerMock
        connectionInformation:connectionInformation
           startupInformation:startupInformationMock
                 browserState:GetInterfaceProvider()
                                  .currentInterface.browserState
                    initStage:InitStageFinal];

    // Tests.
    EXPECT_FALSE(result);
  }
}

// Tests that Chrome does not continue the activity if the webpage url is not
// set.
TEST_F(UserActivityHandlerTest, ContinueUserActivityNoWebpage) {
  // Setup.
  NSUserActivity* userActivity = [[NSUserActivity alloc]
      initWithActivityType:handoff::kChromeHandoffActivityType];

  // The test will fail is a method of those objects is called.
  id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];
  id connectionInformationMock =
      [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
  id startupInformationMock =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];

  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:NO
                  tabOpener:tabOpenerMock
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  // Tests.
  EXPECT_FALSE(result);
}

// Tests that Chrome does not continue the activity if the activity is a
// Spotlight action of an unknown type.
TEST_F(UserActivityHandlerTest,
       ContinueUserActivitySpotlightActionFromGarbage) {
  // Only test Spotlight if it is enabled and available on the device.
  if (!spotlight::IsSpotlightAvailable()) {
    return;
  }
  // Setup.
  NSUserActivity* userActivity =
      [[NSUserActivity alloc] initWithActivityType:CSSearchableItemActionType];
  NSString* invalidAction =
      [NSString stringWithFormat:@"%@.invalidAction",
                                 spotlight::StringFromSpotlightDomain(
                                     spotlight::DOMAIN_ACTIONS)];
  NSDictionary* userInfo =
      @{CSSearchableItemActivityIdentifier : invalidAction};
  [userActivity addUserInfoEntriesFromDictionary:userInfo];

  // Enable the SpotlightActions experiment.
  base::test::ScopedCommandLine scoped_command_line;
  scoped_command_line.GetProcessCommandLine()->AppendSwitch(
      switches::kEnableSpotlightActions);

  id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];
  id startupInformationMock =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];
  id connectionInformationMock =
      [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:NO
                  tabOpener:tabOpenerMock
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  // Tests.
  EXPECT_FALSE(result);
}

// Tests that Chrome continues the activity if the application is in background
// by saving the url to startupParameters.
TEST_F(UserActivityHandlerTest, ContinueUserActivityBackground) {
  // Setup.
  NSUserActivity* userActivity = [[NSUserActivity alloc]
      initWithActivityType:handoff::kChromeHandoffActivityType];
  NSURL* nsurl = [NSURL URLWithString:@"http://www.google.com"];
  [userActivity setWebpageURL:nsurl];

  id startupInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(StartupInformation)];
  id connectionInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(ConnectionInformation)];
  [[connectionInformationMock expect]
      setStartupParameters:[OCMArg checkWithBlock:^BOOL(id value) {
        EXPECT_TRUE([value isKindOfClass:[AppStartupParameters class]]);

        AppStartupParameters* startupParameters = (AppStartupParameters*)value;
        const GURL calledURL = startupParameters.externalURL;
        return calledURL == net::GURLWithNSURL(nsurl);
      }]];

  // The test will fail is a method of this object is called.
  id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];

  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:NO
                  tabOpener:tabOpenerMock
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  // Test.
  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  EXPECT_TRUE(result);
}

// Tests that Chrome continues the activity if the application is in foreground
// by opening a new tab.
TEST_F(UserActivityHandlerTest, ContinueUserActivityForeground) {
  // Setup.
  NSUserActivity* userActivity = [[NSUserActivity alloc]
      initWithActivityType:handoff::kChromeHandoffActivityType];
  GURL gurl("http://www.google.com");
  [userActivity setWebpageURL:net::NSURLWithGURL(gurl)];

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  id startupInformationMock =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];

  id connectionInformationMock =
      [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
  AppStartupParameters* startupParams =
      [[AppStartupParameters alloc] initWithExternalURL:gurl completeURL:gurl];
  [[[connectionInformationMock stub] andReturn:startupParams]
      startupParameters];

  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:YES
                  tabOpener:tabOpener
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  // Test.
  EXPECT_EQ(gurl, tabOpener.urlLoadParams.web_params.url);
  EXPECT_TRUE(tabOpener.urlLoadParams.web_params.virtual_url.is_empty());
  EXPECT_TRUE(result);
}

// Tests that a new tab is created when application is started via handoff.
TEST_F(UserActivityHandlerTest, ContinueUserActivityBrowsingWeb) {
  NSUserActivity* userActivity = [[NSUserActivity alloc]
      initWithActivityType:NSUserActivityTypeBrowsingWeb];
  // This URL is passed to application by iOS but is not used in this part
  // of application logic.
  NSURL* nsurl = [NSURL URLWithString:@"http://goo.gl/foo/bar"];
  [userActivity setWebpageURL:nsurl];

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  // Use an object to capture the startup paramters set by UserActivityHandler.
  FakeStartupInformation* fakeStartupInformation =
      [[FakeStartupInformation alloc] init];
  FakeConnectionInformation* connectionInformationMock =
      [[FakeConnectionInformation alloc] init];

  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:YES
                  tabOpener:tabOpener
      connectionInformation:connectionInformationMock
         startupInformation:fakeStartupInformation
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  const GURL gurl = net::GURLWithNSURL(nsurl);
  EXPECT_EQ(gurl, tabOpener.urlLoadParams.web_params.url);
  EXPECT_TRUE(tabOpener.urlLoadParams.web_params.virtual_url.is_empty());
  // AppStartupParameters default to opening pages in non-Incognito mode.
  EXPECT_EQ(ApplicationModeForTabOpening::NORMAL, [tabOpener applicationMode]);
  EXPECT_TRUE(result);
}

// Tests that continueUserActivity sets startupParameters accordingly to the
// Spotlight action used.
TEST_F(UserActivityHandlerTest, ContinueUserActivityShortcutActions) {
  // Only test Spotlight if it is enabled and available on the device.
  if (!spotlight::IsSpotlightAvailable()) {
    return;
  }
  // Setup.
  GURL gurlNewTab(kChromeUINewTabURL);
  FakeStartupInformation* fakeStartupInformation =
      [[FakeStartupInformation alloc] init];
  FakeConnectionInformation* connectionInformationMock =
      [[FakeConnectionInformation alloc] init];

  NSArray* parametersToTest = @[
    @[
      base::SysUTF8ToNSString(spotlight::kSpotlightActionNewTab), @(NO_ACTION)
    ],
    @[
      base::SysUTF8ToNSString(spotlight::kSpotlightActionNewIncognitoTab),
      @(NO_ACTION)
    ],
    @[
      base::SysUTF8ToNSString(spotlight::kSpotlightActionVoiceSearch),
      @(START_VOICE_SEARCH)
    ],
    @[
      base::SysUTF8ToNSString(spotlight::kSpotlightActionQRScanner),
      @(START_QR_CODE_SCANNER)
    ]
  ];

  // Enable the Spotlight Actions experiment.
  base::test::ScopedCommandLine scoped_command_line;
  scoped_command_line.GetProcessCommandLine()->AppendSwitch(
      switches::kEnableSpotlightActions);

  for (id parameters in parametersToTest) {
    NSUserActivity* userActivity = [[NSUserActivity alloc]
        initWithActivityType:CSSearchableItemActionType];
    NSString* action = [NSString
        stringWithFormat:@"%@.%@", spotlight::StringFromSpotlightDomain(
                                       spotlight::DOMAIN_ACTIONS),
                         parameters[0]];
    NSDictionary* userInfo = @{CSSearchableItemActivityIdentifier : action};
    [userActivity addUserInfoEntriesFromDictionary:userInfo];

    id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];

    // Action.
    BOOL result = [UserActivityHandler
         continueUserActivity:userActivity
          applicationIsActive:NO
                    tabOpener:tabOpenerMock
        connectionInformation:connectionInformationMock
           startupInformation:fakeStartupInformation
                 browserState:GetInterfaceProvider()
                                  .currentInterface.browserState
                    initStage:InitStageFinal];

    // Tests.
    EXPECT_TRUE(result);
    EXPECT_EQ(gurlNewTab,
              [connectionInformationMock startupParameters].externalURL);
    EXPECT_EQ([parameters[1] intValue],
              [connectionInformationMock startupParameters].postOpeningAction);
  }
}

// Tests that Chrome responds to open in incognito intent in the background
TEST_F(UserActivityHandlerTest, ContinueUserActivityIntentIncognitoBackground) {
  NSURL* url1 = [[NSURL alloc] initWithString:@"http://www.google.com"];
  NSURL* url2 = [[NSURL alloc] initWithString:@"http://www.apple.com"];
  NSURL* url3 = [[NSURL alloc] initWithString:@"http://www.espn.com"];
  NSArray<NSURL*>* urls = [NSArray arrayWithObjects:url1, url2, url3, nil];

  NSUserActivity* userActivity = [[NSUserActivity alloc]
      initWithActivityType:@"OpenInChromeIncognitoIntent"];

  OpenInChromeIncognitoIntent* intent =
      [[OpenInChromeIncognitoIntent alloc] init];

  intent.url = urls;

  INInteraction* interaction = [[INInteraction alloc] initWithIntent:intent
                                                            response:nil];

  userActivity.interaction = interaction;

  id startupInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(StartupInformation)];

  id connectionInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(ConnectionInformation)];

  [[connectionInformationMock expect]
      setStartupParameters:[OCMArg checkWithBlock:^BOOL(id value) {
        EXPECT_TRUE([value isKindOfClass:[AppStartupParameters class]] ||
                    value == nil);

        if (value != nil) {
          AppStartupParameters* startupParameters =
              (AppStartupParameters*)value;
          const GURL calledURL = startupParameters.externalURL;
          EXPECT_TRUE((int)[intent.url count] == 3);
          return [intent.url containsObject:(net::NSURLWithGURL(calledURL))];
        } else {
          return YES;
        }
      }]];

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:NO
                  tabOpener:tabOpener
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  EXPECT_TRUE(result);
}

// Tests that Chrome responds to open intents in the background.
TEST_F(UserActivityHandlerTest, ContinueUserActivityIntentBackground) {
  NSUserActivity* userActivity =
      [[NSUserActivity alloc] initWithActivityType:@"OpenInChromeIntent"];
  OpenInChromeIntent* intent = [[OpenInChromeIntent alloc] init];

  NSURL* url1 = [[NSURL alloc] initWithString:@"http://www.google.com"];
  NSURL* url2 = [[NSURL alloc] initWithString:@"http://www.apple.com"];
  NSURL* url3 = [[NSURL alloc] initWithString:@"http://www.espn.com"];
  NSArray<NSURL*>* urls = [NSArray arrayWithObjects:url1, url2, url3, nil];

  intent.url = urls;
  INInteraction* interaction = [[INInteraction alloc] initWithIntent:intent
                                                            response:nil];
  userActivity.interaction = interaction;

  id startupInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(StartupInformation)];
  id connectionInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(ConnectionInformation)];

  [[connectionInformationMock expect]
      setStartupParameters:[OCMArg checkWithBlock:^BOOL(id value) {
        EXPECT_TRUE([value isKindOfClass:[AppStartupParameters class]] ||
                    value == nil);

        if (value != nil) {
          AppStartupParameters* startupParameters =
              (AppStartupParameters*)value;
          const GURL calledURL = startupParameters.externalURL;
          EXPECT_TRUE((int)[intent.url count] == 3);
          return [intent.url containsObject:(net::NSURLWithGURL(calledURL))];
        } else {
          return YES;
        }
      }]];

  // The test will fail if a method of this object is called.
  id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];

  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:NO
                  tabOpener:tabOpenerMock
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  // Test.
  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  EXPECT_TRUE(result);
}

// Test that Chrome respond to open in incognito intent in the foreground.
TEST_F(UserActivityHandlerTest, ContinueUserActivityIntentIncognitoForeground) {
  NSURL* url1 = [[NSURL alloc] initWithString:@"http://www.google.com"];
  NSURL* url2 = [[NSURL alloc] initWithString:@"http://www.apple.com"];
  NSURL* url3 = [[NSURL alloc] initWithString:@"http://www.espn.com"];
  NSArray<NSURL*>* urls = [NSArray arrayWithObjects:url1, url2, url3, nil];

  NSUserActivity* userActivity = [[NSUserActivity alloc]
      initWithActivityType:@"OpenInChromeIncognitoIntent"];

  OpenInChromeIncognitoIntent* intent =
      [[OpenInChromeIncognitoIntent alloc] init];

  intent.url = urls;

  INInteraction* interaction = [[INInteraction alloc] initWithIntent:intent
                                                            response:nil];

  userActivity.interaction = interaction;

  id startupInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(StartupInformation)];

  id connectionInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(ConnectionInformation)];

  [[connectionInformationMock expect]
      setStartupParameters:[OCMArg checkWithBlock:^BOOL(id value) {
        EXPECT_TRUE([value isKindOfClass:[AppStartupParameters class]] ||
                    value == nil);

        if (value != nil) {
          AppStartupParameters* startupParameters =
              (AppStartupParameters*)value;
          const GURL calledURL = startupParameters.externalURL;
          EXPECT_TRUE((int)[intent.url count] == 3);
          return [intent.url containsObject:(net::NSURLWithGURL(calledURL))];
        } else {
          return YES;
        }
      }]];


  std::vector<GURL> URLs;
  for (NSURL* URL in urls) {
    URLs.push_back(net::GURLWithNSURL(URL));
  }

  AppStartupParameters* startupParams =
      [[AppStartupParameters alloc] initWithURLs:URLs];
  [[[connectionInformationMock stub] andReturn:startupParams]
      startupParameters];

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:YES
                  tabOpener:tabOpener
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  // Test.
  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  EXPECT_TRUE(result);
  EXPECT_EQ(3U, tabOpener.URLs.size());
}

// Tests that Chrome responds to open intents in the foreground.
TEST_F(UserActivityHandlerTest, ContinueUserActivityIntentForeground) {
  NSUserActivity* userActivity =
      [[NSUserActivity alloc] initWithActivityType:@"OpenInChromeIntent"];
  OpenInChromeIntent* intent = [[OpenInChromeIntent alloc] init];
  NSURL* url1 = [[NSURL alloc] initWithString:@"http://www.google.com"];
  NSURL* url2 = [[NSURL alloc] initWithString:@"http://www.apple.com"];
  NSURL* url3 = [[NSURL alloc] initWithString:@"http://www.espn.com"];
  NSArray<NSURL*>* urls = [NSArray arrayWithObjects:url1, url2, url3, nil];

  intent.url = urls;
  INInteraction* interaction = [[INInteraction alloc] initWithIntent:intent
                                                            response:nil];
  userActivity.interaction = interaction;

  id startupInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(StartupInformation)];

  id connectionInformationMock =
      [OCMockObject niceMockForProtocol:@protocol(ConnectionInformation)];

  [[connectionInformationMock expect]
      setStartupParameters:[OCMArg checkWithBlock:^BOOL(id value) {
        EXPECT_TRUE([value isKindOfClass:[AppStartupParameters class]] ||
                    value == nil);

        if (value != nil) {
          AppStartupParameters* startupParameters =
              (AppStartupParameters*)value;
          const GURL calledURL = startupParameters.externalURL;
          EXPECT_TRUE((int)[intent.url count] == 3);
          return [intent.url containsObject:(net::NSURLWithGURL(calledURL))];
        } else {
          return YES;
        }
      }]];

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  std::vector<GURL> URLs;
  for (NSURL* URL in urls) {
    URLs.push_back(net::GURLWithNSURL(URL));
  }

  AppStartupParameters* startupParams =
      [[AppStartupParameters alloc] initWithURLs:URLs];
  [[[connectionInformationMock stub] andReturn:startupParams]
      startupParameters];

  // Action.
  BOOL result = [UserActivityHandler
       continueUserActivity:userActivity
        applicationIsActive:YES
                  tabOpener:tabOpener
      connectionInformation:connectionInformationMock
         startupInformation:startupInformationMock
               browserState:GetInterfaceProvider().currentInterface.browserState
                  initStage:InitStageFinal];

  // Test.
  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  EXPECT_TRUE(result);
  EXPECT_EQ(3U, tabOpener.URLs.size());
}

// Tests that handleStartupParameters with a file url. "external URL" gets
// rewritten to chrome://URL, while "complete URL" remains full local file URL.
TEST_F(UserActivityHandlerTest, HandleStartupParamsWithExternalFile) {
  // Setup.
  GURL externalURL("chrome://test.pdf");
  GURL completeURL("file://test.pdf");

  AppStartupParameters* startupParams =
      [[AppStartupParameters alloc] initWithExternalURL:externalURL
                                            completeURL:completeURL];
  [startupParams setLaunchInIncognito:YES];

  id startupInformationMock =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];

  id connectionInformationMock =
      [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
  [[[connectionInformationMock stub] andReturn:startupParams]
      startupParameters];
  [[connectionInformationMock expect] setStartupParameters:nil];
  [[[connectionInformationMock expect] andReturnValue:@NO]
      startupParametersAreBeingHandled];
  [[connectionInformationMock expect] setStartupParametersAreBeingHandled:YES];

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  // The test will fail is a method of this object is called.
  //  id interfaceProviderMock =
  //      [OCMockObject mockForProtocol:@protocol(BrowserInterfaceProvider)];

  // Action.
  [UserActivityHandler
      handleStartupParametersWithTabOpener:tabOpener
                     connectionInformation:connectionInformationMock
                        startupInformation:startupInformationMock
                              browserState:GetInterfaceProvider()
                                               .currentInterface.browserState
                                 initStage:InitStageFinal];
  [tabOpener completionBlock]();

  // Tests.
  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  // External file:// URL will be loaded by WebState, which expects complete
  // file:// URL. chrome:// URL is expected to be displayed in the omnibox,
  // and omnibox shows virtual URL.
  EXPECT_EQ(completeURL, tabOpener.urlLoadParams.web_params.url);
  EXPECT_EQ(externalURL, tabOpener.urlLoadParams.web_params.virtual_url);
  EXPECT_EQ(ApplicationModeForTabOpening::INCOGNITO,
            [tabOpener applicationMode]);
}

// Tests that handleStartupParameters with a non-U2F url opens a new tab.
TEST_F(UserActivityHandlerTest, HandleStartupParamsNonU2F) {
  // Setup.
  GURL gurl("http://www.google.com");

  AppStartupParameters* startupParams =
      [[AppStartupParameters alloc] initWithExternalURL:gurl completeURL:gurl];
  [startupParams setLaunchInIncognito:YES];

  id startupInformationMock =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];

  id connectionInformationMock =
      [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
  [[[connectionInformationMock stub] andReturn:startupParams]
      startupParameters];
  [[[connectionInformationMock expect] andReturnValue:@NO]
      startupParametersAreBeingHandled];
  [[connectionInformationMock expect] setStartupParametersAreBeingHandled:YES];
  [[connectionInformationMock expect] setStartupParameters:nil];

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  // The test will fail is a method of this object is called.
  //  id interfaceProviderMock =
  //      [OCMockObject mockForProtocol:@protocol(BrowserInterfaceProvider)];

  // Action.
  [UserActivityHandler
      handleStartupParametersWithTabOpener:tabOpener
                     connectionInformation:connectionInformationMock
                        startupInformation:startupInformationMock
                              browserState:GetInterfaceProvider()
                                               .currentInterface.browserState
                                 initStage:InitStageFinal];
  [tabOpener completionBlock]();

  // Tests.
  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  EXPECT_EQ(gurl, tabOpener.urlLoadParams.web_params.url);
  EXPECT_TRUE(tabOpener.urlLoadParams.web_params.virtual_url.is_empty());
  EXPECT_EQ(ApplicationModeForTabOpening::INCOGNITO,
            [tabOpener applicationMode]);
}

// Tests that handleStartupParameters with a U2F url opens in the correct tab.
TEST_F(UserActivityHandlerTest, HandleStartupParamsU2F) {
  // Setup.
  base::test::TaskEnvironment task_enviroment_;

  TestChromeBrowserState::Builder test_cbs_builder;
  std::unique_ptr<ChromeBrowserState> browser_state_ = test_cbs_builder.Build();

  FakeWebStateListDelegate _webStateListDelegate;
  std::unique_ptr<WebStateList> web_state_list_ =
      std::make_unique<WebStateList>(&_webStateListDelegate);

  auto web_state = std::make_unique<web::FakeWebState>();
  TabIdTabHelper::CreateForWebState(web_state.get());
  FakeU2FTabHelper::CreateForWebState(web_state.get());
  web::WebState* web_state_ptr = web_state.get();
  web_state_list_->InsertWebState(
      0, std::move(web_state), WebStateList::INSERT_NO_FLAGS, WebStateOpener());

  std::unique_ptr<Browser> browser_ = std::make_unique<TestBrowser>(
      browser_state_.get(), web_state_list_.get());
  std::unique_ptr<Browser> otr_browser_ = std::make_unique<TestBrowser>(
      browser_state_->GetOffTheRecordChromeBrowserState(),
      web_state_list_.get());

  BrowserList* browser_list_ =
      BrowserListFactory::GetForBrowserState(browser_state_.get());
  browser_list_->AddBrowser(browser_.get());

  std::string urlRepresentation = base::StringPrintf(
      "chromium://u2f-callback?isU2F=1&tabID=%s",
      base::SysNSStringToUTF8(GetTabIdForWebState(web_state_ptr)).c_str());

  GURL gurl(urlRepresentation);
  AppStartupParameters* startupParams =
      [[AppStartupParameters alloc] initWithExternalURL:gurl completeURL:gurl];
  [startupParams setLaunchInIncognito:YES];

  id startupInformationMock =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];
  id connectionInformationMock =
      [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
  [[[connectionInformationMock stub] andReturn:startupParams]
      startupParameters];
  [[[connectionInformationMock expect] andReturnValue:@NO]
      startupParametersAreBeingHandled];
  [[connectionInformationMock expect] setStartupParametersAreBeingHandled:YES];
  [[connectionInformationMock expect] setStartupParameters:nil];

  StubBrowserInterfaceProvider* interfaceProvider =
      [[StubBrowserInterfaceProvider alloc] init];
  interfaceProvider.mainInterface.browserState = browser_state_.get();
  interfaceProvider.incognitoInterface.browserState =
      browser_state_->GetOffTheRecordChromeBrowserState();

  MockTabOpener* tabOpener = [[MockTabOpener alloc] init];

  // Action.
  [UserActivityHandler
      handleStartupParametersWithTabOpener:tabOpener
                     connectionInformation:connectionInformationMock
                        startupInformation:startupInformationMock
                              browserState:interfaceProvider.currentInterface
                                               .browserState
                                 initStage:InitStageFinal];

  // Tests.
  EXPECT_OCMOCK_VERIFY(startupInformationMock);
  EXPECT_EQ(gurl, GetU2FTabHelperForWebState(web_state_ptr)->url());
  EXPECT_TRUE(tabOpener.urlLoadParams.web_params.url.is_empty());
  EXPECT_TRUE(tabOpener.urlLoadParams.web_params.virtual_url.is_empty());
}

// Tests that performActionForShortcutItem set startupParameters accordingly to
// the shortcut used
// TODO(crbug.com/1172529): The test fails on device.
#if TARGET_IPHONE_SIMULATOR
#define MAYBE_PerformActionForShortcutItemWithRealShortcut \
  PerformActionForShortcutItemWithRealShortcut
#else
#define MAYBE_PerformActionForShortcutItemWithRealShortcut \
  DISABLED_PerformActionForShortcutItemWithRealShortcut
#endif
TEST_F(UserActivityHandlerTest,
       MAYBE_PerformActionForShortcutItemWithRealShortcut) {
  // Setup.
  GURL gurlNewTab("chrome://newtab/");

  FakeStartupInformation* fakeStartupInformation =
      [[FakeStartupInformation alloc] init];

  FakeConnectionInformation* fakeConnectionInformation =
      [[FakeConnectionInformation alloc] init];

  NSArray* parametersToTest = @[
    @[ @"OpenNewSearch", @NO, @(FOCUS_OMNIBOX) ],
    @[ @"OpenIncognitoSearch", @YES, @(FOCUS_OMNIBOX) ],
    @[ @"OpenVoiceSearch", @NO, @(START_VOICE_SEARCH) ],
    @[ @"OpenQRScanner", @NO, @(START_QR_CODE_SCANNER) ]
  ];

  swizzleHandleStartupParameters();

  for (id parameters in parametersToTest) {
    UIApplicationShortcutItem* shortcut =
        [[UIApplicationShortcutItem alloc] initWithType:parameters[0]
                                         localizedTitle:parameters[0]];

    resetHandleStartupParametersHasBeenCalled();

    // The test will fail is a method of those objects is called.
    id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];

    // Action.
    [UserActivityHandler performActionForShortcutItem:shortcut
                                    completionHandler:getCompletionHandler()
                                            tabOpener:tabOpenerMock
                                connectionInformation:fakeConnectionInformation
                                   startupInformation:fakeStartupInformation
                                    interfaceProvider:GetInterfaceProvider()
                                            initStage:InitStageFinal];

    // Tests.
    EXPECT_EQ(gurlNewTab,
              [fakeConnectionInformation startupParameters].externalURL);
    EXPECT_EQ([[parameters objectAtIndex:1] boolValue],
              [fakeConnectionInformation startupParameters].launchInIncognito);
    EXPECT_EQ([[parameters objectAtIndex:2] intValue],
              [fakeConnectionInformation startupParameters].postOpeningAction);
    EXPECT_TRUE(completionHandlerExecuted());
    EXPECT_TRUE(completionHandlerArgument());
    EXPECT_TRUE(getHandleStartupParametersHasBeenCalled());
  }
}

// Tests that performActionForShortcutItem just executes the completionHandler
// with NO if the firstRunUI is present.
TEST_F(UserActivityHandlerTest, PerformActionForShortcutItemWithFirstRunUI) {
  // Setup.
  id startupInformationMock =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];

  id connectionInformationMock =
      [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];

  UIApplicationShortcutItem* shortcut =
      [[UIApplicationShortcutItem alloc] initWithType:@"OpenNewSearch"
                                       localizedTitle:@""];

  swizzleHandleStartupParameters();

  // The test will fail is a method of those objects is called.
  id tabOpenerMock = [OCMockObject mockForProtocol:@protocol(TabOpening)];
  id interfaceProviderMock =
      [OCMockObject mockForProtocol:@protocol(BrowserInterfaceProvider)];

  // Action.
  [UserActivityHandler performActionForShortcutItem:shortcut
                                  completionHandler:getCompletionHandler()
                                          tabOpener:tabOpenerMock
                              connectionInformation:connectionInformationMock
                                 startupInformation:startupInformationMock
                                  interfaceProvider:interfaceProviderMock
                                          initStage:InitStageFirstRun];

  // Tests.
  EXPECT_TRUE(completionHandlerExecuted());
  EXPECT_FALSE(completionHandlerArgument());
  EXPECT_FALSE(getHandleStartupParametersHasBeenCalled());
}
