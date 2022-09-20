// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/autofill/form_input_accessory/branding_view_controller.h"

#import "base/notreached.h"
#import "base/threading/sequenced_task_runner_handle.h"
#import "base/time/time.h"
#import "ios/chrome/browser/ui/autofill/features.h"
#import "ios/chrome/browser/ui/autofill/form_input_accessory/branding_view_controller_delegate.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// The left margin of the branding logo, if visible.
constexpr CGFloat kLeadingInset = 10;
// The scale used by the "pop" animation.
constexpr CGFloat kAnimationScale = 1.25;
// Wait time after the branding is shown to perform pop animation.
constexpr base::TimeDelta kAnimationWaitTime = base::Milliseconds(200);
// Time it takes the "pop" animation to perform.
constexpr base::TimeDelta kTimeToAnimate = base::Milliseconds(400);
// Minimum time interval between two animations.
constexpr base::TimeDelta kMinTimeIntervalBetweenAnimations = base::Seconds(3);
}  // namespace

@interface BrandingViewController ()

// The start time of the last or ongoing animation.
@property(nonatomic, assign) base::TimeTicks lastAnimationStartTime;

// Whether the animation should be shown; should be checked each time the
// animation is visible.
@property(nonatomic, readonly) BOOL shouldAnimate;

@end

@implementation BrandingViewController

#pragma mark - Life Cycle

- (void)loadView {
  NSString* logoName;
  switch (autofill::features::GetAutofillBrandingType()) {
    case autofill::features::AutofillBrandingType::kFullColor:
      logoName = @"fullcolor_branding_icon";
      break;
    case autofill::features::AutofillBrandingType::kMonotone:
      logoName = @"monotone_branding_icon";
      break;
    case autofill::features::AutofillBrandingType::kDisabled:
      NOTREACHED();
      break;
  }
  UIImage* logo = [[UIImage imageNamed:logoName]
      imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration* buttonConfig =
        [UIButtonConfiguration plainButtonConfiguration];
    buttonConfig.contentInsets =
        NSDirectionalEdgeInsetsMake(0, kLeadingInset, 0, 0);
    button.configuration = buttonConfig;
  } else {
    button.imageEdgeInsets = UIEdgeInsetsMake(0, kLeadingInset, 0, 0);
  }
  [button setImage:logo forState:UIControlStateNormal];
  [button setImage:logo forState:UIControlStateHighlighted];
  button.imageView.contentMode = UIViewContentModeScaleAspectFit;
  button.isAccessibilityElement = NO;  // Prevents VoiceOver users from tap.
  button.translatesAutoresizingMaskIntoConstraints = NO;
  self.view = button;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  DCHECK(self.delegate);
  if (!self.shouldAnimate) {
    return;
  }
  // The "pop" animation should start after a slight timeout.
  __weak BrandingViewController* weakSelf = self;
  base::SequencedTaskRunnerHandle::Get()->PostDelayedTask(
      FROM_HERE, base::BindOnce(^{
        [weakSelf performPopAnimation];
      }),
      kAnimationWaitTime);
}

#pragma mark - Accessors

- (BOOL)shouldAnimate {
  if (![self.delegate brandingIconShouldPerformPopAnimation]) {
    return NO;
  }
  const base::TimeTicks lastAnimationStartTime = self.lastAnimationStartTime;
  return lastAnimationStartTime.is_null() ||
         (base::TimeTicks::Now() - lastAnimationStartTime) >
             kMinTimeIntervalBetweenAnimations;
}

- (void)setDelegate:(id<BrandingViewControllerDelegate>)delegate {
  _delegate = delegate;
  if (_delegate != nil) {
    [(UIButton*)self.view addTarget:_delegate
                             action:@selector(brandingIconPressed)
                   forControlEvents:UIControlEventTouchUpInside];
  }
}

#pragma mark - Private

// Performs the "pop" animation. This includes a quick enlarging of the icon
// and shrinking it back to the original size, and if finishes successfully,
// also notifies the delegate on completion.
- (void)performPopAnimation {
  self.lastAnimationStartTime = base::TimeTicks::Now();
  __weak BrandingViewController* weakSelf = self;
  [UIView animateWithDuration:kTimeToAnimate.InSecondsF() / 2
      // Scale up the icon.
      animations:^{
        // Resets the transform to original state before animation starts.
        weakSelf.view.transform = CGAffineTransformIdentity;
        weakSelf.view.transform = CGAffineTransformScale(
            weakSelf.view.transform, kAnimationScale, kAnimationScale);
      }
      completion:^(BOOL finished) {
        if (!finished) {
          return;
        }
        // Scale the icon back down.
        [UIView animateWithDuration:kTimeToAnimate.InSecondsF() / 2
            animations:^{
              weakSelf.view.transform = CGAffineTransformIdentity;
            }
            completion:^(BOOL innerFinished) {
              if (innerFinished) {
                [weakSelf.delegate brandingIconDidPerformPopAnimation];
              }
            }];
      }];
}

@end