// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bubble/bubble_view.h"

#include "base/ios/ios_util.h"
#include "base/mac/foundation_util.h"
#include "ios/chrome/browser/ui/util/ui_util.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface BubbleViewDelegateTest : NSObject <BubbleViewDelegate>

- (instancetype)init;

@property(nonatomic) int tapCounter;

@end

@implementation BubbleViewDelegateTest

- (instancetype)init {
  self = [super init];
  if (self) {
    _tapCounter = 0;
  }
  return self;
}

- (void)didTapCloseButton {
  _tapCounter += 1;
}

@end

// Fixture to test BubbleView.
class BubbleViewTest : public PlatformTest {
 public:
  BubbleViewTest()
      : maxSize_(CGSizeMake(500.0f, 500.0f)),
        arrowDirection_(BubbleArrowDirectionUp),
        alignment_(BubbleAlignmentCenter),
        shortText_(@"I"),
        longText_(@"Lorem ipsum dolor sit amet, consectetur adipiscing elit.") {
  }

 protected:
  // The maximum size of the bubble.
  const CGSize maxSize_;
  // The direction that the bubble's arrow points.
  const BubbleArrowDirection arrowDirection_;
  // The alignment of the bubble's arrow relative to the rest of the bubble.
  const BubbleAlignment alignment_;
  // Text that is shorter than the minimum line width.
  NSString* shortText_;
  // Text that is longer than the maximum line width. It should wrap onto
  // multiple lines.
  NSString* longText_;

  UIButton* GetCloseButton(BubbleView* bubbleView) {
    for (UIView* subview in bubbleView.subviews) {
      if ([subview isKindOfClass:[UIButton class]] &&
          subview.accessibilityIdentifier == kBubbleViewCloseButtonIdentifier) {
        return base::mac::ObjCCastStrict<UIButton>(subview);
      }
    }
    return nil;
  }
};

// Test |sizeThatFits| given short text.
TEST_F(BubbleViewTest, BubbleSizeShortText) {
  BubbleView* bubble = [[BubbleView alloc] initWithText:shortText_
                                         arrowDirection:arrowDirection_
                                              alignment:alignment_];
  CGSize bubbleSize = [bubble sizeThatFits:maxSize_];
  // Since the label is shorter than the minimum line width, expect the bubble
  // to be the minimum width and accommodate one line of text.
  EXPECT_NEAR(58.0f, bubbleSize.width, 1.0f);
  EXPECT_NEAR(65.0f, bubbleSize.height, 1.0f);
}

// Test |sizeThatFits| given text that should wrap onto multiple lines.
TEST_F(BubbleViewTest, BubbleSizeMultipleLineText) {
  BubbleView* bubble = [[BubbleView alloc] initWithText:longText_
                                         arrowDirection:arrowDirection_
                                              alignment:alignment_];
  CGSize bubbleSize = [bubble sizeThatFits:maxSize_];

  // The bubble should fit the label, which contains two lines of text.
  EXPECT_NEAR(329.0f, bubbleSize.width, 1.0f);

  EXPECT_NEAR(83.0f, bubbleSize.height, 2.0f);
}

// Test that the accessibility label matches the display text.
TEST_F(BubbleViewTest, Accessibility) {
  BubbleView* bubble = [[BubbleView alloc] initWithText:longText_
                                         arrowDirection:arrowDirection_
                                              alignment:alignment_];
  UIView* superview = [[UIView alloc] initWithFrame:CGRectZero];
  // Add the bubble view to the view hierarchy.
  [superview addSubview:bubble];
  EXPECT_NSEQ(longText_, bubble.accessibilityLabel);
}

// Tests that the close button is not showed when the option is set to hidden.
TEST_F(BubbleViewTest, CloseButtonIsNotPresent) {
  BubbleView* bubble = [[BubbleView alloc] initWithText:longText_
                                         arrowDirection:arrowDirection_
                                              alignment:alignment_];
  [bubble setShowsCloseButton:NO];
  UIView* superview = [[UIView alloc] initWithFrame:CGRectZero];
  [superview addSubview:bubble];
  UIButton* closeButton = GetCloseButton(bubble);
  ASSERT_FALSE(closeButton);
}

// Tests the close button action and its presence.
TEST_F(BubbleViewTest, CloseButtonActionAndPresent) {
  BubbleView* bubble = [[BubbleView alloc] initWithText:longText_
                                         arrowDirection:arrowDirection_
                                              alignment:alignment_];
  BubbleViewDelegateTest* delegate = [[BubbleViewDelegateTest alloc] init];
  [bubble setShowsCloseButton:YES];
  [bubble setDelegate:delegate];
  UIView* superview = [[UIView alloc] initWithFrame:CGRectZero];
  [superview addSubview:bubble];
  UIButton* closeButton = GetCloseButton(bubble);
  ASSERT_TRUE(closeButton);
  // Tests close button action.
  [closeButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  EXPECT_EQ(delegate.tapCounter, 1);
}
