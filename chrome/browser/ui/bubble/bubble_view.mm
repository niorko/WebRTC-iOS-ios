// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bubble/bubble_view.h"

#include <ostream>

#include "base/check.h"
#include "base/notreached.h"
#import "ios/chrome/browser/ui/bubble/bubble_util.h"
#import "ios/chrome/browser/ui/colors/MDCPalette+CrAdditions.h"
#include "ios/chrome/browser/ui/util/rtl_geometry.h"
#include "ios/chrome/browser/ui/util/ui_util.h"
#include "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Accessibility identifier for the close button.
NSString* const kBubbleViewCloseButtonIdentifier =
    @"BubbleViewCloseButtonIdentifier";
// Accessibility identifier for the title label.
NSString* const kBubbleViewTitleLabelIdentifier =
    @"BubbleViewTitleLabelIdentifier";

namespace {
// The color of the bubble (both circular background and arrow).
UIColor* BubbleColor() {
  return [UIColor colorNamed:kBlueColor];
}

// The corner radius of the bubble's background, which causes the ends of the
// badge to be circular.
const CGFloat kBubbleCornerRadius = 13.0f;
// The maximum label width preserves readability, ensuring that long labels do
// not span across wide screens.
const CGFloat kMaxLabelWidth = 359.0f;

// Margin between the bubble view's bounds and its content. This margin is on
// all sides of the bubble.
const CGFloat kBubbleMargin = 4.0f;
// Padding between the top and bottom the bubble's background and the top and
// bottom of its content.
const CGFloat kBubbleVerticalPadding = 15.0f;
// Padding between the sides of the bubble's background and the sides of its
// content.
const CGFloat kBubbleHorizontalPadding = 20.0f;

// The size that the arrow will appear to have.
const CGSize kArrowSize = {32, 9};

// The offset of the bubble's drop shadow, which will be slightly below the
// bubble.
const CGSize kShadowOffset = {0.0f, 2.0f};
// The blur radius of the bubble's drop shadow.
const CGFloat kShadowRadius = 4.0f;
// The opacity of the bubble's drop shadow.
const CGFloat kShadowOpacity = 0.1f;

// Bezier curve constants.
const CGFloat kControlPointCenter = 0.243125;
const CGFloat kControlPointEnd = 0.514375;

// The size of the close button.
const CGFloat kCloseButtonSize = 48.0f;
// The padding for the top and trailing edges of the close button.
const CGFloat kCloseButtonTopTrailingPadding = 15.0f;

}  // namespace

@interface BubbleView ()
// Label containing the text displayed on the bubble.
@property(nonatomic, strong) UILabel* label;
// Label containing the title displayed on the bubble.
@property(nonatomic, strong) UILabel* titleLabel;
// Pill-shaped view in the background of the bubble.
@property(nonatomic, strong, readonly) UIView* background;
// Triangular arrow that points to the target UI element.
@property(nonatomic, strong, readonly) UIView* arrow;
// Optional close button displayed at the trailing top corner of the bubble.
@property(nonatomic, strong, readonly) UIButton* closeButton;
// Triangular shape, the backing layer for the arrow.
@property(nonatomic, weak) CAShapeLayer* arrowLayer;
@property(nonatomic, assign, readonly) BubbleArrowDirection direction;
@property(nonatomic, assign, readonly) BubbleAlignment alignment;
// Indicate whether view properties need to be added as subviews of the bubble.
@property(nonatomic, assign) BOOL needsAddSubviews;
@end

@implementation BubbleView
@synthesize label = _label;
@synthesize background = _background;
@synthesize arrow = _arrow;
@synthesize direction = _direction;
@synthesize alignment = _alignment;
@synthesize needsAddSubviews = _needsAddSubviews;
@synthesize closeButton = _closeButton;

- (instancetype)initWithText:(NSString*)text
              arrowDirection:(BubbleArrowDirection)direction
                   alignment:(BubbleAlignment)alignment {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _direction = direction;
    _alignment = alignment;
    _label = [BubbleView labelWithText:text];
    _needsAddSubviews = YES;
    _showsCloseButton = NO;
  }
  return self;
}

#pragma mark - Public

- (void)setTitleString:(NSString*)titleString {
  _titleString = [titleString copy];
  if (titleString.length > 0) {
    _titleLabel = [BubbleView titleLabelWithText:_titleString];
    [self.label
        setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]];
  } else {
    _titleLabel = nil;
    [self.label
        setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];
  }
}

- (NSTextAlignment)textAlignment {
  return self.label.textAlignment;
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
  [self.label setTextAlignment:textAlignment];
  [self.titleLabel setTextAlignment:textAlignment];
}

#pragma mark - Private property accessors

// Lazily load the background view.
- (UIView*)background {
  // If the instance variable for the background has not been set up, load the
  // background view and set the instance variable equal to the background view.
  if (!_background) {
    UIView* background = [[UIView alloc] initWithFrame:CGRectZero];
    [background setBackgroundColor:BubbleColor()];
    [background.layer setCornerRadius:kBubbleCornerRadius];
    [background setTranslatesAutoresizingMaskIntoConstraints:NO];
    _background = background;
  }
  return _background;
}

// Lazily load the arrow view.
- (UIView*)arrow {
  // If the instance variable for the arrow has not been set up, load the arrow
  // and set the instance variable equal to the arrow.
  if (!_arrow) {
    CGFloat width = kArrowSize.width;
    CGFloat height = kArrowSize.height;
    UIView* arrow =
        [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, height)];
    UIBezierPath* path = UIBezierPath.bezierPath;
    CGFloat xCenter = width / 2;
    if (self.direction == BubbleArrowDirectionUp) {
      [path moveToPoint:CGPointMake(xCenter, 0)];
      [path addCurveToPoint:CGPointMake(width, height)
              controlPoint1:CGPointMake(xCenter + xCenter * kControlPointCenter,
                                        0)
              controlPoint2:CGPointMake(xCenter + xCenter * kControlPointEnd,
                                        height)];
      [path addLineToPoint:CGPointMake(0, height)];
      [path addCurveToPoint:CGPointMake(xCenter, 0)
              controlPoint1:CGPointMake(xCenter - xCenter * kControlPointEnd,
                                        height)
              controlPoint2:CGPointMake(xCenter - xCenter * kControlPointCenter,
                                        0)];
      } else {
        [path moveToPoint:CGPointMake(xCenter, height)];
        [path
            addCurveToPoint:CGPointMake(width, 0)
              controlPoint1:CGPointMake(xCenter + xCenter * kControlPointCenter,
                                        height)
              controlPoint2:CGPointMake(xCenter + xCenter * kControlPointEnd,
                                        0)];
        [path addLineToPoint:CGPointZero];
        [path
            addCurveToPoint:CGPointMake(xCenter, height)
              controlPoint1:CGPointMake(xCenter - xCenter * kControlPointEnd, 0)
              controlPoint2:CGPointMake(xCenter - xCenter * kControlPointCenter,
                                        height)];
      }
    [path closePath];
    CAShapeLayer* layer = [CAShapeLayer layer];
    [layer setPath:path.CGPath];
    [layer setFillColor:BubbleColor().CGColor];
    [arrow.layer addSublayer:layer];
    _arrowLayer = layer;
    [arrow setTranslatesAutoresizingMaskIntoConstraints:NO];
    _arrow = arrow;
  }
  return _arrow;
}

// Lazy loads the close button.
- (UIButton*)closeButton {
  if (!_closeButton) {
    UIImageSymbolConfiguration* configuration = [UIImageSymbolConfiguration
        configurationWithScale:UIImageSymbolScaleMedium];
    UIImage* buttonImage = [UIImage systemImageNamed:@"xmark"
                                   withConfiguration:configuration];
    // Computes the paddings to position the button's image. The button is
    // bigger than the image for accessibility purposes.
    const CGFloat closeButtonBottomPadding = kCloseButtonSize -
                                             kCloseButtonTopTrailingPadding -
                                             buttonImage.size.height;
    const CGFloat closeButtonLeadingPadding = kCloseButtonSize -
                                              kCloseButtonTopTrailingPadding -
                                              buttonImage.size.width;
    UIButton* button;
    // setImageEdgeInsets from UIButton is deprecated since iOS 15.0, the new
    // API uses UIButtonConfiguration to set the image inset.
    if (@available(iOS 15.0, *)) {
      UIButtonConfiguration* buttonConfiguration =
          [UIButtonConfiguration.plainButtonConfiguration copy];
      [buttonConfiguration setImage:buttonImage];
      [buttonConfiguration
          setContentInsets:NSDirectionalEdgeInsetsMake(
                               kCloseButtonTopTrailingPadding,
                               closeButtonLeadingPadding,
                               closeButtonBottomPadding,
                               kCloseButtonTopTrailingPadding)];
      button = [UIButton buttonWithConfiguration:buttonConfiguration
                                   primaryAction:nil];
    } else {
      button = [UIButton buttonWithType:UIButtonTypeSystem];
      [button setImage:buttonImage forState:UIControlStateNormal];
      [button.imageView setBounds:CGRectZero];
      [button.imageView setContentMode:UIViewContentModeScaleAspectFit];
      [button setImageEdgeInsets:UIEdgeInsetsMakeDirected(
                                     kCloseButtonTopTrailingPadding,
                                     closeButtonLeadingPadding,
                                     closeButtonBottomPadding,
                                     kCloseButtonTopTrailingPadding)];
    }
    [button setTintColor:[UIColor colorNamed:kSolidButtonTextColor]];
    [button addTarget:self
                  action:@selector(closeButtonWasTapped:)
        forControlEvents:UIControlEventTouchUpInside];
    [button setAccessibilityIdentifier:kBubbleViewCloseButtonIdentifier];
    [button setTranslatesAutoresizingMaskIntoConstraints:NO];
    _closeButton = button;
  }
  return _closeButton;
}

#pragma mark - Private class methods

// Returns a label to be used for a BubbleView that displays white text.
+ (UILabel*)labelWithText:(NSString*)text {
  DCHECK(text.length);
  UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
  [label setText:text];
  [label setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];
  [label setTextColor:[UIColor colorNamed:kSolidButtonTextColor]];
  [label setTextAlignment:NSTextAlignmentCenter];
  [label setNumberOfLines:0];
  [label setLineBreakMode:NSLineBreakByWordWrapping];
  [label setTranslatesAutoresizingMaskIntoConstraints:NO];
  return label;
}

// Returns a label to be used for the BubbleView's title.
+ (UILabel*)titleLabelWithText:(NSString*)text {
  DCHECK(text.length);
  UILabel* label = [BubbleView labelWithText:text];
  [label setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
  [label setAccessibilityIdentifier:kBubbleViewTitleLabelIdentifier];
  return label;
}

#pragma mark - Private instance methods

// Handles taps on the close button.
- (void)closeButtonWasTapped:(UIButton*)button {
  DCHECK(self.showsCloseButton);
  if ([self.delegate respondsToSelector:@selector(didTapCloseButton)]) {
    [self.delegate didTapCloseButton];
  }
}

// Add a drop shadow to the bubble.
- (void)addShadow {
  [self.layer setShadowOffset:kShadowOffset];
  [self.layer setShadowRadius:kShadowRadius];
  [self.layer setShadowColor:[UIColor blackColor].CGColor];
  [self.layer setShadowOpacity:kShadowOpacity];
}

// Activate Autolayout constraints to properly position the bubble's subviews.
- (void)activateConstraints {
  // Add constraints that do not depend on the bubble's direction or alignment.
  NSMutableArray<NSLayoutConstraint*>* constraints =
      [NSMutableArray arrayWithArray:[self generalConstraints]];
  // Add the constraint that aligns the arrow relative to the bubble.
  [constraints addObject:[self arrowAlignmentConstraint]];
  // Add constraints that depend on the bubble's direction.
  [constraints addObjectsFromArray:[self arrowDirectionConstraints]];
  // Add constraints for close button.
  if (self.showsCloseButton) {
    [constraints addObjectsFromArray:[self closeButtonConstraints]];
  }
  // Add constraints for title label.
  if (self.titleLabel) {
    [constraints addObjectsFromArray:[self titleLabelConstraints]];
  }
  [NSLayoutConstraint activateConstraints:constraints];
}

// Return an array of constraints that do not depend on the bubble's arrow
// direction or alignment.
- (NSArray<NSLayoutConstraint*>*)generalConstraints {
  UIView* background = self.background;
  UIView* label = self.label;
  NSArray<NSLayoutConstraint*>* constraints = @[
    // Center the background view on the bubble view.
    [background.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
    // Add a margin to the sides of the background.
    [background.widthAnchor constraintEqualToAnchor:self.widthAnchor
                                           constant:-kBubbleMargin * 2],
    [background.widthAnchor
        constraintGreaterThanOrEqualToConstant:[self minBubbleWidth] -
                                               kBubbleMargin * 2],
    // Ensure that the background view is as wide as the label, with added
    // padding on the sides of the label.
    [label.topAnchor
        constraintGreaterThanOrEqualToAnchor:background.topAnchor
                                    constant:kBubbleVerticalPadding],
    [background.bottomAnchor
        constraintGreaterThanOrEqualToAnchor:label.bottomAnchor
                                    constant:kBubbleVerticalPadding],
    [label.leadingAnchor
        constraintGreaterThanOrEqualToAnchor:background.leadingAnchor
                                    constant:kBubbleHorizontalPadding],
    [background.trailingAnchor
        constraintGreaterThanOrEqualToAnchor:label.trailingAnchor
                                    constant:kBubbleHorizontalPadding],
    // Enforce the arrow's size, scaling by |kArrowScaleFactor| to prevent gaps
    // between the arrow and the background view.
    [self.arrow.widthAnchor constraintEqualToConstant:kArrowSize.width],
    [self.arrow.heightAnchor constraintEqualToConstant:kArrowSize.height]

  ];
  return constraints;
}

// Returns the constraint for the close button.
- (NSArray<NSLayoutConstraint*>*)closeButtonConstraints {
  UIView* closeButton = self.closeButton;
  NSArray<NSLayoutConstraint*>* constraints = @[
    [closeButton.widthAnchor constraintEqualToConstant:kCloseButtonSize],
    [closeButton.heightAnchor constraintEqualToConstant:kCloseButtonSize],
    [closeButton.leadingAnchor
        constraintGreaterThanOrEqualToAnchor:self.label.trailingAnchor],
    [closeButton.topAnchor constraintEqualToAnchor:self.background.topAnchor],
    [closeButton.trailingAnchor
        constraintEqualToAnchor:self.background.trailingAnchor],
  ];
  return constraints;
}

// Returns the constraint for the title label.
- (NSArray<NSLayoutConstraint*>*)titleLabelConstraints {
  UIView* titleLabel = self.titleLabel;
  UIView* label = self.label;
  NSArray<NSLayoutConstraint*>* constraints = @[
    [titleLabel.topAnchor constraintEqualToAnchor:self.background.topAnchor
                                         constant:kBubbleVerticalPadding],
    [titleLabel.bottomAnchor constraintEqualToAnchor:label.topAnchor],
    [titleLabel.leadingAnchor constraintEqualToAnchor:label.leadingAnchor],
    [titleLabel.trailingAnchor constraintEqualToAnchor:label.trailingAnchor],
  ];
  return constraints;
}

// Return the constraint that aligns the arrow to the bubble view. This depends
// on the bubble's alignment.
- (NSLayoutConstraint*)arrowAlignmentConstraint {
  // The anchor of the bubble which is aligned with the arrow's center anchor.
  NSLayoutAnchor* anchor;
  // The constant by which |anchor| is offset from the arrow's center anchor.
  CGFloat offset;
  switch (self.alignment) {
    case BubbleAlignmentLeading:
      // The anchor point is at a distance of |kBubbleAlignmentOffset|
      // from the bubble's leading edge. Center align the arrow with the anchor
      // point by aligning the center of the arrow with the leading edge of the
      // bubble view and adding an offset of |kBubbleAlignmentOffset|.
      anchor = self.leadingAnchor;
      offset = bubble_util::BubbleAlignmentOffset();
      break;
    case BubbleAlignmentCenter:
      // Since the anchor point is in the center of the bubble view, center the
      // arrow on the bubble view.
      anchor = self.centerXAnchor;
      offset = 0.0f;
      break;
    case BubbleAlignmentTrailing:
      // The anchor point is at a distance of |kBubbleAlignmentOffset|
      // from the bubble's trailing edge. Center align the arrow with the anchor
      // point by aligning the center of the arrow with the trailing edge of the
      // bubble view and adding an offset of |-kBubbleAlignmentOffset|.
      anchor = self.trailingAnchor;
      offset = -bubble_util::BubbleAlignmentOffset();
      break;
    default:
      NOTREACHED() << "Invalid bubble alignment " << self.alignment;
      return nil;
  }
  return
      [self.arrow.centerXAnchor constraintEqualToAnchor:anchor constant:offset];
}

// Return an array of constraints that depend on the bubble's arrow direction.
- (NSArray<NSLayoutConstraint*>*)arrowDirectionConstraints {
  NSArray<NSLayoutConstraint*>* constraints;
  if (self.direction == BubbleArrowDirectionUp) {
    constraints = @[
      [self.background.topAnchor constraintEqualToAnchor:self.arrow.topAnchor
                                                constant:kArrowSize.height],
      // Ensure that the top of the arrow is aligned with the top of the bubble
      // view and add a margin above the arrow.
      [self.arrow.topAnchor constraintEqualToAnchor:self.topAnchor
                                           constant:kBubbleMargin]
    ];
  } else {
    DCHECK(self.direction == BubbleArrowDirectionDown);
    constraints = @[
      [self.arrow.bottomAnchor
          constraintEqualToAnchor:self.background.bottomAnchor
                         constant:kArrowSize.height],
      // Ensure that the bottom of the arrow is aligned with the bottom of the
      // bubble view and add a margin below the arrow.
      [self.bottomAnchor constraintEqualToAnchor:self.arrow.bottomAnchor
                                        constant:kBubbleMargin]
    ];
  }
  return constraints;
}

#pragma mark - UIView overrides

// Override |willMoveToSuperview| to add view properties to the view hierarchy.
- (void)willMoveToSuperview:(UIView*)newSuperview {
  // If subviews have not been added to the view hierarchy, add them.
  if (self.needsAddSubviews) {
    [self addSubview:self.arrow];
    [self addSubview:self.background];
    [self addSubview:self.label];
    if (self.showsCloseButton) {
      [self addSubview:self.closeButton];
    }
    if (self.titleLabel) {
      [self addSubview:self.titleLabel];
    }
    // Set |needsAddSubviews| to NO to ensure that the subviews are only added
    // to the view hierarchy once.
    self.needsAddSubviews = NO;
    // Perform additional setup and layout operations, such as activating
    // constraints, adding the drop shadow, and setting the accessibility label.
    [self activateConstraints];
    [self addShadow];
    [self setAccessibilityLabel:self.label.text];
  }
  [super willMoveToSuperview:newSuperview];
}

// Calculates the optimal size of the text (label and title) with the available
// size to minimize whitespace.
- (CGSize)optimalTextSize:(CGSize)size {
  // Calculate the maximum width the text is allowed to use, and ensure that
  // the text does not exceed the maximum line width.
  CGFloat textMaxWidth = MIN(size.width, kMaxLabelWidth);
  CGSize textMaxSize = CGSizeMake(textMaxWidth, size.height);
  CGSize labelSize = [self.label sizeThatFits:textMaxSize];
  CGSize titleSize = CGSizeZero;
  if (self.titleLabel) {
    titleSize = [self.titleLabel sizeThatFits:textMaxSize];
  }
  CGFloat textWidth = MAX(labelSize.width, titleSize.width);
  CGFloat textHeight = labelSize.height + titleSize.height;
  CGSize textSize = CGSizeMake(textWidth, textHeight);
  return textSize;
}

// Override |sizeThatFits| to return the bubble's optimal size. Calculate
// optimal size by finding the labels' optimal size, and adding inset distances
// to the labels' dimensions. This method also enforces minimum bubble width to
// prevent strange, undesired behaviors, and maximum labels width to preserve
// readability.
- (CGSize)sizeThatFits:(CGSize)size {
  // The combined horizontal inset distance of the label and title with respect
  // to the bubble.
  CGFloat textHorizontalInset = kBubbleMargin * 2 + kBubbleHorizontalPadding;
  // Add close button size, which is on the trailing edge of the labels.
  if (self.showsCloseButton) {
    textHorizontalInset += MAX(kCloseButtonSize, kBubbleHorizontalPadding);
  } else {
    textHorizontalInset += kBubbleHorizontalPadding;
  }
  CGFloat textMaxWidth = size.width - textHorizontalInset;
  CGSize optimalTextSize =
      [self optimalTextSize:CGSizeMake(textMaxWidth, size.height)];

  // Ensure that the bubble is at least as wide as the minimum bubble width.
  CGFloat bubbleWidth =
      MAX(optimalTextSize.width + textHorizontalInset, [self minBubbleWidth]);
  // Calculate the height needed to display the bubble.
  CGFloat bubbleHeight = 2 * (kBubbleMargin + kBubbleVerticalPadding) +
                         kArrowSize.height + optimalTextSize.height;
  CGSize bubbleSize = CGSizeMake(bubbleWidth, bubbleHeight);
  return bubbleSize;
}

- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection
          hasDifferentColorAppearanceComparedToTraitCollection:
              previousTraitCollection]) {
    self.arrowLayer.fillColor = BubbleColor().CGColor;
  }
}

#pragma mark - Private sizes

// The minimum bubble width is two times the bubble alignment offset, which
// causes the bubble to appear center-aligned for short display text.
- (CGFloat)minBubbleWidth {
  return bubble_util::BubbleAlignmentOffset() * 2;
}

@end
