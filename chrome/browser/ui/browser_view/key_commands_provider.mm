// Copyright 2016 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/browser_view/key_commands_provider.h"

#import "components/sessions/core/tab_restore_service_helper.h"
#import "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/find_in_page/find_tab_helper.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/sessions/ios_chrome_tab_restore_service_factory.h"
#import "ios/chrome/browser/ui/commands/bookmarks_commands.h"
#import "ios/chrome/browser/ui/commands/open_new_tab_command.h"
#import "ios/chrome/browser/ui/keyboard/UIKeyCommand+Chrome.h"
#import "ios/chrome/browser/ui/main/layout_guide_util.h"
#import "ios/chrome/browser/ui/util/keyboard_observer_helper.h"
#import "ios/chrome/browser/ui/util/layout_guide_names.h"
#import "ios/chrome/browser/ui/util/rtl_geometry.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/browser/ui/util/util_swift.h"
#import "ios/chrome/browser/url_loading/url_loading_util.h"
#import "ios/chrome/browser/web/web_navigation_browser_agent.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ios/web/public/web_state.h"
#import "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface KeyCommandsProvider ()

// The current browser object.
@property(nonatomic, assign) Browser* browser;

// The view controller delegating key command actions handling.
@property(nonatomic, weak) UIViewController* viewController;

// Configures the responder following the receiver in the responder chain.
@property(nonatomic, weak) UIResponder* followingNextResponder;

// The current navigation agent.
@property(nonatomic, assign, readonly)
    WebNavigationBrowserAgent* navigationAgent;

// Whether the Find in Page… UI is currently available.
@property(nonatomic, readonly, getter=isFindInPageAvailable)
    BOOL findInPageAvailable;

// The number of tabs displayed.
@property(nonatomic, readonly) NSUInteger tabsCount;

// Whether text is currently being edited.
@property(nonatomic, readonly, getter=isEditingText) BOOL editingText;

@end

@implementation KeyCommandsProvider

#pragma mark - Public

- (instancetype)initWithBrowser:(Browser*)browser {
  DCHECK(browser);
  self = [super init];
  if (self) {
    _browser = browser;
  }
  return self;
}

- (void)respondBetweenViewController:(UIViewController*)viewController
                        andResponder:(UIResponder*)nextResponder {
  _viewController = viewController;
  _followingNextResponder = nextResponder;
}

#pragma mark - UIResponder

- (UIResponder*)nextResponder {
  return _followingNextResponder;
}

- (NSArray<UIKeyCommand*>*)keyCommands {
  __weak __typeof(self) weakSelf = self;

  const BOOL hasTabs = self.tabsCount > 0;

  const BOOL useRTLLayout = UseRTLLayout();

  // Blocks for navigating forward/back.
  void (^browseLeft)();
  void (^browseRight)();
  if (useRTLLayout) {
    browseLeft = ^{
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf.navigationAgent->CanGoForward())
        strongSelf.navigationAgent->GoForward();
    };
    browseRight = ^{
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf.navigationAgent->CanGoBack())
        strongSelf.navigationAgent->GoBack();
    };
  } else {
    browseLeft = ^{
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf.navigationAgent->CanGoBack())
        strongSelf.navigationAgent->GoBack();
    };
    browseRight = ^{
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf.navigationAgent->CanGoForward())
        strongSelf.navigationAgent->GoForward();
    };
  }

  // Blocks for next/previous tab.
  void (^showTabLeft)();
  void (^showTabRight)();
  if (useRTLLayout) {
    showTabLeft = ^{
      [weakSelf showNextTab];
    };
    showTabRight = ^{
      [weakSelf showPreviousTab];
    };
  } else {
    showTabLeft = ^{
      [weakSelf showPreviousTab];
    };
    showTabRight = ^{
      [weakSelf showNextTab];
    };
  }

  const int browseLeftDescriptionID = useRTLLayout
                                          ? IDS_IOS_KEYBOARD_HISTORY_FORWARD
                                          : IDS_IOS_KEYBOARD_HISTORY_BACK;
  const int browseRightDescriptionID = useRTLLayout
                                           ? IDS_IOS_KEYBOARD_HISTORY_BACK
                                           : IDS_IOS_KEYBOARD_HISTORY_FORWARD;

  // Initialize the array of commands with an estimated capacity.
  NSMutableArray<UIKeyCommand*>* keyCommands = [NSMutableArray array];

  // List the commands that always appear in the HUD. They appear in the HUD
  // since they have titles.
  [keyCommands addObjectsFromArray:@[
    [UIKeyCommand cr_keyCommandWithInput:@"t"
                           modifierFlags:KeyModifierCommand
                                   title:l10n_util::GetNSStringWithFixup(
                                             IDS_IOS_TOOLS_MENU_NEW_TAB)
                                  action:^{
                                    [weakSelf openNewTab];
                                  }],
    [UIKeyCommand
        cr_keyCommandWithInput:@"n"
                 modifierFlags:KeyModifierShiftCommand
                         title:l10n_util::GetNSStringWithFixup(
                                   IDS_IOS_TOOLS_MENU_NEW_INCOGNITO_TAB)
                        action:^{
                          [weakSelf openNewIncognitoTab];
                        }],
    [UIKeyCommand cr_keyCommandWithInput:@"t"
                           modifierFlags:KeyModifierShiftCommand
                                   title:l10n_util::GetNSStringWithFixup(
                                             IDS_IOS_KEYBOARD_REOPEN_CLOSED_TAB)
                                  action:^{
                                    [weakSelf reopenClosedTab];
                                  }],
  ]];

  // List the commands that only appear when there is at least a tab. When they
  // appear, they are in the HUD since they have titles.
  if (hasTabs) {
    if (self.findInPageAvailable) {
      [keyCommands addObjectsFromArray:@[

        [UIKeyCommand
            cr_keyCommandWithInput:@"f"
                     modifierFlags:KeyModifierCommand
                             title:l10n_util::GetNSStringWithFixup(
                                       IDS_IOS_TOOLS_MENU_FIND_IN_PAGE)
                            action:^{
                              [weakSelf openFindInPage];
                            }],
        [UIKeyCommand cr_keyCommandWithInput:@"g"
                               modifierFlags:KeyModifierCommand
                                       title:nil
                                      action:^{
                                        [weakSelf findNextStringInPage];
                                      }],
        [UIKeyCommand cr_keyCommandWithInput:@"g"
                               modifierFlags:KeyModifierShiftCommand
                                       title:nil
                                      action:^{
                                        [weakSelf findPreviousStringInPage];
                                      }]
      ]];
    }

    [keyCommands addObjectsFromArray:@[
      [UIKeyCommand cr_keyCommandWithInput:@"l"
                             modifierFlags:KeyModifierCommand
                                     title:l10n_util::GetNSStringWithFixup(
                                               IDS_IOS_KEYBOARD_OPEN_LOCATION)
                                    action:^{
                                      [weakSelf focusOmnibox];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"w"
                             modifierFlags:KeyModifierCommand
                                     title:l10n_util::GetNSStringWithFixup(
                                               IDS_IOS_TOOLS_MENU_CLOSE_TAB)
                                    action:^{
                                      [weakSelf closeTab];
                                    }],
    ]];

    // Deal with the multiple next/previous tab commands we have, only one pair
    // of which appears in the HUD. Take RTL into account for the direction.
    const int tabLeftDescriptionID = useRTLLayout
                                          ? IDS_IOS_KEYBOARD_NEXT_TAB
                                          : IDS_IOS_KEYBOARD_PREVIOUS_TAB;
    const int tabRightDescriptionID = useRTLLayout
                                           ? IDS_IOS_KEYBOARD_PREVIOUS_TAB
                                           : IDS_IOS_KEYBOARD_NEXT_TAB;
    NSString* tabLeftTitle = l10n_util::GetNSStringWithFixup(
        tabLeftDescriptionID);
    NSString* tabRightTitle = l10n_util::GetNSStringWithFixup(
        tabRightDescriptionID);
    [keyCommands addObjectsFromArray:@[
      [UIKeyCommand cr_keyCommandWithInput:UIKeyInputLeftArrow
                             modifierFlags:KeyModifierAltCommand
                                     title:tabLeftTitle
                                    action:showTabLeft],
      [UIKeyCommand cr_keyCommandWithInput:UIKeyInputRightArrow
                             modifierFlags:KeyModifierAltCommand
                                     title:tabRightTitle
                                    action:showTabRight],
      [UIKeyCommand cr_keyCommandWithInput:@"{"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:showTabLeft],
      [UIKeyCommand cr_keyCommandWithInput:@"}"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:showTabRight],
    ]];

    [keyCommands addObjectsFromArray:@[
      [UIKeyCommand
          cr_keyCommandWithInput:@"d"
                   modifierFlags:KeyModifierCommand
                           title:l10n_util::GetNSStringWithFixup(
                                     IDS_IOS_KEYBOARD_BOOKMARK_THIS_PAGE)
                          action:^{
                            [weakSelf bookmarkThisPage];
                          }],
      [UIKeyCommand cr_keyCommandWithInput:@"r"
                             modifierFlags:KeyModifierCommand
                                     title:l10n_util::GetNSStringWithFixup(
                                               IDS_IOS_ACCNAME_RELOAD)
                                    action:^{
                                      [weakSelf reload];
                                    }],
    ]];

    // Since cmd+left and cmd+right are valid system shortcuts when editing
    // text, don't register those if text is being edited.
    if (!self.editingText) {
      [keyCommands addObjectsFromArray:@[
        [UIKeyCommand cr_keyCommandWithInput:UIKeyInputLeftArrow
                               modifierFlags:KeyModifierCommand
                                       title:l10n_util::GetNSStringWithFixup(
                                                 browseLeftDescriptionID)
                                      action:browseLeft],
        [UIKeyCommand cr_keyCommandWithInput:UIKeyInputRightArrow
                               modifierFlags:KeyModifierCommand
                                       title:l10n_util::GetNSStringWithFixup(
                                                 browseRightDescriptionID)
                                      action:browseRight],
      ]];
    }

    NSString* voiceSearchTitle = l10n_util::GetNSStringWithFixup(
        IDS_IOS_VOICE_SEARCH_KEYBOARD_DISCOVERY_TITLE);
    [keyCommands addObjectsFromArray:@[
      [UIKeyCommand cr_keyCommandWithInput:@"y"
                             modifierFlags:KeyModifierCommand
                                     title:l10n_util::GetNSStringWithFixup(
                                               IDS_HISTORY_SHOW_HISTORY)
                                    action:^{
                                      [weakSelf showHistory];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"."
                             modifierFlags:KeyModifierShiftCommand
                                     title:voiceSearchTitle
                                    action:^{
                                      [weakSelf startVoiceSearch];
                                    }],
    ]];
  }

  if (self.canDismissModals) {
    [keyCommands addObjectsFromArray:@[
      [UIKeyCommand cr_keyCommandWithInput:UIKeyInputEscape
                             modifierFlags:KeyModifierNone
                                     title:nil
                                    action:^{
                                      [weakSelf dismissModalDialogs];
                                    }],
    ]];
  }

  // List the commands that don't appear in the HUD but are always present.
  [keyCommands addObjectsFromArray:@[
    [UIKeyCommand cr_keyCommandWithInput:@"n"
                           modifierFlags:KeyModifierCommand
                                   title:nil
                                  action:^{
                                    [weakSelf openNewTab];
                                  }],
    [UIKeyCommand cr_keyCommandWithInput:@","
                           modifierFlags:KeyModifierCommand
                                   title:nil
                                  action:^{
                                    [weakSelf showSettings];
                                  }],
  ]];

  // List the commands that don't appear in the HUD and only appear when there
  // is at least a tab.
  if (hasTabs) {
    [keyCommands addObjectsFromArray:@[
      [UIKeyCommand cr_keyCommandWithInput:@"["
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:browseLeft],
      [UIKeyCommand cr_keyCommandWithInput:@"]"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:browseRight],
      [UIKeyCommand cr_keyCommandWithInput:@"."
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf stop];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"?"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showHelpPage];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"l"
                             modifierFlags:KeyModifierAltCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showDownloadsFolder];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"1"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab0];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"2"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab1];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"3"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab2];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"4"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab3];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"5"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab4];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"6"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab5];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"7"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab6];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"8"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showTab7];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"9"
                             modifierFlags:KeyModifierCommand
                                     title:nil
                                    action:^{
                                      [weakSelf showLastTab];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"\t"
                             modifierFlags:KeyModifierControlShift
                                     title:nil
                                    action:^{
                                      [weakSelf showPreviousTab];
                                    }],
      [UIKeyCommand cr_keyCommandWithInput:@"\t"
                             modifierFlags:KeyModifierControl
                                     title:nil
                                    action:^{
                                      [weakSelf showNextTab];
                                    }],
    ]];
  }

  return keyCommands;
}

#pragma mark - Actions

- (void)openNewTab {
  OpenNewTabCommand* newTabCommand = [OpenNewTabCommand command];
  newTabCommand.shouldFocusOmnibox = YES;
  [_dispatcher openURLInNewTab:newTabCommand];
}

- (void)openNewIncognitoTab {
  OpenNewTabCommand* newIncognitoTabCommand =
      [OpenNewTabCommand incognitoTabCommand];
  newIncognitoTabCommand.shouldFocusOmnibox = YES;
  [_dispatcher openURLInNewTab:newIncognitoTabCommand];
}

- (void)reopenClosedTab {
  ChromeBrowserState* browserState = self.browser->GetBrowserState();
  sessions::TabRestoreService* const tabRestoreService =
      IOSChromeTabRestoreServiceFactory::GetForBrowserState(browserState);
  if (!tabRestoreService || tabRestoreService->entries().empty())
    return;

  const std::unique_ptr<sessions::TabRestoreService::Entry>& entry =
      tabRestoreService->entries().front();
  // Only handle the TAB type.
  // TODO(crbug.com/1056596) : Support WINDOW restoration under multi-window.
  if (entry->type != sessions::TabRestoreService::TAB)
    return;

  [self.dispatcher openURLInNewTab:[OpenNewTabCommand command]];
  RestoreTab(entry->id, WindowOpenDisposition::CURRENT_TAB, self.browser);
}

- (void)openFindInPage {
  [_dispatcher openFindInPage];
}

- (void)findNextStringInPage {
  [_dispatcher findNextStringInPage];
}

- (void)findPreviousStringInPage {
  [_dispatcher findPreviousStringInPage];
}

- (void)focusOmnibox {
  [_omniboxHandler focusOmnibox];
}

- (void)closeTab {
  // -closeCurrentTab might destroy the object that implements this shortcut
  // (BVC), so this selector might not be registered with the dispatcher
  // anymore. Check if it's still available. See crbug.com/967637 for context.
  if ([_dispatcher respondsToSelector:@selector(closeCurrentTab)]) {
    [_browserCoordinatorCommandsHandler closeCurrentTab];
  }
}

- (void)showNextTab {
  WebStateList* webStateList = self.browser->GetWebStateList();
  if (!webStateList)
    return;

  int activeIndex = webStateList->active_index();
  if (activeIndex == WebStateList::kInvalidIndex)
    return;

  // If the active index isn't the last index, activate the next index.
  // (the last index is always `count() - 1`).
  // Otherwise activate the first index.
  if (activeIndex < (webStateList->count() - 1)) {
    webStateList->ActivateWebStateAt(activeIndex + 1);
  } else {
    webStateList->ActivateWebStateAt(0);
  }
}

- (void)showPreviousTab {
  WebStateList* webStateList = self.browser->GetWebStateList();
  if (!webStateList)
    return;

  int activeIndex = webStateList->active_index();
  if (activeIndex == WebStateList::kInvalidIndex)
    return;

  // If the active index isn't the first index, activate the prior index.
  // Otherwise index the last index (`count() - 1`).
  if (activeIndex > 0) {
    webStateList->ActivateWebStateAt(activeIndex - 1);
  } else {
    webStateList->ActivateWebStateAt(webStateList->count() - 1);
  }
}

- (void)bookmarkThisPage {
  web::WebState* currentWebState =
      _browser->GetWebStateList()->GetActiveWebState();
  if (!currentWebState) {
    return;
  }

  BookmarkAddCommand* command =
      [[BookmarkAddCommand alloc] initWithWebState:currentWebState
                              presentFolderChooser:NO];
  [_bookmarksCommandsHandler bookmark:command];
}

- (void)reload {
  self.navigationAgent->Reload();
}

- (void)showHistory {
  [_dispatcher showHistory];
}

- (void)startVoiceSearch {
  [LayoutGuideCenterForBrowser(_browser) referenceView:nil
                                             underName:kVoiceSearchButtonGuide];
  [_dispatcher startVoiceSearch];
}

- (void)dismissModalDialogs {
  [_dispatcher dismissModalDialogs];
}

- (void)showSettings {
  [_dispatcher showSettingsFromViewController:_viewController];
}

- (void)stop {
  self.navigationAgent->StopLoading();
}

- (void)showHelpPage {
  [_browserCoordinatorCommandsHandler showHelpPage];
}

- (void)showDownloadsFolder {
  [_browserCoordinatorCommandsHandler showDownloadsFolder];
}

- (void)showTab0 {
  [self showTabAtIndex:0];
}

- (void)showTab1 {
  [self showTabAtIndex:1];
}

- (void)showTab2 {
  [self showTabAtIndex:2];
}

- (void)showTab3 {
  [self showTabAtIndex:3];
}

- (void)showTab4 {
  [self showTabAtIndex:4];
}

- (void)showTab5 {
  [self showTabAtIndex:5];
}

- (void)showTab6 {
  [self showTabAtIndex:6];
}

- (void)showTab7 {
  [self showTabAtIndex:7];
}

- (void)showLastTab {
  [self showTabAtIndex:self.tabsCount - 1];
}

#pragma mark - Private

- (WebNavigationBrowserAgent*)navigationAgent {
  return WebNavigationBrowserAgent::FromBrowser(self.browser);
}

- (BOOL)isFindInPageAvailable {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  if (!currentWebState) {
    return NO;
  }

  FindTabHelper* helper = FindTabHelper::FromWebState(currentWebState);
  return (helper && helper->CurrentPageSupportsFindInPage());
}

- (NSUInteger)tabsCount {
  return self.browser->GetWebStateList()->count();
}

- (BOOL)isEditingText {
  UIResponder* firstResponder = GetFirstResponder();
  return [firstResponder isKindOfClass:[UITextField class]] ||
         [firstResponder isKindOfClass:[UITextView class]] ||
         [[KeyboardObserverHelper sharedKeyboardObserver] isKeyboardVisible];
}

- (void)showTabAtIndex:(NSUInteger)index {
  WebStateList* webStateList = self.browser->GetWebStateList();
  if (webStateList->ContainsIndex(index)) {
    webStateList->ActivateWebStateAt(static_cast<int>(index));
  }
}

@end
