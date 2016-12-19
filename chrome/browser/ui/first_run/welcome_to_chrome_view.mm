// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/first_run/welcome_to_chrome_view.h"

#include "base/i18n/rtl.h"
#import "base/ios/weak_nsobject.h"
#include "base/logging.h"
#import "base/mac/scoped_nsobject.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/ui/UIView+SizeClassSupport.h"
#include "ios/chrome/browser/ui/fancy_ui/primary_action_button.h"
#include "ios/chrome/browser/ui/first_run/first_run_util.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#import "ios/chrome/browser/ui/util/CRUILabel+AttributeUtils.h"
#import "ios/chrome/browser/ui/util/label_link_controller.h"
#include "ios/chrome/common/string_util.h"
#include "ios/chrome/grit/ios_chromium_strings.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/third_party/material_roboto_font_loader_ios/src/src/MaterialRobotoFontLoader.h"
#include "ui/base/l10n/l10n_util.h"
#include "url/gurl.h"

namespace {

// Accessibility identifier for the checkbox button.
NSString* const kUMAMetricsButtonAccessibilityIdentifier =
    @"UMAMetricsButtonAccessibilityIdentifier";

// Color of "Terms of Service" link text.
const int kLinkColorRGB = 0x5D9AFF;

// The width of the container view for a REGULAR width size class.
const CGFloat kContainerViewRegularWidth = 510.0;

// The percentage of the view's width taken up by the container view for a
// COMPACT width size class.
const CGFloat kContainerViewCompactWidthPercentage = 0.8;

// Layout constants.
const CGFloat kImageTopPadding[SIZE_CLASS_COUNT] = {32.0, 50.0};
const CGFloat kTOSLabelTopPadding[SIZE_CLASS_COUNT] = {34.0, 40.0};
const CGFloat kOptInLabelTopPadding[SIZE_CLASS_COUNT] = {10.0, 14.0};
const CGFloat kCheckBoxPadding[SIZE_CLASS_COUNT] = {10.0, 16.0};
const CGFloat kOKButtonBottomPadding[SIZE_CLASS_COUNT] = {16.0, 24.0};
// Multiplier matches that used in LaunchScreen.xib to determine size of logo.
const CGFloat kAppLogoProportionMultiplier = 0.381966;

// Font sizes.
const CGFloat kTitleLabelFontSize[SIZE_CLASS_COUNT] = {24.0, 36.0};
const CGFloat kTOSLabelFontSize[SIZE_CLASS_COUNT] = {14.0, 21.0};
const CGFloat kTOSLabelLineHeight[SIZE_CLASS_COUNT] = {20.0, 32.0};
const CGFloat kOptInLabelFontSize[SIZE_CLASS_COUNT] = {13.0, 19.0};
const CGFloat kOptInLabelLineHeight[SIZE_CLASS_COUNT] = {18.0, 26.0};
const CGFloat kOKButtonTitleLabelFontSize[SIZE_CLASS_COUNT] = {14.0, 20.0};

// Animation constants
const CGFloat kAnimationDuration = .4;
// Delay animation to avoid interaction with launch screen fadeout.
const CGFloat kAnimationDelay = .5;

// Image names.
NSString* const kAppLogoImageName = @"launchscreen_app_logo";
NSString* const kCheckBoxImageName = @"checkbox";
NSString* const kCheckBoxCheckedImageName = @"checkbox_checked";

}  // namespace

@interface WelcomeToChromeView () {
  // Backing objects for properties of the same name.
  base::WeakNSProtocol<id<WelcomeToChromeViewDelegate>> _delegate;
  base::scoped_nsobject<UIView> _containerView;
  base::scoped_nsobject<UILabel> _titleLabel;
  base::scoped_nsobject<UIImageView> _imageView;
  base::scoped_nsobject<UILabel> _TOSLabel;
  base::scoped_nsobject<LabelLinkController> _TOSLabelLinkController;
  base::scoped_nsobject<UIButton> _checkBoxButton;
  base::scoped_nsobject<UILabel> _optInLabel;
  base::scoped_nsobject<PrimaryActionButton> _OKButton;
}

// Subview properties are lazily instantiated upon their first use.

// A container view used to layout and center subviews.
@property(nonatomic, readonly) UIView* containerView;
// The "Welcome to Chrome" label that appears at the top of the view.
@property(nonatomic, readonly) UILabel* titleLabel;
// The Chrome logo image view.
@property(nonatomic, readonly) UIImageView* imageView;
// The "Terms of Service" label.
@property(nonatomic, readonly) UILabel* TOSLabel;
// The stats reporting opt-in label.
@property(nonatomic, readonly) UILabel* optInLabel;
// The stats reporting opt-in checkbox button.
@property(nonatomic, readonly) UIButton* checkBoxButton;
// The "Accept & Continue" button.
@property(nonatomic, readonly) PrimaryActionButton* OKButton;

// Subview layout methods.  They must be called in the order declared here, as
// subsequent subview layouts depend on the layouts that precede them.
- (void)layoutTitleLabel;
- (void)layoutImageView;
- (void)layoutTOSLabel;
- (void)layoutOptInLabel;
- (void)layoutCheckBoxButton;
- (void)layoutContainerView;
- (void)layoutOKButton;

// Calls the subview configuration selectors below.
- (void)configureSubviews;

// Subview configuration methods.
- (void)configureTitleLabel;
- (void)configureImageView;
- (void)configureTOSLabel;
- (void)configureOptInLabel;
- (void)configureContainerView;
- (void)configureOKButton;

// Action triggered by the check box button.
- (void)checkBoxButtonWasTapped;

// Action triggered by the ok button.
- (void)OKButtonWasTapped;

// The TOS label button was tapped.
// TODO(crbug.com/539961): Remove once link detection is fixed.
- (void)TOSLinkWasTapped;

@end

@implementation WelcomeToChromeView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [UIColor whiteColor];
    self.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  }
  return self;
}

- (void)runLaunchAnimation {
  // Prepare for animation by making views (except for the logo) transparent
  // and finding the initial and final location of the logo.
  self.titleLabel.alpha = 0.0;
  self.TOSLabel.alpha = 0.0;
  self.optInLabel.alpha = 0.0;
  self.checkBoxButton.alpha = 0.0;
  self.OKButton.alpha = 0.0;

  // Get final location of logo based on result from previously run
  // layoutSubviews.
  CGRect finalLogoFrame = self.imageView.frame;
  // Ensure that frame position is valid and that layoutSubviews ran
  // before this method.
  DCHECK(finalLogoFrame.origin.x >= 0 && finalLogoFrame.origin.y >= 0);
  self.imageView.center = CGPointMake(CGRectGetMidX(self.containerView.bounds),
                                      CGRectGetMidY(self.containerView.bounds));

  base::WeakNSObject<WelcomeToChromeView> weakSelf(self);
  [UIView animateWithDuration:kAnimationDuration
                        delay:kAnimationDelay
                      options:UIViewAnimationCurveEaseInOut
                   animations:^{
                     [weakSelf imageView].frame = finalLogoFrame;
                     [weakSelf titleLabel].alpha = 1.0;
                     [weakSelf TOSLabel].alpha = 1.0;
                     [weakSelf optInLabel].alpha = 1.0;
                     [weakSelf checkBoxButton].alpha = 1.0;
                     [weakSelf OKButton].alpha = 1.0;
                   }
                   completion:nil];
}

#pragma mark - Accessors

- (id<WelcomeToChromeViewDelegate>)delegate {
  return _delegate;
}

- (void)setDelegate:(id<WelcomeToChromeViewDelegate>)delegate {
  _delegate.reset(delegate);
}

- (BOOL)isCheckBoxSelected {
  return self.checkBoxButton.selected;
}

- (void)setCheckBoxSelected:(BOOL)checkBoxSelected {
  if (checkBoxSelected != self.checkBoxButton.selected)
    [self checkBoxButtonWasTapped];
}

- (UIView*)containerView {
  if (!_containerView) {
    _containerView.reset([[UIView alloc] initWithFrame:CGRectZero]);
    [_containerView setBackgroundColor:[UIColor whiteColor]];
  }
  return _containerView.get();
}

- (UILabel*)titleLabel {
  if (!_titleLabel) {
    _titleLabel.reset([[UILabel alloc] initWithFrame:CGRectZero]);
    [_titleLabel setBackgroundColor:[UIColor whiteColor]];
    [_titleLabel setNumberOfLines:0];
    [_titleLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [_titleLabel setBaselineAdjustment:UIBaselineAdjustmentAlignBaselines];
    [_titleLabel
        setText:l10n_util::GetNSString(IDS_IOS_FIRSTRUN_WELCOME_TO_CHROME)];
  }
  return _titleLabel.get();
}

- (UIImageView*)imageView {
  if (!_imageView) {
    UIImage* image = [UIImage imageNamed:kAppLogoImageName];
    _imageView.reset([[UIImageView alloc] initWithImage:image]);
    [_imageView setBackgroundColor:[UIColor whiteColor]];
  }
  return _imageView.get();
}

- (UILabel*)TOSLabel {
  if (!_TOSLabel) {
    _TOSLabel.reset([[UILabel alloc] initWithFrame:CGRectZero]);
    [_TOSLabel setNumberOfLines:0];
    [_TOSLabel setTextAlignment:NSTextAlignmentCenter];
  }
  return _TOSLabel.get();
}

- (UILabel*)optInLabel {
  if (!_optInLabel) {
    _optInLabel.reset([[UILabel alloc] initWithFrame:CGRectZero]);
    [_optInLabel setNumberOfLines:0];
    [_optInLabel
        setText:l10n_util::GetNSString(IDS_IOS_FIRSTRUN_NEW_OPT_IN_LABEL)];
    [_optInLabel setTextAlignment:NSTextAlignmentNatural];
  }
  return _optInLabel.get();
}

- (UIButton*)checkBoxButton {
  if (!_checkBoxButton) {
    _checkBoxButton.reset([[UIButton alloc] initWithFrame:CGRectZero]);
    [_checkBoxButton setBackgroundColor:[UIColor clearColor]];
    [_checkBoxButton addTarget:self
                        action:@selector(checkBoxButtonWasTapped)
              forControlEvents:UIControlEventTouchUpInside];
    SetA11yLabelAndUiAutomationName(_checkBoxButton,
                                    IDS_IOS_FIRSTRUN_NEW_OPT_IN_LABEL,
                                    kUMAMetricsButtonAccessibilityIdentifier);
    [_checkBoxButton
        setAccessibilityValue:l10n_util::GetNSString(IDS_IOS_SETTING_OFF)];
    [_checkBoxButton setImage:[UIImage imageNamed:kCheckBoxImageName]
                     forState:UIControlStateNormal];
    [_checkBoxButton setImage:[UIImage imageNamed:kCheckBoxCheckedImageName]
                     forState:UIControlStateSelected];
  }
  return _checkBoxButton.get();
}

- (PrimaryActionButton*)OKButton {
  if (!_OKButton) {
    _OKButton.reset([[PrimaryActionButton alloc] initWithFrame:CGRectZero]);
    [_OKButton addTarget:self
                  action:@selector(OKButtonWasTapped)
        forControlEvents:UIControlEventTouchUpInside];
    NSString* acceptAndContinue =
        l10n_util::GetNSString(IDS_IOS_FIRSTRUN_OPT_IN_ACCEPT_BUTTON);
    [_OKButton setTitle:acceptAndContinue forState:UIControlStateNormal];
    [_OKButton setTitle:acceptAndContinue forState:UIControlStateHighlighted];
    // UIAutomation tests look for the Accept button to skip through the
    // First Run UI when it shows up.
    SetA11yLabelAndUiAutomationName(
        _OKButton, IDS_IOS_FIRSTRUN_OPT_IN_ACCEPT_BUTTON, @"Accept & Continue");
  }
  return _OKButton.get();
}

#pragma mark - Layout

- (void)willMoveToSuperview:(nullable UIView*)newSuperview {
  [super willMoveToSuperview:newSuperview];

  // Early return if the view hierarchy is already built.
  if (self.containerView.superview) {
    DCHECK_EQ(self, self.containerView.superview);
    return;
  }

  [self addSubview:self.containerView];
  [self.containerView addSubview:self.titleLabel];
  [self.containerView addSubview:self.imageView];
  [self.containerView addSubview:self.TOSLabel];
  [self.containerView addSubview:self.optInLabel];
  [self.containerView addSubview:self.checkBoxButton];
  [self addSubview:self.OKButton];
  [self configureSubviews];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [self layoutTitleLabel];
  [self layoutImageView];
  [self layoutTOSLabel];
  [self layoutOptInLabel];
  [self layoutCheckBoxButton];
  [self layoutContainerView];
  [self layoutOKButton];
}

- (void)layoutTitleLabel {
  // The label is centered and top-aligned with the container view.
  CGSize containerSize = self.containerView.bounds.size;
  containerSize.height = CGFLOAT_MAX;
  CGSize titleLabelSize = [self.titleLabel sizeThatFits:containerSize];
  self.titleLabel.frame = AlignRectOriginAndSizeToPixels(
      CGRectMake((containerSize.width - titleLabelSize.width) / 2.0, 0.0,
                 titleLabelSize.width, titleLabelSize.height));
}

- (void)layoutImageView {
  // The image is centered and laid out below |titleLabel| as specified by
  // kImageTopPadding.
  CGSize imageViewSize = self.imageView.bounds.size;
  CGFloat imageViewTopPadding = kImageTopPadding[self.cr_heightSizeClass];
  self.imageView.frame = AlignRectOriginAndSizeToPixels(CGRectMake(
      (CGRectGetWidth(self.containerView.bounds) - imageViewSize.width) / 2.0,
      CGRectGetMaxY(self.titleLabel.frame) + imageViewTopPadding,
      imageViewSize.width, imageViewSize.height));
}

- (void)layoutTOSLabel {
  // The TOS label is centered and laid out below |imageView| as specified by
  // kTOSLabelTopPadding.
  CGSize containerSize = self.containerView.bounds.size;
  containerSize.height = CGFLOAT_MAX;
  self.TOSLabel.frame = {CGPointZero, containerSize};
  NSString* TOSText = l10n_util::GetNSString(IDS_IOS_FIRSTRUN_AGREE_TO_TERMS);
  NSRange linkTextRange = NSMakeRange(NSNotFound, 0);
  NSString* strippedText = ParseStringWithLink(TOSText, &linkTextRange);
  DCHECK_NE(NSNotFound, static_cast<NSInteger>(linkTextRange.location));
  DCHECK_NE(0u, linkTextRange.length);

  self.TOSLabel.text = strippedText;
  if (ios_internal::FixOrphanWord(self.TOSLabel)) {
    // If a newline is inserted, check whether it was added mid-link and adjust
    // |linkTextRange| accordingly.
    NSRange newlineRange =
        [self.TOSLabel.text rangeOfString:@"\n" options:0 range:linkTextRange];
    if (newlineRange.length)
      linkTextRange.length++;
  }

  base::WeakNSObject<WelcomeToChromeView> weakSelf(self);
  ProceduralBlockWithURL action = ^(const GURL& url) {
    base::scoped_nsobject<WelcomeToChromeView> strongSelf([weakSelf retain]);
    if (!strongSelf)
      return;
    [[strongSelf delegate] welcomeToChromeViewDidTapTOSLink:strongSelf];
  };

  _TOSLabelLinkController.reset(
      [[LabelLinkController alloc] initWithLabel:_TOSLabel action:action]);
  [_TOSLabelLinkController
      addLinkWithRange:linkTextRange
                   url:GURL("internal://terms-of-service")];
  [_TOSLabelLinkController setLinkColor:UIColorFromRGB(kLinkColorRGB)];

  CGSize TOSLabelSize = [self.TOSLabel sizeThatFits:containerSize];
  CGFloat TOSLabelTopPadding = kTOSLabelTopPadding[self.cr_heightSizeClass];
  self.TOSLabel.frame = AlignRectOriginAndSizeToPixels(
      CGRectMake((containerSize.width - TOSLabelSize.width) / 2.0,
                 CGRectGetMaxY(self.imageView.frame) + TOSLabelTopPadding,
                 TOSLabelSize.width, TOSLabelSize.height));
}

- (void)layoutOptInLabel {
  // The opt in label is laid out to the right (or left in RTL) of the check box
  // button and below |TOSLabel| as specified by kOptInLabelTopPadding.
  CGSize checkBoxSize =
      [self.checkBoxButton imageForState:self.checkBoxButton.state].size;
  CGFloat checkBoxPadding = kCheckBoxPadding[self.cr_widthSizeClass];
  CGFloat optInLabelSidePadding = checkBoxSize.width + 2.0 * checkBoxPadding;
  CGSize optInLabelSize = [self.optInLabel
      sizeThatFits:CGSizeMake(CGRectGetWidth(self.containerView.bounds) -
                                  optInLabelSidePadding,
                              CGFLOAT_MAX)];
  CGFloat optInLabelTopPadding = kOptInLabelTopPadding[self.cr_heightSizeClass];
  CGFloat optInLabelOriginX =
      base::i18n::IsRTL() ? 0.0f : optInLabelSidePadding;
  self.optInLabel.frame = AlignRectOriginAndSizeToPixels(
      CGRectMake(optInLabelOriginX,
                 CGRectGetMaxY(self.TOSLabel.frame) + optInLabelTopPadding,
                 optInLabelSize.width, optInLabelSize.height));
  ios_internal::FixOrphanWord(self.optInLabel);
}

- (void)layoutCheckBoxButton {
  // The checkBoxButton is laid out to the left of |optInLabel|.  The view
  // itself is sized so that it covers the label, and the image insets are
  // chosen such that the check box image is centered vertically with
  // |optInLabel|.
  CGSize checkBoxSize =
      [self.checkBoxButton imageForState:self.checkBoxButton.state].size;
  CGFloat checkBoxPadding = kCheckBoxPadding[self.cr_widthSizeClass];
  CGSize checkBoxButtonSize =
      CGSizeMake(CGRectGetWidth(self.optInLabel.frame) + checkBoxSize.width +
                     2.0 * checkBoxPadding,
                 std::max(CGRectGetHeight(self.optInLabel.frame),
                          checkBoxSize.height + 2.0f * checkBoxPadding));
  self.checkBoxButton.frame = AlignRectOriginAndSizeToPixels(CGRectMake(
      0.0f,
      CGRectGetMidY(self.optInLabel.frame) - checkBoxButtonSize.height / 2.0,
      checkBoxButtonSize.width, checkBoxButtonSize.height));
  CGFloat largeHorizontalInset =
      checkBoxButtonSize.width - checkBoxSize.width - checkBoxPadding;
  CGFloat smallHorizontalInset = checkBoxPadding;
  self.checkBoxButton.imageEdgeInsets = UIEdgeInsetsMake(
      (checkBoxButtonSize.height - checkBoxSize.height) / 2.0,
      base::i18n::IsRTL() ? largeHorizontalInset : smallHorizontalInset,
      (checkBoxButtonSize.height - checkBoxSize.height) / 2.0,
      base::i18n::IsRTL() ? smallHorizontalInset : largeHorizontalInset);
}

- (void)layoutContainerView {
  // The container view is resized according to the final layout of
  // |checkBoxButton|, which is its lowest subview.  The resized view is then
  // centered horizontally and vertically.
  CGSize containerViewSize = self.containerView.bounds.size;
  containerViewSize.height = CGRectGetMaxY(self.checkBoxButton.frame);
  self.containerView.frame = AlignRectOriginAndSizeToPixels(CGRectMake(
      (CGRectGetWidth(self.bounds) - containerViewSize.width) / 2.0,
      (CGRectGetHeight(self.bounds) - containerViewSize.height) / 2.0,
      containerViewSize.width, CGRectGetMaxY(self.checkBoxButton.frame)));
}

- (void)layoutOKButton {
  // The OK button is laid out at the bottom of the view as specified by
  // kOKButtonBottomPadding.
  CGFloat OKButtonBottomPadding =
      kOKButtonBottomPadding[self.cr_widthSizeClass];
  CGSize OKButtonSize = self.OKButton.bounds.size;
  self.OKButton.frame = AlignRectOriginAndSizeToPixels(CGRectMake(
      (CGRectGetWidth(self.bounds) - OKButtonSize.width) / 2.0,
      CGRectGetMaxY(self.bounds) - OKButtonSize.height - OKButtonBottomPadding,
      OKButtonSize.width, OKButtonSize.height));
}

- (void)traitCollectionDidChange:
    (nullable UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  [self configureSubviews];
}

- (void)configureSubviews {
  [self configureContainerView];
  [self configureTitleLabel];
  [self configureImageView];
  [self configureTOSLabel];
  [self configureOptInLabel];
  [self configureOKButton];
  [self setNeedsLayout];
}

- (void)configureTitleLabel {
  self.titleLabel.font = [[MDFRobotoFontLoader sharedInstance]
      regularFontOfSize:kTitleLabelFontSize[self.cr_widthSizeClass]];
}

- (void)configureImageView {
  CGFloat sideLength = self.imageView.image.size.width;
  if (self.cr_widthSizeClass == COMPACT) {
    sideLength = self.bounds.size.width * kAppLogoProportionMultiplier;
  } else if (self.cr_heightSizeClass == COMPACT) {
    sideLength = self.bounds.size.height * kAppLogoProportionMultiplier;
  }
  self.imageView.bounds = AlignRectOriginAndSizeToPixels(
      CGRectMake(self.imageView.bounds.origin.x, self.imageView.bounds.origin.y,
                 sideLength, sideLength));
}

- (void)configureTOSLabel {
  self.TOSLabel.font = [[MDFRobotoFontLoader sharedInstance]
      regularFontOfSize:kTOSLabelFontSize[self.cr_widthSizeClass]];
  self.TOSLabel.cr_lineHeight = kTOSLabelLineHeight[self.cr_widthSizeClass];
}

- (void)configureOptInLabel {
  self.optInLabel.font = [[MDFRobotoFontLoader sharedInstance]
      regularFontOfSize:kOptInLabelFontSize[self.cr_widthSizeClass]];
  self.optInLabel.cr_lineHeight = kOptInLabelLineHeight[self.cr_widthSizeClass];
}

- (void)configureContainerView {
  CGFloat containerViewWidth =
      self.cr_widthSizeClass == COMPACT
          ? kContainerViewCompactWidthPercentage * CGRectGetWidth(self.bounds)
          : kContainerViewRegularWidth;
  self.containerView.frame =
      CGRectMake(0.0, 0.0, containerViewWidth, CGFLOAT_MAX);
}

- (void)configureOKButton {
  self.OKButton.titleLabel.font = [[MDFRobotoFontLoader sharedInstance]
      mediumFontOfSize:kOKButtonTitleLabelFontSize[self.cr_widthSizeClass]];
  [self.OKButton sizeToFit];
}

#pragma mark -

- (void)checkBoxButtonWasTapped {
  self.checkBoxButton.selected = !self.checkBoxButton.selected;
  self.checkBoxButton.accessibilityValue =
      self.checkBoxButton.selected
          ? l10n_util::GetNSString(IDS_IOS_SETTING_ON)
          : l10n_util::GetNSString(IDS_IOS_SETTING_OFF);
}

- (void)OKButtonWasTapped {
  [self.delegate welcomeToChromeViewDidTapOKButton:self];
}

- (void)TOSLinkWasTapped {
  [self.delegate welcomeToChromeViewDidTapTOSLink:self];
}

@end
