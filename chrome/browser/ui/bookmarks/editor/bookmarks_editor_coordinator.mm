// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bookmarks/editor/bookmarks_editor_coordinator.h"

#import "base/metrics/user_metrics.h"
#import "base/metrics/user_metrics_action.h"
#import "ios/chrome/browser/bookmarks/account_bookmark_model_factory.h"
#import "ios/chrome/browser/bookmarks/local_or_syncable_bookmark_model_factory.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/shared/coordinator/alert/action_sheet_coordinator.h"
#import "ios/chrome/browser/shared/ui/table_view/table_view_navigation_controller.h"
#import "ios/chrome/browser/sync/sync_service_factory.h"
#import "ios/chrome/browser/sync/sync_setup_service_factory.h"
#import "ios/chrome/browser/ui/bookmarks/editor/bookmarks_editor_coordinator_delegate.h"
#import "ios/chrome/browser/ui/bookmarks/editor/bookmarks_editor_mediator.h"
#import "ios/chrome/browser/ui/bookmarks/editor/bookmarks_editor_mediator_delegate.h"
#import "ios/chrome/browser/ui/bookmarks/editor/bookmarks_editor_view_controller.h"
#import "ios/chrome/browser/ui/bookmarks/folder_chooser/bookmarks_folder_chooser_coordinator.h"
#import "ios/chrome/browser/ui/bookmarks/folder_editor/bookmarks_folder_editor_coordinator.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util_mac.h"
#import "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface BookmarksEditorCoordinator () <
    BookmarksEditorViewControllerDelegate,
    BookmarksEditorMediatorDelegate,
    BookmarksFolderChooserCoordinatorDelegate> {
  // BookmarkNode to edit.
  const bookmarks::BookmarkNode* _node;

  // The editor view controller owned and presented by this coordinator.
  // It is wrapped in a TableViewNavigationController.
  BookmarksEditorViewController* _viewController;

  // The editor mediator owned and presented by this coordinator.
  // It is wrapped in a TableViewNavigationController.
  BookmarksEditorMediator* _mediator;

  // Receives commands to show a snackbar once a bookmark is edited or deleted.
  id<SnackbarCommands> _snackbarCommandsHandler;

  // The navigation controller that is being presented. The bookmark editor view
  // controller is the child of this navigation controller.
  UINavigationController* _navigationController;

  // The folder chooser coordinator.
  BookmarksFolderChooserCoordinator* _folderChooserCoordinator;
}

// The action sheet coordinator, if one is currently being shown.
@property(nonatomic, strong) ActionSheetCoordinator* actionSheetCoordinator;

@end

@implementation BookmarksEditorCoordinator

- (instancetype)initWithBaseViewController:(UIViewController*)viewController
                                   browser:(Browser*)browser
                                      node:(const bookmarks::BookmarkNode*)node
                   snackbarCommandsHandler:
                       (id<SnackbarCommands>)snackbarCommandsHandler {
  self = [super initWithBaseViewController:viewController browser:browser];
  if (self) {
    _node = node;
    _snackbarCommandsHandler = snackbarCommandsHandler;
  }
  return self;
}

- (void)start {
  [super start];
  _viewController =
      [[BookmarksEditorViewController alloc] initWithBrowser:self.browser];
  _viewController.delegate = self;
  _viewController.snackbarCommandsHandler = _snackbarCommandsHandler;
  ChromeBrowserState* browserState =
      self.browser->GetBrowserState()->GetOriginalChromeBrowserState();
  bookmarks::BookmarkModel* profileBookmarkModel =
      ios::LocalOrSyncableBookmarkModelFactory::GetForBrowserState(
          browserState);
  bookmarks::BookmarkModel* accountBookmarkModel =
      ios::AccountBookmarkModelFactory::GetForBrowserState(browserState);
  _mediator = [[BookmarksEditorMediator alloc]
      initWithProfileBookmarkModel:profileBookmarkModel
              accountBookmarkModel:accountBookmarkModel
                      bookmarkNode:_node
                             prefs:browserState->GetPrefs()
                  syncSetupService:SyncSetupServiceFactory::GetForBrowserState(
                                       browserState)
                       syncService:SyncServiceFactory::GetForBrowserState(
                                       browserState)];
  _mediator.consumer = _viewController;
  _mediator.delegate = self;
  _viewController.mutator = _mediator;

  _navigationController =
      [[TableViewNavigationController alloc] initWithTable:_viewController];
  _navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
  _navigationController.toolbarHidden = YES;
  _navigationController.presentationController.delegate = self;

  [self.baseViewController presentViewController:_navigationController
                                        animated:YES
                                      completion:nil];
}

- (void)stop {
  [super stop];
  DCHECK(_navigationController);
  [_mediator disconnect];
  _mediator.consumer = nil;
  _mediator = nil;
  _viewController.delegate = nil;
  _viewController.snackbarCommandsHandler = nil;
  _viewController.mutator = nil;
  _viewController = nil;
  _snackbarCommandsHandler = nil;
  [_folderChooserCoordinator stop];
  _folderChooserCoordinator.delegate = nil;
  _folderChooserCoordinator = nil;

  // animatedDismissal should have been explicitly set before calling stop.
  [_navigationController dismissViewControllerAnimated:self.animatedDismissal
                                            completion:nil];
  _navigationController = nil;
}

- (BOOL)canDismiss {
  if (_viewController.edited) {
    return NO;
  }
  if (_folderChooserCoordinator && ![_folderChooserCoordinator canDismiss]) {
    return NO;
  }
  return YES;
}

#pragma mark - BookmarksEditorViewControllerDelegate

- (void)moveBookmark {
  DCHECK([_mediator bookmarkModel]);
  DCHECK(!_folderChooserCoordinator);

  std::set<const bookmarks::BookmarkNode*> hiddenNodes{[_mediator bookmark]};
  _folderChooserCoordinator = [[BookmarksFolderChooserCoordinator alloc]
      initWithBaseNavigationController:_navigationController
                               browser:self.browser
                           hiddenNodes:hiddenNodes];
  [_folderChooserCoordinator setSelectedFolder:_mediator.folder];
  _folderChooserCoordinator.delegate = self;
  [_folderChooserCoordinator start];
}

- (void)bookmarkEditorWantsDismissal:
    (BookmarksEditorViewController*)controller {
  [self.delegate bookmarksEditorCoordinatorShouldStop:self];
}

- (void)bookmarkEditorWillCommitTitleOrURLChange:
    (BookmarksEditorViewController*)controller {
  [self.delegate bookmarkEditorWillCommitTitleOrURLChange:self];
}
#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerDidAttemptToDismiss:
    (UIPresentationController*)presentationController {
  self.actionSheetCoordinator = [[ActionSheetCoordinator alloc]
      initWithBaseViewController:_viewController
                         browser:self.browser
                           title:nil
                         message:nil
                   barButtonItem:_viewController.cancelItem];

  __weak __typeof(self) weakSelf = self;
  [self.actionSheetCoordinator
      addItemWithTitle:l10n_util::GetNSString(
                           IDS_IOS_VIEW_CONTROLLER_DISMISS_SAVE_CHANGES)
                action:^{
                  BookmarksEditorCoordinator* strongSelf = weakSelf;
                  if (strongSelf != nil) {
                    [strongSelf->_viewController save];
                  }
                }
                 style:UIAlertActionStyleDefault];
  [self.actionSheetCoordinator
      addItemWithTitle:l10n_util::GetNSString(
                           IDS_IOS_VIEW_CONTROLLER_DISMISS_DISCARD_CHANGES)
                action:^{
                  BookmarksEditorCoordinator* strongSelf = weakSelf;
                  if (strongSelf != nil) {
                    [strongSelf->_viewController cancel];
                  }
                }
                 style:UIAlertActionStyleDestructive];
  [self.actionSheetCoordinator
      addItemWithTitle:l10n_util::GetNSString(
                           IDS_IOS_VIEW_CONTROLLER_DISMISS_CANCEL_CHANGES)
                action:^{
                  BookmarksEditorCoordinator* strongSelf = weakSelf;
                  if (strongSelf != nil) {
                    [strongSelf->_viewController setNavigationItemsEnabled:YES];
                  }
                }
                 style:UIAlertActionStyleCancel];

  [_viewController setNavigationItemsEnabled:NO];
  [self.actionSheetCoordinator start];
}

- (void)presentationControllerWillDismiss:
    (UIPresentationController*)presentationController {
  // Resign first responder if trying to dismiss the VC so the keyboard doesn't
  // linger until the VC dismissal has completed.
  [_viewController.view endEditing:YES];
}

- (void)presentationControllerDidDismiss:
    (UIPresentationController*)presentationController {
  base::RecordAction(
      base::UserMetricsAction("IOSBookmarksEditorClosedWithSwipeDown"));
  [_viewController dismissBookmarkEditorView];
}

- (BOOL)presentationControllerShouldDismiss:
    (UIPresentationController*)presentationController {
  return [self canDismiss];
}

#pragma mark - BookmarksEditorMediatorDelegate

- (void)bookmarkEditorMediatorWantsDismissal:
    (BookmarksEditorMediator*)mediator {
  [self.delegate bookmarksEditorCoordinatorShouldStop:self];
}

- (void)bookmarkDidMoveToParent:(const bookmarks::BookmarkNode*)newParent {
  [_folderChooserCoordinator setSelectedFolder:newParent];
}

#pragma mark - BookmarksFolderChooserCoordinatorDelegate

- (void)bookmarksFolderChooserCoordinatorDidConfirm:
            (BookmarksFolderChooserCoordinator*)coordinator
                                 withSelectedFolder:
                                     (const bookmarks::BookmarkNode*)folder {
  DCHECK(_folderChooserCoordinator);
  DCHECK(folder);
  [_folderChooserCoordinator stop];
  _folderChooserCoordinator.delegate = nil;
  _folderChooserCoordinator = nil;

  [_mediator changeFolder:folder];
}

- (void)bookmarksFolderChooserCoordinatorDidCancel:
    (BookmarksFolderChooserCoordinator*)coordinator {
  DCHECK(_folderChooserCoordinator);
  [_folderChooserCoordinator stop];
  _folderChooserCoordinator.delegate = nil;
  _folderChooserCoordinator = nil;
  if (!_navigationController.presentingViewController) {
    // In this case the `_navigationController` itself was dismissed.
    // TODO(crbug.com/1402758): Remove this if block when dismiss handling
    // is done in coordinators.
    [_viewController.view endEditing:YES];
    [self.delegate bookmarksEditorCoordinatorShouldStop:self];
  }
}

@end
