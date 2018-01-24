// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/toolbar/adaptive/primary_toolbar_view_controller.h"

#import "base/logging.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/history_popup/requirements/tab_history_constants.h"
#import "ios/chrome/browser/ui/toolbar/adaptive/adaptive_toolbar_view_controller+subclassing.h"
#import "ios/chrome/browser/ui/toolbar/adaptive/primary_toolbar_view.h"
#import "ios/chrome/browser/ui/toolbar/clean/toolbar_button.h"
#import "ios/chrome/browser/ui/toolbar/clean/toolbar_constants.h"
#import "ios/chrome/browser/ui/toolbar/clean/toolbar_tools_menu_button.h"
#import "ios/chrome/browser/ui/util/named_guide.h"
#import "ios/third_party/material_components_ios/src/components/ProgressView/src/MaterialProgressView.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface PrimaryToolbarViewController ()
// Redefined to be a PrimaryToolbarView.
@property(nonatomic, strong) PrimaryToolbarView* view;
@end

@implementation PrimaryToolbarViewController

@dynamic view;

#pragma mark - Public

- (void)showPrerenderingAnimation {
  __weak PrimaryToolbarViewController* weakSelf = self;
  [self.view.progressBar setProgress:0];
  [self.view.progressBar setHidden:NO
                          animated:YES
                        completion:^(BOOL finished) {
                          [weakSelf stopProgressBar];
                        }];
}

#pragma mark - UIViewController

- (void)loadView {
  DCHECK(self.buttonFactory);

  self.view =
      [[PrimaryToolbarView alloc] initWithButtonFactory:self.buttonFactory];

  if (@available(iOS 11, *)) {
    self.view.topSafeAnchor = self.view.safeAreaLayoutGuide.topAnchor;
  } else {
    self.view.topSafeAnchor = self.topLayoutGuide.bottomAnchor;
  }

  // This method cannot be called from the init as the topSafeAnchor can only be
  // set to topLayoutGuide after the view creation on iOS 10.
  [self.view setUp];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Adds the layout guide to the buttons. Adds the priorities such as the
  // layout guide constraints does not conflict with others set by other
  // toolbar.
  self.view.toolsMenuButton.guideName = kTabSwitcherGuide;
  self.view.toolsMenuButton.constraintPriority =
      kPrimaryToolbarTrailingButtonPriority;
  self.view.forwardLeadingButton.guideName = kForwardButtonGuide;
  self.view.forwardLeadingButton.constraintPriority =
      kPrimaryToolbarLeadingButtonPriority;
  self.view.forwardTrailingButton.guideName = kForwardButtonGuide;
  self.view.forwardTrailingButton.constraintPriority =
      kPrimaryToolbarTrailingButtonPriority;
  self.view.backButton.guideName = kBackButtonGuide;
  self.view.backButton.constraintPriority =
      kPrimaryToolbarLeadingButtonPriority;

  // Add navigation popup menu triggers.
  [self addLongPressGestureToView:self.view.backButton];
  [self addLongPressGestureToView:self.view.forwardLeadingButton];
  [self addLongPressGestureToView:self.view.forwardTrailingButton];
}

#pragma mark - Property accessors

- (void)setLocationBarView:(UIView*)locationBarView {
  self.view.locationBarView = locationBarView;
}

#pragma mark - ActivityServicePositioner

- (UIView*)shareButtonView {
  return self.view.shareButton;
}

#pragma mark - TabHistoryUIUpdater

- (void)updateUIForTabHistoryPresentationFrom:(ToolbarButtonType)buttonType {
  if (buttonType == ToolbarButtonTypeBack) {
    self.view.backButton.selected = YES;
  } else {
    self.view.forwardLeadingButton.selected = YES;
    self.view.forwardTrailingButton.selected = YES;
  }
}

- (void)updateUIForTabHistoryWasDismissed {
  self.view.backButton.selected = NO;
  self.view.forwardLeadingButton.selected = NO;
  self.view.forwardTrailingButton.selected = NO;
}

#pragma mark - Private

// Adds a LongPressGesture to the |view|, with target on -|handleLongPress:|.
- (void)addLongPressGestureToView:(UIView*)view {
  UILongPressGestureRecognizer* navigationHistoryLongPress =
      [[UILongPressGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(handleLongPress:)];
  [view addGestureRecognizer:navigationHistoryLongPress];
}

// Handles the long press on the views.
- (void)handleLongPress:(UILongPressGestureRecognizer*)gesture {
  if (gesture.state != UIGestureRecognizerStateBegan)
    return;

  if (gesture.view == self.view.backButton) {
    [self.dispatcher showTabHistoryPopupForBackwardHistory];
  } else if (gesture.view == self.view.forwardLeadingButton ||
             gesture.view == self.view.forwardTrailingButton) {
    [self.dispatcher showTabHistoryPopupForForwardHistory];
  }
}

@end
