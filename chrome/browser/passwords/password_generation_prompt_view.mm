// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/passwords/password_generation_prompt_view.h"

#include <memory>

#include "base/strings/sys_string_conversions.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/passwords/password_generation_prompt_delegate.h"
#import "ios/chrome/browser/ui/rtl_geometry.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#import "ios/chrome/browser/ui/util/constraints_ui_util.h"
#include "ios/chrome/common/string_util.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ios/chrome/grit/ios_theme_resources.h"
#import "ios/third_party/material_components_ios/src/components/Buttons/src/MaterialButtons.h"
#import "ios/third_party/material_components_ios/src/components/Typography/src/MaterialTypography.h"
#include "ui/base/l10n/l10n_util.h"
#include "ui/base/resource/resource_bundle.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Material Design Component constraints.
const CGFloat kMDCPadding = 24;

// Horizontal and vertical padding for the entire view.
const CGFloat kPadding = 8.0f;

// Colors for primary and secondary user interactions.
const int kPrimaryActionColor = 0x5595FE;

// Constants for the password label.
const int kPasswordLabelFontSize = 16;
const int kPasswordLabelFontColor = 0x787878;
const CGFloat kPasswordLabelVerticalPadding = 5.0f;

// Constants for the title label.
const int kTitleLabelFontSize = 16;
const int kTitleLabelFontColor = 0x333333;
const CGFloat kTitleLabelVerticalPadding = 5.0f;

// Constants for the description label.
const int kDescriptionLabelFontSize = 14;
const int kDescriptionLabelFontColor = 0x787878;
const int kDescriptionLabelLineSpacing = 8;
const CGFloat kDescriptionLabelTopPadding = 10.0f;

}  // namespace

// A view that prompts the user with a password generated by Chrome and explains
// what that means. The user can accept the password, cancel password
// generation, or click a link to view all their saved passwords.
@interface PasswordGenerationPromptView : UIView<UITextViewDelegate>

// Initializes a PasswordGenerationPromptView that shows the specified
// |password| and delegates user interaction events to |delegate|.
- (instancetype)initWithPassword:(NSString*)password
                        delegate:(id<PasswordGenerationPromptDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

- (instancetype)initWithCoder:(NSCoder*)aDecoder NS_UNAVAILABLE;

// Configure the view, adding subviews and constraints.
- (void)configure;

// Returns an autoreleased label for the title of the view.
- (UILabel*)titleLabel;

// Returns an autoreleased label to propose a generated password.
- (UILabel*)passwordLabel:(NSString*)password;

// Returns an autoreleased text view to explain password generation with a link.
- (UITextView*)description;

// Returns an autoreleased view that shows the lock icon.
- (UIImageView*)keyIconView;

@end

@implementation PasswordGenerationPromptView {
  NSString* _password;
  __weak id<PasswordGenerationPromptDelegate> _delegate;
  NSURL* _URL;
  UILabel* _title;
}

- (instancetype)initWithPassword:(NSString*)password
                        delegate:
                            (id<PasswordGenerationPromptDelegate>)delegate {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _URL = [NSURL URLWithString:@"chromeinternal://showpasswords"];
    _delegate = delegate;
    _password = [password copy];
  }
  return self;
}

- (void)configure {
  UIView* headerView = [[UIView alloc] initWithFrame:CGRectZero];
  UIImageView* icon = [self keyIconView];
  UILabel* title = [self titleLabel];
  UILabel* password = [self passwordLabel:_password];
  UITextView* description = [self description];

  _title = title;

  [headerView addSubview:icon];
  [headerView addSubview:title];
  [headerView addSubview:password];
  [self addSubview:headerView];
  [self addSubview:description];

  // -----------------------------------------------
  // |                                             |
  // |  (lock)  Use password generated by Chrome?  |
  // |          Fsf6s88fssdf                       |
  // |                                             |
  // |  blah blah blah description blah blah       |
  // |  blah blah [link to passwords] blah.        |
  // |                                             |
  // -----------------------------------------------

  [headerView setTranslatesAutoresizingMaskIntoConstraints:NO];
  [icon setTranslatesAutoresizingMaskIntoConstraints:NO];
  [title setTranslatesAutoresizingMaskIntoConstraints:NO];
  [password setTranslatesAutoresizingMaskIntoConstraints:NO];
  [description setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSArray* constraints = @[
    @"H:|[keyIcon]-[title]|", @"V:|[keyIcon]",
    @"V:|-(padding)-[header]-(descriptionPadding)-[description]|",
    @"H:|-(padding)-[header]-(padding)-|",
    @"H:|-(padding)-[description]-(padding)-|"
  ];

  NSDictionary* viewsDictionary = @{
    @"keyIcon" : icon,
    @"title" : title,
    @"passwd" : password,
    @"header" : headerView,
    @"description" : description
  };

  NSDictionary* metrics = @{
    @"padding" : @(kPadding),
    @"passwordPadding" : @(kPasswordLabelVerticalPadding),
    @"descriptionPadding" : @(kDescriptionLabelTopPadding),
    @"titlePadding" : @(kTitleLabelVerticalPadding)
  };

  ApplyVisualConstraintsWithMetricsAndOptions(
      constraints, viewsDictionary, metrics, LayoutOptionForRTLSupport());

  [headerView
      addConstraints:
          [NSLayoutConstraint
              constraintsWithVisualFormat:
                  @"V:|-(titlePadding)-[title]-(passwordPadding)-[passwd]|"
                                  options:NSLayoutFormatAlignAllLeading
                                  metrics:metrics
                                    views:viewsDictionary]];

  [title setContentHuggingPriority:UILayoutPriorityRequired
                           forAxis:UILayoutConstraintAxisVertical];
  [icon setContentHuggingPriority:UILayoutPriorityRequired
                          forAxis:UILayoutConstraintAxisHorizontal];
  [headerView setContentHuggingPriority:UILayoutPriorityRequired
                                forAxis:UILayoutConstraintAxisVertical];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  // Make sure the title is spread on multiple lines if needed.
  [_title setPreferredMaxLayoutWidth:[_title frame].size.width];
}

- (UILabel*)titleLabel {
  NSMutableDictionary* attrsDictionary = [NSMutableDictionary
      dictionaryWithObject:[[MDCTypography fontLoader]
                               mediumFontOfSize:kTitleLabelFontSize]
                    forKey:NSFontAttributeName];
  [attrsDictionary setObject:UIColorFromRGB(kTitleLabelFontColor)
                      forKey:NSForegroundColorAttributeName];

  NSMutableAttributedString* string = [[NSMutableAttributedString alloc]
      initWithString:l10n_util::GetNSString(
                         IDS_IOS_GENERATED_PASSWORD_PROMPT_TITLE)
          attributes:attrsDictionary];

  UILabel* titleLabel = [[UILabel alloc] init];
  [titleLabel setAttributedText:string];
  [titleLabel setNumberOfLines:0];
  [titleLabel sizeToFit];
  return titleLabel;
}

- (UILabel*)passwordLabel:(NSString*)password {
  UILabel* passwordLabel = [[UILabel alloc] init];
  [passwordLabel setText:password];
  [passwordLabel setTextColor:UIColorFromRGB(kPasswordLabelFontColor)];
  [passwordLabel setFont:[[MDCTypography fontLoader]
                             regularFontOfSize:kPasswordLabelFontSize]];
  [passwordLabel setNumberOfLines:1];
  [passwordLabel sizeToFit];
  return passwordLabel;
}

- (UITextView*)description {
  NSRange linkRange;
  NSString* description = ParseStringWithLink(
      l10n_util::GetNSString(IDS_IOS_GENERATED_PASSWORD_PROMPT_DESCRIPTION),
      &linkRange);

  NSMutableParagraphStyle* paragraphStyle =
      [[NSMutableParagraphStyle alloc] init];
  [paragraphStyle setLineSpacing:kDescriptionLabelLineSpacing];

  NSDictionary* attributeDictionary =
      [NSDictionary dictionaryWithObjectsAndKeys:
                        UIColorFromRGB(kDescriptionLabelFontColor),
                        NSForegroundColorAttributeName, paragraphStyle,
                        NSParagraphStyleAttributeName,
                        [[MDCTypography fontLoader]
                            regularFontOfSize:kDescriptionLabelFontSize],
                        NSFontAttributeName, nil];

  NSMutableAttributedString* attributedString =
      [[NSMutableAttributedString alloc] initWithString:description
                                             attributes:attributeDictionary];

  UITextView* descriptionView =
      [[UITextView alloc] initWithFrame:CGRectZero textContainer:nil];
  descriptionView.scrollEnabled = NO;
  descriptionView.selectable = YES;
  descriptionView.editable = NO;
  descriptionView.delegate = self;
  descriptionView.userInteractionEnabled = YES;

  descriptionView.linkTextAttributes =
      [NSDictionary dictionaryWithObject:UIColorFromRGB(kPrimaryActionColor)
                                  forKey:NSForegroundColorAttributeName];

  [attributedString addAttribute:NSLinkAttributeName
                           value:_URL
                           range:linkRange];
  descriptionView.attributedText = attributedString;
  return descriptionView;
}

- (UIImageView*)keyIconView {
  UIImage* keyIcon = ui::ResourceBundle::GetSharedInstance()
                         .GetImageNamed(IDR_IOS_INFOBAR_AUTOLOGIN)
                         .ToUIImage();
  UIImageView* keyIconView = [[UIImageView alloc] initWithImage:keyIcon];
  [keyIconView setFrame:{CGPointZero, keyIcon.size}];
  return keyIconView;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView*)textView
    shouldInteractWithURL:(NSURL*)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction {
  DCHECK([URL isEqual:_URL]);
  [_delegate showSavedPasswords:self];
  return NO;
}

@end

#pragma mark - Classes emulating MDCDialog

@interface PasswordGenerationPromptDialog () {
  __weak UIViewController* _viewController;
  __weak id<PasswordGenerationPromptDelegate> _weakDelegate;
}

// Dismiss the dialog.
- (void)dismiss;
// Callback called when the user accept to use the password.
- (void)acceptPassword;
// Creates the view containing the buttons.
- (UIView*)createButtons;

@end

@implementation PasswordGenerationPromptDialog

- (instancetype)initWithDelegate:(id<PasswordGenerationPromptDelegate>)delegate
                  viewController:(UIViewController*)viewController {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _viewController = viewController;
    _weakDelegate = delegate;
  }
  return self;
}

- (void)dismiss {
  [_viewController dismissViewControllerAnimated:NO completion:nil];
}

- (void)acceptPassword {
  [_weakDelegate acceptPasswordGeneration:nil];
  [self dismiss];
}

// Creates the view containing the buttons.
- (UIView*)createButtons {
  UIView* view = [[UIView alloc] initWithFrame:CGRectZero];

  NSString* cancelTitle = l10n_util::GetNSString(IDS_CANCEL);
  MDCFlatButton* cancelButton = [[MDCFlatButton alloc] init];
  [cancelButton setTitle:cancelTitle forState:UIControlStateNormal];
  [cancelButton sizeToFit];
  [cancelButton setTitleColor:[UIColor blackColor]
                     forState:UIControlStateNormal];
  [cancelButton addTarget:self
                   action:@selector(dismiss)
         forControlEvents:UIControlEventTouchUpInside];

  NSString* acceptTitle =
      l10n_util::GetNSString(IDS_IOS_GENERATED_PASSWORD_ACCEPT);
  MDCFlatButton* OKButton = [[MDCFlatButton alloc] init];
  [OKButton setTitle:acceptTitle forState:UIControlStateNormal];
  [OKButton sizeToFit];
  [OKButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  [OKButton addTarget:self
                action:@selector(acceptPassword)
      forControlEvents:UIControlEventTouchUpInside];

  [cancelButton setTranslatesAutoresizingMaskIntoConstraints:NO];
  [OKButton setTranslatesAutoresizingMaskIntoConstraints:NO];

  [view addSubview:cancelButton];
  [view addSubview:OKButton];

  NSDictionary* views = @{ @"cancel" : cancelButton, @"ok" : OKButton };
  [view addConstraints:[NSLayoutConstraint
                           constraintsWithVisualFormat:@"V:|-[cancel]-|"
                                               options:0
                                               metrics:nil
                                                 views:views]];
  [view addConstraints:[NSLayoutConstraint
                           constraintsWithVisualFormat:@"H:[cancel]-[ok]-|"
                                               options:NSLayoutFormatAlignAllTop
                                               metrics:nil
                                                 views:views]];

  return view;
}

// Creates the view containing the password text and the buttons.
- (void)configureGlobalViewWithPassword:(NSString*)password {
  PasswordGenerationPromptView* passwordContentView =
      [[PasswordGenerationPromptView alloc] initWithPassword:password
                                                    delegate:_weakDelegate];

  [passwordContentView configure];

  [passwordContentView setTranslatesAutoresizingMaskIntoConstraints:NO];

  UIView* buttons = [self createButtons];
  [buttons setTranslatesAutoresizingMaskIntoConstraints:NO];

  [self addSubview:passwordContentView];
  [self addSubview:buttons];

  NSDictionary* views =
      @{ @"view" : passwordContentView,
         @"buttons" : buttons };
  NSDictionary* metrics = @{ @"MDCPadding" : @(kMDCPadding) };
  [self addConstraints:[NSLayoutConstraint
                           constraintsWithVisualFormat:
                               @"V:|[view]-(MDCPadding)-[buttons]-|"
                                               options:NSLayoutAttributeTrailing
                                               metrics:metrics
                                                 views:views]];
  [self addConstraints:[NSLayoutConstraint
                           constraintsWithVisualFormat:@"H:|[view]|"
                                               options:0
                                               metrics:nil
                                                 views:views]];
}

@end
