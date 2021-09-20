// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/first_run/default_browser/instruction_view.h"

#import "ios/chrome/browser/ui/first_run/first_run_constants.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_cells_constants.h"
#include "ios/chrome/common/string_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"
#include "ios/chrome/common/ui/util/dynamic_type_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

constexpr CGFloat kStepNumberLabelSize = 20;
constexpr CGFloat kLeadingMargin = 15;
constexpr CGFloat kSpacing = 14;
constexpr CGFloat kVerticalMargin = 12;
constexpr CGFloat kTrailingMargin = 16;
constexpr CGFloat kCornerRadius = 12;
constexpr CGFloat kSeparatorLeadingMargin = 60;
constexpr CGFloat kSeparatorHeight = 0.5;

}  // namespace

@implementation InstructionView

#pragma mark - Public

- (instancetype)initWithList:(NSArray<NSString*>*)instructionList {
  self = [super init];
  if (self) {
    UIStackView* stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    [stackView addArrangedSubview:[self createLineInstruction:instructionList[0]
                                                   stepNumber:1]];
    for (NSUInteger i = 1; i < [instructionList count]; i++) {
      [stackView addArrangedSubview:[self createLineSeparator]];
      [stackView
          addArrangedSubview:[self createLineInstruction:instructionList[i]
                                              stepNumber:i + 1]];
    }
    [self addSubview:stackView];
    AddSameConstraints(self, stackView);
    self.backgroundColor = [UIColor colorNamed:kGrey100Color];
    self.layer.cornerRadius = kCornerRadius;
  }
  return self;
}

#pragma mark - Private

// Creates a separator line.
- (UIView*)createLineSeparator {
  UIView* liner = [[UIView alloc] init];
  UIView* separator = [[UIView alloc] init];
  separator.backgroundColor = [UIColor colorNamed:kGrey300Color];
  separator.translatesAutoresizingMaskIntoConstraints = NO;

  [liner addSubview:separator];

  [NSLayoutConstraint activateConstraints:@[
    [separator.leadingAnchor constraintEqualToAnchor:liner.leadingAnchor
                                            constant:kSeparatorLeadingMargin],
    [separator.trailingAnchor constraintEqualToAnchor:liner.trailingAnchor],
    [separator.topAnchor constraintEqualToAnchor:liner.topAnchor],
    [separator.bottomAnchor constraintEqualToAnchor:liner.bottomAnchor],
    [liner.heightAnchor constraintEqualToConstant:kSeparatorHeight]
  ]];

  return liner;
}

// Creates an instruction line which contain a step number and an instruction
// text.
- (UIView*)createLineInstruction:(NSString*)instruction
                      stepNumber:(NSUInteger)stepNumber {
  UIView* stepNumberView = [self createStepNumberView:stepNumber];
  stepNumberView.translatesAutoresizingMaskIntoConstraints = NO;

  UILabel* instructionLabel = [[UILabel alloc] init];
  instructionLabel.textColor = [UIColor colorNamed:kGrey800Color];
  instructionLabel.font =
      [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
  instructionLabel.attributedText = [self putBoldPartInString:instruction];
  instructionLabel.numberOfLines = 0;
  instructionLabel.adjustsFontForContentSizeCategory = YES;
  instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;

  UIView* line = [[UIView alloc] init];
  [line addSubview:stepNumberView];
  [line addSubview:instructionLabel];

  [NSLayoutConstraint activateConstraints:@[
    [stepNumberView.leadingAnchor constraintEqualToAnchor:line.leadingAnchor
                                                 constant:kLeadingMargin],
    [stepNumberView.centerYAnchor constraintEqualToAnchor:line.centerYAnchor],
    [instructionLabel.leadingAnchor
        constraintEqualToAnchor:stepNumberView.trailingAnchor
                       constant:kSpacing],
    [instructionLabel.centerYAnchor constraintEqualToAnchor:line.centerYAnchor],
    [instructionLabel.bottomAnchor constraintEqualToAnchor:line.bottomAnchor
                                                  constant:-kVerticalMargin],
    [instructionLabel.topAnchor constraintEqualToAnchor:line.topAnchor
                                               constant:kVerticalMargin],
    [instructionLabel.trailingAnchor constraintEqualToAnchor:line.trailingAnchor
                                                    constant:kTrailingMargin]
  ]];

  return line;
}

// Parses a string with an embedded bold part inside, delineated by
// "BEGIN_BOLD" and "END_BOLD". Returns an attributed string with bold part.
- (NSAttributedString*)putBoldPartInString:(NSString*)string {
  StringWithTag parsedString = ParseStringWithTag(
      string, first_run::kBeginBoldTag, first_run::kEndBoldTag);

  NSMutableAttributedString* attributedString =
      [[NSMutableAttributedString alloc] initWithString:parsedString.string];

  UIFontDescriptor* defaultDescriptor = [UIFontDescriptor
      preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];

  UIFontDescriptor* boldDescriptor = [[UIFontDescriptor
      preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline]
      fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];

  [attributedString addAttribute:NSFontAttributeName
                           value:[UIFont fontWithDescriptor:defaultDescriptor
                                                       size:0.0]
                           range:NSMakeRange(0, parsedString.string.length)];

  [attributedString addAttribute:NSFontAttributeName
                           value:[UIFont fontWithDescriptor:boldDescriptor
                                                       size:0.0]
                           range:parsedString.range];

  return attributedString;
}

// Creates a view with a round numbered label in it.
- (UIView*)createStepNumberView:(NSInteger)stepNumber {
  UILabel* stepNumberLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  stepNumberLabel.translatesAutoresizingMaskIntoConstraints = NO;
  stepNumberLabel.textColor = [UIColor colorNamed:kBlueColor];
  stepNumberLabel.textAlignment = NSTextAlignmentCenter;
  stepNumberLabel.text = [@(stepNumber) stringValue];
  stepNumberLabel.font = PreferredFontForTextStyleWithMaxCategory(
      UIFontTextStyleFootnote,
      self.traitCollection.preferredContentSizeCategory,
      UIContentSizeCategoryExtraExtraExtraLarge);

  UIFontDescriptor* boldFontDescriptor = [stepNumberLabel.font.fontDescriptor
      fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
  stepNumberLabel.font = [UIFont fontWithDescriptor:boldFontDescriptor size:0];

  stepNumberLabel.layer.cornerRadius = kStepNumberLabelSize / 2;
  stepNumberLabel.layer.backgroundColor =
      [UIColor colorNamed:kPrimaryBackgroundColor].CGColor;

  UIView* labelContainer = [[UIView alloc] initWithFrame:CGRectZero];
  labelContainer.translatesAutoresizingMaskIntoConstraints = NO;

  [labelContainer addSubview:stepNumberLabel];

  [NSLayoutConstraint activateConstraints:@[
    [stepNumberLabel.centerYAnchor
        constraintEqualToAnchor:labelContainer.centerYAnchor],
    [stepNumberLabel.centerXAnchor
        constraintEqualToAnchor:labelContainer.centerXAnchor],
    [stepNumberLabel.widthAnchor
        constraintEqualToConstant:kStepNumberLabelSize],
    [stepNumberLabel.heightAnchor
        constraintEqualToConstant:kStepNumberLabelSize],

    [labelContainer.widthAnchor
        constraintEqualToConstant:kTableViewIconImageSize],
    [labelContainer.heightAnchor
        constraintEqualToAnchor:labelContainer.widthAnchor],
  ]];

  return labelContainer;
}

@end
