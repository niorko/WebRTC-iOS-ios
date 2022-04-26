// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/omnibox/popup/omnibox_pedal_annotator.h"

#include "base/strings/sys_string_conversions.h"
#include "components/omnibox/browser/actions/omnibox_action.h"
#include "components/omnibox/browser/actions/omnibox_pedal_concepts.h"
#include "components/omnibox/browser/autocomplete_match.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/omnibox_commands.h"
#import "ios/chrome/browser/ui/commands/open_new_tab_command.h"
#import "ios/chrome/browser/ui/omnibox/popup/popup_swift.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Hard-coded here to avoid dependency on //content. This needs to be kept in
// sync with kChromeUIScheme in `content/public/common/url_constants.h`.
const char kChromeUIScheme[] = "chrome";

}

@implementation OmniboxPedalAnnotator

- (OmniboxPedalData*)pedalForMatch:(const AutocompleteMatch&)match
                         incognito:(BOOL)incognito {
  if (!match.action) {
    return nil;
  }
  __weak id<ApplicationCommands> pedalsEndpoint = self.pedalsEndpoint;
  __weak id<OmniboxCommands> omniboxCommandHandler = self.omniboxCommandHandler;

  NSString* hint =
      base::SysUTF16ToNSString(match.action->GetLabelStrings().hint);
  NSString* suggestionContents = base::SysUTF16ToNSString(
      match.action->GetLabelStrings().suggestion_contents);

  switch (match.action->GetID()) {
    case (int)OmniboxPedalId::PLAY_CHROME_DINO_GAME: {
      NSString* urlStr = [NSString
          stringWithFormat:@"%s://%s", kChromeUIScheme, kChromeUIDinoHost];
      GURL url(base::SysNSStringToUTF8(urlStr));
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:urlStr
          accessibilityHint:suggestionContents
                  imageName:@"pedal_dino"
                  incognito:incognito
                     action:^{
                       OpenNewTabCommand* command =
                           [OpenNewTabCommand commandWithURLFromChrome:url
                                                           inIncognito:NO];
                       [pedalsEndpoint openURLInNewTab:command];
                     }];
    }
    case (int)OmniboxPedalId::CLEAR_BROWSING_DATA: {
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:
                       l10n_util::GetNSString(
                           IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_CLEAR_BROWSING_DATA)
          accessibilityHint:suggestionContents
                  imageName:@"pedal_clear_browsing_data"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint showClearBrowsingDataSettings];
                     }];
    }
    case (int)OmniboxPedalId::SET_CHROME_AS_DEFAULT_BROWSER: {
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:l10n_util::GetNSString(
                                IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_DEFAULT_BROWSER)
          accessibilityHint:suggestionContents
                  imageName:@"pedal_default_browser"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint
                           showDefaultBrowserSettingsFromViewController:nil];
                     }];
    }
    case (int)OmniboxPedalId::MANAGE_PASSWORDS: {
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:l10n_util::GetNSString(
                                IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_MANAGE_PASSWORDS)
          accessibilityHint:suggestionContents
                  imageName:@"pedal_passwords"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint
                           showSavedPasswordsSettingsFromViewController:nil
                                                       showCancelButton:NO];
                     }];
    }
    case (int)OmniboxPedalId::UPDATE_CREDIT_CARD: {
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:
                       l10n_util::GetNSString(
                           IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_UPDATE_CREDIT_CARD)
          accessibilityHint:suggestionContents
                  imageName:@"pedal_payments"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint showCreditCardSettings];
                     }];
    }
    case (int)OmniboxPedalId::LAUNCH_INCOGNITO: {
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:l10n_util::GetNSString(
                                IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_LAUNCH_INCOGNITO)
          accessibilityHint:suggestionContents
                  imageName:@"pedal_incognito"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint
                           openURLInNewTab:[OpenNewTabCommand
                                               incognitoTabCommand]];
                     }];
    }
    case (int)OmniboxPedalId::RUN_CHROME_SAFETY_CHECK: {
      NSString* subtitle = l10n_util::GetNSString(
          IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_RUN_CHROME_SAFETY_CHECK);
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:subtitle
          accessibilityHint:suggestionContents
                  imageName:@"pedal_safety_check"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint
                           showSafetyCheckSettingsAndStartSafetyCheck];
                     }];
    }
    case (int)OmniboxPedalId::MANAGE_CHROME_SETTINGS: {
      NSString* subtitle = l10n_util::GetNSString(
          IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_MANAGE_CHROME_SETTINGS);
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:subtitle
          accessibilityHint:suggestionContents
                  imageName:@"pedal_settings"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint showSettingsFromViewController:nil];
                     }];
    }
    case (int)OmniboxPedalId::VIEW_CHROME_HISTORY: {
      return [[OmniboxPedalData alloc]
              initWithTitle:hint
                   subtitle:
                       l10n_util::GetNSString(
                           IDS_IOS_OMNIBOX_PEDAL_SUBTITLE_VIEW_CHROME_HISTORY)
          accessibilityHint:suggestionContents
                  imageName:@"pedal_history"
                  incognito:incognito
                     action:^{
                       [omniboxCommandHandler cancelOmniboxEdit];
                       [pedalsEndpoint showHistory];
                     }];
    }
    default:
      return nil;
  }
}

@end
