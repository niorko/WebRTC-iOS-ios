// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bookmarks/folder_editor/bookmarks_folder_editor_coordinator.h"

#import "base/check.h"
#import "base/check_op.h"
#import "base/mac/foundation_util.h"
#import "components/bookmarks/browser/bookmark_model.h"
#import "ios/chrome/browser/bookmarks/bookmark_model_factory.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_navigation_controller.h"
#import "ios/chrome/browser/ui/bookmarks/folder_editor/bookmarks_folder_editor_coordinator_delegate.h"
#import "ios/chrome/browser/ui/bookmarks/folder_editor/bookmarks_folder_editor_view_controller.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/snackbar_commands.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface BookmarksFolderEditorCoordinator () <
    BookmarksFolderEditorViewControllerDelegate,
    UIAdaptivePresentationControllerDelegate> {
  // The navigation controller is `nullptr` if the folder chooser view
  // controller is pushed into the base navigation controller.
  // Otherwise, the navigation controller is presented in the base view
  // controller.
  UINavigationController* _navigationController;
  BookmarksFolderEditorViewController* _viewController;
  // `_parentFolderNode` is only used when a new folder is added. The new
  // folder should be added in `_parentFolderNode`. If `_parentFolderNode` is
  // `nullptr`, then the new folder needs to be added in the default folder.
  const bookmarks::BookmarkNode* _parentFolderNode;
  // If `_folderNode` is set, the user is editing an existing folder and
  // `_parentFolderNode` should be `nullptr`. If `_folderNode` is not set, the
  // user is adding a new folder.
  const bookmarks::BookmarkNode* _folderNode;
}

@end

@implementation BookmarksFolderEditorCoordinator

@synthesize baseNavigationController = _baseNavigationController;

- (instancetype)initWithBaseNavigationController:
                    (UINavigationController*)navigationController
                                         browser:(Browser*)browser
                                parentFolderNode:
                                    (const bookmarks::BookmarkNode*)
                                        parentFolder {
  self = [super initWithBaseViewController:navigationController
                                   browser:browser];
  if (self) {
    _baseNavigationController = navigationController;
    _parentFolderNode = parentFolder;
  }
  return self;
}

- (instancetype)initWithBaseViewController:(UIViewController*)baseViewController
                                   browser:(Browser*)browser
                                folderNode:
                                    (const bookmarks::BookmarkNode*)folder {
  self = [super initWithBaseViewController:baseViewController browser:browser];
  if (self) {
    _folderNode = folder;
  }
  return self;
}

- (void)start {
  [super start];
  // TODO(crbug.com/1402758): Create a mediator.
  bookmarks::BookmarkModel* model =
      ios::BookmarkModelFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  if (_baseNavigationController) {
    DCHECK(!_folderNode);
    _viewController = [BookmarksFolderEditorViewController
        folderCreatorWithBookmarkModel:model
                          parentFolder:_parentFolderNode
                               browser:self.browser];
    _viewController.delegate = self;
    _viewController.snackbarCommandsHandler = HandlerForProtocol(
        self.browser->GetCommandDispatcher(), SnackbarCommands);
    [_baseNavigationController pushViewController:_viewController animated:YES];
  } else {
    DCHECK(!_navigationController);
    DCHECK(_folderNode);
    DCHECK(!_parentFolderNode);
    _viewController = [BookmarksFolderEditorViewController
        folderEditorWithBookmarkModel:model
                               folder:_folderNode
                              browser:self.browser];
    _viewController.delegate = self;
    _viewController.snackbarCommandsHandler = HandlerForProtocol(
        self.browser->GetCommandDispatcher(), SnackbarCommands);
    _navigationController = [[BookmarkNavigationController alloc]
        initWithRootViewController:_viewController];
    _navigationController.presentationController.delegate = self;
    _navigationController.modalPresentationStyle = UIModalPresentationFormSheet;

    [self.baseViewController presentViewController:_navigationController
                                          animated:YES
                                        completion:nil];
  }
}

- (void)stop {
  [super stop];

  DCHECK(_viewController);
  if (_baseNavigationController) {
    DCHECK_EQ(self.baseNavigationController.topViewController, _viewController);
    [_baseNavigationController popViewControllerAnimated:YES];
  } else if (_navigationController) {
    [self.baseViewController dismissViewControllerAnimated:YES completion:nil];
    _navigationController = nil;
  } else {
    // If there is no `_baseNavigationController` and `_navigationController`,
    // the view controller has been already dismissed. See
    // `presentationControllerDidDismiss:`.
    // Therefore `self.baseViewController.presentedViewController` must be
    // `nullptr`. This should only happend when the user is editing an existing
    // folder node.
    DCHECK(!self.baseViewController.presentedViewController);
    DCHECK(_folderNode);
    DCHECK(!_parentFolderNode);
  }
  _viewController = nil;
}

- (BOOL)canDismiss {
  DCHECK(_viewController);
  return [_viewController canDismiss];
}

#pragma mark - BookmarksFolderEditorViewControllerDelegate

- (void)bookmarksFolderEditor:(BookmarksFolderEditorViewController*)folderEditor
       didFinishEditingFolder:(const bookmarks::BookmarkNode*)folder {
  [_delegate bookmarksFolderEditorCoordinator:self
                   didFinishEditingFolderNode:folder];
}

- (void)bookmarksFolderEditorDidDeleteEditedFolder:
    (BookmarksFolderEditorViewController*)folderEditor {
  // Deleting the folder is only allowed when the user is editing an existing
  // folder.
  DCHECK(_folderNode);
  DCHECK(!_parentFolderNode);
  [_delegate bookmarksFolderEditorCoordinatorShouldStop:self];
}

- (void)bookmarksFolderEditorDidCancel:
    (BookmarksFolderEditorViewController*)folderEditor {
  [_delegate bookmarksFolderEditorCoordinatorShouldStop:self];
}

- (void)bookmarksFolderEditorWillCommitTitleChange:
    (BookmarksFolderEditorViewController*)controller {
  [_delegate bookmarksFolderEditorWillCommitTitleChange:self];
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerDidAttemptToDismiss:
    (UIPresentationController*)presentationController {
  [_viewController presentationControllerDidAttemptToDismiss];
}

- (void)presentationControllerWillDismiss:
    (UIPresentationController*)presentationController {
  // Resign first responder if trying to dismiss the VC so the keyboard doesn't
  // linger until the VC dismissal has completed.
  [_viewController.view endEditing:YES];
}

- (void)presentationControllerDidDismiss:
    (UIPresentationController*)presentationController {
  DCHECK(_navigationController);
  _navigationController = nil;
  [_delegate bookmarksFolderEditorCoordinatorShouldStop:self];
}

- (BOOL)presentationControllerShouldDismiss:
    (UIPresentationController*)presentationController {
  return [self canDismiss];
}

@end
