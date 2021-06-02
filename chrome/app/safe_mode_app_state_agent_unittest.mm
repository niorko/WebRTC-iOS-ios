// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/app/safe_mode_app_state_agent.h"

#include "base/ios/block_types.h"
#include "base/test/ios/wait_util.h"
#import "ios/chrome/app/application_delegate/app_state_testing.h"
#import "ios/chrome/app/application_delegate/browser_launcher.h"
#import "ios/chrome/app/application_delegate/startup_information.h"
#import "ios/chrome/app/main_application_delegate.h"
#import "ios/chrome/browser/ui/main/connection_information.h"
#import "ios/chrome/browser/ui/main/test/fake_scene_state.h"
#import "ios/chrome/browser/ui/safe_mode/safe_mode_coordinator.h"
#include "ios/chrome/test/block_cleanup_test.h"
#import "ios/chrome/test/scoped_key_window.h"
#import "ios/testing/scoped_block_swizzler.h"
#include "ios/web/public/test/web_task_environment.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// A block that takes self as argument and return a BOOL.
typedef BOOL (^DecisionBlock)(id self);
}

// Exposes private methods for testing.
@interface SafeModeAppAgent (Private)
@property(nonatomic, strong) SafeModeCoordinator* safeModeCoordinator;
@property(nonatomic, assign) BOOL firstSceneHasActivated;

- (void)appState:(AppState*)appState
    didTransitionFromInitStage:(InitStage)previousStage;
- (void)sceneState:(SceneState*)sceneState
    transitionedToActivationLevel:(SceneActivationLevel)level;
- (void)coordinatorDidExitSafeMode:(SafeModeCoordinator*)coordinator;
@end

// Exposes private methods for testing.
@interface AppState (Private)
@property(nonatomic, assign) InitStage initStage;

- (void)appState:(AppState*)appState
    didTransitionFromInitStage:(InitStage)previousInitStage;
@end

// Iterate through the init stages from |startInitStage| up to
// |initStageDestination|.
void IterateToStage(InitStage startInitStage,
                    InitStage initStageDestination,
                    SafeModeAppAgent* agent,
                    id appStateMock) {
  InitStage initStage = startInitStage;
  if (initStage == InitStageStart) {
    [appStateMock setInitStage:InitStageStart];
    [agent appState:appStateMock didTransitionFromInitStage:InitStageStart];
    initStage = static_cast<InitStage>(startInitStage + 1);
  }

  InitStage prevInitStage = static_cast<InitStage>(initStage - 1);
  while (initStage <= initStageDestination) {
    [appStateMock setInitStage:initStage];
    [agent appState:appStateMock didTransitionFromInitStage:prevInitStage];
    prevInitStage = initStage;
    initStage = static_cast<InitStage>(initStage + 1);
  }
}

class SafeModeAppStateAgentTest : public BlockCleanupTest {
 protected:
  SafeModeAppStateAgentTest() {
    window_ = [OCMockObject mockForClass:[UIWindow class]];
    browser_launcher_mock_ =
        [OCMockObject mockForProtocol:@protocol(BrowserLauncher)];
    startup_information_mock_ =
        [OCMockObject mockForProtocol:@protocol(StartupInformation)];
    connection_information_mock_ =
        [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
    main_application_delegate_ =
        [OCMockObject mockForClass:[MainApplicationDelegate class]];
  }

  void SetUp() override { BlockCleanupTest::SetUp(); }

  void swizzleSafeModeShouldStart(BOOL shouldStart) {
    safe_mode_swizzle_block_ = ^BOOL(id self) {
      return shouldStart;
    };
    safe_mode_swizzler_.reset(new ScopedBlockSwizzler(
        [SafeModeCoordinator class], @selector(shouldStart),
        safe_mode_swizzle_block_));
  }

  AppState* getAppStateWithMock() {
    if (!app_state_) {
      // The swizzle block needs the scene state before app_state is created,
      // but the scene state needs the app state. So this alloc before swizzling
      // and initiate after app state is created.
      main_scene_state_ = [FakeSceneState alloc];

      app_state_ =
          [[AppState alloc] initWithBrowserLauncher:browser_launcher_mock_
                                 startupInformation:startup_information_mock_
                                applicationDelegate:main_application_delegate_];
      app_state_.mainSceneState = main_scene_state_;

      main_scene_state_ = [main_scene_state_ initWithAppState:app_state_];
      main_scene_state_.window = getWindowMock();
    }
    return app_state_;
  }

  id getWindowMock() { return window_; }

  id getBrowserLauncherMock() { return browser_launcher_mock_; }

  FakeSceneState* GetSceneState() { return main_scene_state_; }

 private:
  web::WebTaskEnvironment task_environment_;
  AppState* app_state_;
  FakeSceneState* main_scene_state_;

  std::unique_ptr<ScopedBlockSwizzler> safe_mode_swizzler_;
  DecisionBlock safe_mode_swizzle_block_;

  id browser_launcher_mock_;
  id startup_information_mock_;
  id connection_information_mock_;
  id main_application_delegate_;
  id window_;
};

TEST_F(SafeModeAppStateAgentTest, startSafeMode) {
  id windowMock = getWindowMock();
  [[windowMock expect] makeKeyAndVisible];
  [[[windowMock stub] andReturn:nil] rootViewController];
  [[windowMock stub] setRootViewController:[OCMArg any]];

  AppState* appState = getAppStateWithMock();

  swizzleSafeModeShouldStart(YES);

  SafeModeAppAgent* agent = [[SafeModeAppAgent alloc] init];
  [agent setAppState:appState];

  IterateToStage(InitStageStart, InitStageSafeMode, agent, appState);

  SceneState* sceneState = GetSceneState();

  [agent sceneState:sceneState
      transitionedToActivationLevel:SceneActivationLevelForegroundActive];
  // Second call that should be deduped.
  [agent sceneState:sceneState
      transitionedToActivationLevel:SceneActivationLevelForegroundActive];

  EXPECT_OCMOCK_VERIFY(windowMock);

  // Exit safe mode.
  [agent coordinatorDidExitSafeMode:agent.safeModeCoordinator];

  EXPECT_EQ(nil, agent.safeModeCoordinator);
}

TEST_F(SafeModeAppStateAgentTest, dontStartSafeModeBecauseNotNeeded) {
  AppState* appState = getAppStateWithMock();
  id appStateMock = OCMPartialMock(appState);
  [[appStateMock expect] queueTransitionToNextInitStage];
  [[appStateMock expect] appState:appState
       didTransitionFromInitStage:InitStageSafeMode];

  swizzleSafeModeShouldStart(NO);

  SafeModeAppAgent* agent = [[SafeModeAppAgent alloc] init];
  [agent setAppState:appStateMock];

  IterateToStage(InitStageStart, InitStageSafeMode, agent, appStateMock);

  [agent sceneState:GetSceneState()
      transitionedToActivationLevel:SceneActivationLevelForegroundActive];

  EXPECT_OCMOCK_VERIFY(appStateMock);
}

TEST_F(SafeModeAppStateAgentTest, dontStartSafeModeBecauseNotActiveLevel) {
  AppState* appState = getAppStateWithMock();
  id appStateMock = OCMPartialMock(appState);
  [[appStateMock reject] queueTransitionToNextInitStage];

  swizzleSafeModeShouldStart(YES);

  SafeModeAppAgent* agent = [[SafeModeAppAgent alloc] init];
  [agent setAppState:appStateMock];

  IterateToStage(InitStageStart, InitStageSafeMode, agent, appStateMock);

  [agent sceneState:GetSceneState()
      transitionedToActivationLevel:SceneActivationLevelForegroundInactive];

  EXPECT_OCMOCK_VERIFY(appStateMock);
}

TEST_F(SafeModeAppStateAgentTest,
       dontStartSafeModeBecauseFirstSceneHasAlreadyActivated) {
  AppState* appState = getAppStateWithMock();

  id appStateMock = OCMPartialMock(appState);
  [[appStateMock reject] queueTransitionToNextInitStage];

  swizzleSafeModeShouldStart(YES);

  SafeModeAppAgent* agent = [[SafeModeAppAgent alloc] init];
  [agent setAppState:appStateMock];

  IterateToStage(InitStageStart, InitStageSafeMode, agent, appStateMock);

  agent.firstSceneHasActivated = YES;
  [agent sceneState:GetSceneState()
      transitionedToActivationLevel:SceneActivationLevelForegroundActive];

  EXPECT_OCMOCK_VERIFY(appStateMock);
}
