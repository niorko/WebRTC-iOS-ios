// Copyright 2018 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bookmarks/home/bookmarks_home_mediator.h"

#import "base/check.h"
#import "base/mac/foundation_util.h"
#import "base/strings/sys_string_conversions.h"
#import "components/bookmarks/browser/bookmark_model.h"
#import "components/bookmarks/browser/bookmark_utils.h"
#import "components/bookmarks/browser/titled_url_match.h"
#import "components/bookmarks/common/bookmark_features.h"
#import "components/bookmarks/common/bookmark_pref_names.h"
#import "components/bookmarks/managed/managed_bookmark_service.h"
#import "components/prefs/ios/pref_observer_bridge.h"
#import "components/prefs/pref_change_registrar.h"
#import "components/prefs/pref_service.h"
#import "components/sync/driver/sync_service.h"
#import "ios/chrome/browser/bookmarks/bookmark_model_bridge_observer.h"
#import "ios/chrome/browser/bookmarks/managed_bookmark_service_factory.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/shared/public/features/features.h"
#import "ios/chrome/browser/shared/ui/table_view/cells/table_view_text_header_footer_item.h"
#import "ios/chrome/browser/shared/ui/table_view/cells/table_view_text_item.h"
#import "ios/chrome/browser/shared/ui/table_view/table_view_model.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/sync/sync_observer_bridge.h"
#import "ios/chrome/browser/sync/sync_service_factory.h"
#import "ios/chrome/browser/sync/sync_setup_service.h"
#import "ios/chrome/browser/sync/sync_setup_service_factory.h"
#import "ios/chrome/browser/ui/authentication/cells/table_view_signin_promo_item.h"
#import "ios/chrome/browser/ui/authentication/enterprise/enterprise_utils.h"
#import "ios/chrome/browser/ui/authentication/signin_presenter.h"
#import "ios/chrome/browser/ui/authentication/signin_promo_view_mediator.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_utils_ios.h"
#import "ios/chrome/browser/ui/bookmarks/cells/bookmark_home_node_item.h"
#import "ios/chrome/browser/ui/bookmarks/home/bookmark_promo_controller.h"
#import "ios/chrome/browser/ui/bookmarks/home/bookmarks_home_consumer.h"
#import "ios/chrome/browser/ui/bookmarks/home/bookmarks_home_shared_state.h"
#import "ios/chrome/browser/ui/bookmarks/synced_bookmarks_bridge.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using bookmarks::BookmarkNode;

namespace {
// Maximum number of entries to fetch when searching.
const int kMaxBookmarksSearchResults = 50;
}  // namespace

@interface BookmarksHomeMediator () <BookmarkModelBridgeObserver,
                                     BookmarkPromoControllerDelegate,
                                     PrefObserverDelegate,
                                     SigninPresenter,
                                     SyncObserverModelBridge> {
  // Bridge to register for bookmark changes.
  std::unique_ptr<BookmarkModelBridge> _modelBridge;

  // Observer to keep track of the signin and syncing status.
  std::unique_ptr<sync_bookmarks::SyncedBookmarksObserverBridge>
      _syncedBookmarksObserver;

  // Pref observer to track changes to prefs.
  std::unique_ptr<PrefObserverBridge> _prefObserverBridge;
  // Registrar for pref changes notifications.
  std::unique_ptr<PrefChangeRegistrar> _prefChangeRegistrar;
  // The browser for this mediator.
  base::WeakPtr<Browser> _browser;
  // The sync setup service for this mediator.
  SyncSetupService* _syncSetupService;
  AuthenticationService* _authenticationService;
  // Base view controller to present sign-in UI.
  UIViewController* _baseViewController;
}

// Shared state between Bookmark home classes.
@property(nonatomic, strong) BookmarksHomeSharedState* sharedState;

// The controller managing the display of the promo cell and the promo view
// controller.
@property(nonatomic, strong) BookmarkPromoController* bookmarkPromoController;

// Sync service.
@property(nonatomic, assign) syncer::SyncService* syncService;

@end

@implementation BookmarksHomeMediator

- (instancetype)initWithSharedState:(BookmarksHomeSharedState*)sharedState
                            browser:(Browser*)browser
                 baseViewController:(UIViewController*)baseViewController {
  if ((self = [super init])) {
    DCHECK(browser);
    _sharedState = sharedState;
    _browser = browser->AsWeakPtr();
    _baseViewController = baseViewController;
  }
  return self;
}

- (void)startMediating {
  DCHECK(self.consumer);
  DCHECK(self.sharedState);

  // Set up observers.
  ChromeBrowserState* browserState = [self originalBrowserState];
  _modelBridge = std::make_unique<BookmarkModelBridge>(
      self, self.sharedState.profileBookmarkModel);
  _syncedBookmarksObserver =
      std::make_unique<sync_bookmarks::SyncedBookmarksObserverBridge>(
          self, browserState);
  _bookmarkPromoController =
      [[BookmarkPromoController alloc] initWithBrowser:_browser.get()
                                              delegate:self
                                             presenter:self
                                    baseViewController:_baseViewController];

  _prefChangeRegistrar = std::make_unique<PrefChangeRegistrar>();
  _prefChangeRegistrar->Init(browserState->GetPrefs());
  _prefObserverBridge.reset(new PrefObserverBridge(self));

  _prefObserverBridge->ObserveChangesForPreference(
      bookmarks::prefs::kEditBookmarksEnabled, _prefChangeRegistrar.get());

  _prefObserverBridge->ObserveChangesForPreference(
      bookmarks::prefs::kManagedBookmarks, _prefChangeRegistrar.get());

  _syncService = SyncServiceFactory::GetForBrowserState(browserState);
  _syncSetupService = SyncSetupServiceFactory::GetForBrowserState(browserState);
  _authenticationService =
      AuthenticationServiceFactory::GetForBrowserState(browserState);

  [self computePromoTableViewData];
  [self computeBookmarkTableViewData];
}

- (void)disconnect {
  [_bookmarkPromoController shutdown];
  _bookmarkPromoController.delegate = nil;
  _bookmarkPromoController = nil;
  _modelBridge = nullptr;
  _syncSetupService = nullptr;
  _syncService = nullptr;
  _authenticationService = nullptr;
  _syncedBookmarksObserver = nullptr;
  _browser = nullptr;
  self.consumer = nil;
  self.sharedState = nil;
  _prefChangeRegistrar.reset();
  _prefObserverBridge.reset();
}

#pragma mark - Initial Model Setup

// Computes the bookmarks table view based on the currently displayed node.
- (void)computeBookmarkTableViewData {
  [self resetSections];

  // Regenerate the list of all bookmarks.
  if (!self.sharedState.profileBookmarkModel->loaded() ||
      !self.sharedState.tableViewDisplayedRootNode) {
    [self updateTableViewBackground];
    return;
  }

  if (self.sharedState.tableViewDisplayedRootNode ==
      self.sharedState.profileBookmarkModel->root_node()) {
    [self generateTableViewDataForRootNode];
    [self updateTableViewBackground];
    return;
  }
  [self generateTableViewData];
  [self updateTableViewBackground];
}

// Generate the table view data when the currently displayed node is a child
// node.
- (void)generateTableViewData {
  if (!self.sharedState.tableViewDisplayedRootNode) {
    return;
  }
  bookmarks::BookmarkModel* currentModel =
      bookmark_utils_ios::GetBookmarkModelForNode(
          self.sharedState.tableViewDisplayedRootNode,
          self.sharedState.profileBookmarkModel,
          self.sharedState.accountBookmarkModel);
  BOOL shouldDisplayCloudSlashIcon =
      [self shouldDisplayCloudSlashIconWithBookmarkModel:currentModel];
  // Add all bookmarks and folders of the currently displayed node to the table.
  for (const auto& child :
       self.sharedState.tableViewDisplayedRootNode->children()) {
    BookmarksHomeNodeItem* nodeItem = [[BookmarksHomeNodeItem alloc]
        initWithType:BookmarksHomeItemTypeBookmark
        bookmarkNode:child.get()];
    nodeItem.shouldDisplayCloudSlashIcon = shouldDisplayCloudSlashIcon;
    [self.sharedState.tableViewModel
                        addItem:nodeItem
        toSectionWithIdentifier:BookmarksHomeSectionIdentifierBookmarks];
  }
}

// Generate the table view data when the current currently displayed node is the
// outermost root.
- (void)generateTableViewDataForRootNode {
  // If all the permanent nodes are empty, do not create items for any of them.
  if (![self hasBookmarksOrFolders]) {
    return;
  }
  [self
      generateTableViewDataForModel:self.sharedState.profileBookmarkModel
                          inSection:BookmarksHomeSectionIdentifierRootProfile];
  if (!bookmark_utils_ios::IsAccountBookmarkModelAvailable(
          _authenticationService)) {
    return;
  }
  [self updateHeaderForProfileRootNode];
  [self
      generateTableViewDataForModel:self.sharedState.accountBookmarkModel
                          inSection:BookmarksHomeSectionIdentifierRootAccount];
  [self updateHeaderForAccountRootNode];
}

- (void)generateTableViewDataForModel:(bookmarks::BookmarkModel*)model
                            inSection:(BookmarksHomeSectionIdentifier)
                                          sectionIdentifier {
  BOOL shouldDisplayCloudSlashIcon =
      [self shouldDisplayCloudSlashIconWithBookmarkModel:model];
  // Add "Mobile Bookmarks" to the table.
  const BookmarkNode* mobileNode = model->mobile_node();
  BookmarksHomeNodeItem* mobileItem =
      [[BookmarksHomeNodeItem alloc] initWithType:BookmarksHomeItemTypeBookmark
                                     bookmarkNode:mobileNode];
  mobileItem.shouldDisplayCloudSlashIcon = shouldDisplayCloudSlashIcon;
  [self.sharedState.tableViewModel addItem:mobileItem
                   toSectionWithIdentifier:sectionIdentifier];

  // Add "Bookmarks Bar" and "Other Bookmarks" only when they are not empty.
  const BookmarkNode* bookmarkBar = model->bookmark_bar_node();
  if (!bookmarkBar->children().empty()) {
    BookmarksHomeNodeItem* barItem = [[BookmarksHomeNodeItem alloc]
        initWithType:BookmarksHomeItemTypeBookmark
        bookmarkNode:bookmarkBar];
    barItem.shouldDisplayCloudSlashIcon = shouldDisplayCloudSlashIcon;
    [self.sharedState.tableViewModel addItem:barItem
                     toSectionWithIdentifier:sectionIdentifier];
  }

  const BookmarkNode* otherBookmarks = model->other_node();
  if (!otherBookmarks->children().empty()) {
    BookmarksHomeNodeItem* otherItem = [[BookmarksHomeNodeItem alloc]
        initWithType:BookmarksHomeItemTypeBookmark
        bookmarkNode:otherBookmarks];
    otherItem.shouldDisplayCloudSlashIcon = shouldDisplayCloudSlashIcon;
    [self.sharedState.tableViewModel addItem:otherItem
                     toSectionWithIdentifier:sectionIdentifier];
  }

  // Add "Managed Bookmarks" to the table if it exists.
  ChromeBrowserState* browserState = [self originalBrowserState];
  bookmarks::ManagedBookmarkService* managedBookmarkService =
      ManagedBookmarkServiceFactory::GetForBrowserState(browserState);
  const BookmarkNode* managedNode = managedBookmarkService->managed_node();
  if (managedNode && managedNode->IsVisible()) {
    BookmarksHomeNodeItem* managedItem = [[BookmarksHomeNodeItem alloc]
        initWithType:BookmarksHomeItemTypeBookmark
        bookmarkNode:managedNode];
    managedItem.shouldDisplayCloudSlashIcon = shouldDisplayCloudSlashIcon;
    [self.sharedState.tableViewModel addItem:managedItem
                     toSectionWithIdentifier:sectionIdentifier];
  }
}

- (void)computeBookmarkTableViewDataMatching:(NSString*)searchText
                  orShowMessageWhenNoResults:(NSString*)noResults {
  [self resetSections];

  std::vector<const BookmarkNode*> nodes;
  bookmarks::QueryFields query;
  query.word_phrase_query.reset(new std::u16string);
  *query.word_phrase_query = base::SysNSStringToUTF16(searchText);
  BOOL shouldDisplayCloudSlashIcon = [self
      shouldDisplayCloudSlashIconWithBookmarkModel:self.sharedState
                                                       .profileBookmarkModel];
  GetBookmarksMatchingProperties(self.sharedState.profileBookmarkModel, query,
                                 kMaxBookmarksSearchResults, &nodes);

  int count = 0;
  for (const BookmarkNode* node : nodes) {
    BookmarksHomeNodeItem* nodeItem = [[BookmarksHomeNodeItem alloc]
        initWithType:BookmarksHomeItemTypeBookmark
        bookmarkNode:node];
    nodeItem.shouldDisplayCloudSlashIcon = shouldDisplayCloudSlashIcon;
    [self.sharedState.tableViewModel
                        addItem:nodeItem
        toSectionWithIdentifier:BookmarksHomeSectionIdentifierBookmarks];
    count++;
  }

  if (count == 0) {
    TableViewTextItem* item =
        [[TableViewTextItem alloc] initWithType:BookmarksHomeItemTypeMessage];
    item.textAlignment = NSTextAlignmentLeft;
    item.textColor = [UIColor colorNamed:kTextPrimaryColor];
    item.text = noResults;
    [self.sharedState.tableViewModel
                        addItem:item
        toSectionWithIdentifier:BookmarksHomeSectionIdentifierMessages];
    return;
  }

  [self updateTableViewBackground];
}

- (void)updateTableViewBackground {
  // If the currently displayed node is the outermost root, check if we need to
  // show the spinner backgound. Otherwise, check if we need to show the empty
  // background.
  if (self.sharedState.tableViewDisplayedRootNode ==
      self.sharedState.profileBookmarkModel->root_node()) {
    if (self.sharedState.profileBookmarkModel
            ->HasNoUserCreatedBookmarksOrFolders() &&
        _syncedBookmarksObserver->IsPerformingInitialSync()) {
      [self.consumer
          updateTableViewBackgroundStyle:BookmarksHomeBackgroundStyleLoading];
    } else if (![self hasBookmarksOrFolders]) {
      [self.consumer
          updateTableViewBackgroundStyle:BookmarksHomeBackgroundStyleEmpty];
    } else {
      [self.consumer
          updateTableViewBackgroundStyle:BookmarksHomeBackgroundStyleDefault];
    }
    return;
  }

  if (![self hasBookmarksOrFolders] &&
      !self.sharedState.currentlyShowingSearchResults) {
    [self.consumer
        updateTableViewBackgroundStyle:BookmarksHomeBackgroundStyleEmpty];
  } else {
    [self.consumer
        updateTableViewBackgroundStyle:BookmarksHomeBackgroundStyleDefault];
  }
}

#pragma mark - Public

- (void)computePromoTableViewData {
  // We show promo cell only on the root view, that is when showing
  // the permanent nodes.
  BOOL promoVisible = ((self.sharedState.tableViewDisplayedRootNode ==
                        self.sharedState.profileBookmarkModel->root_node()) &&
                       self.bookmarkPromoController.shouldShowSigninPromo &&
                       !self.sharedState.currentlyShowingSearchResults) &&
                      !self.isSyncDisabledByAdministrator;

  if (promoVisible == self.sharedState.promoVisible) {
    return;
  }
  self.sharedState.promoVisible = promoVisible;

  SigninPromoViewMediator* signinPromoViewMediator =
      self.bookmarkPromoController.signinPromoViewMediator;
  if (self.sharedState.promoVisible) {
    DCHECK(![self.sharedState.tableViewModel
        hasSectionForSectionIdentifier:BookmarksHomeSectionIdentifierPromo]);
    [self.sharedState.tableViewModel
        insertSectionWithIdentifier:BookmarksHomeSectionIdentifierPromo
                            atIndex:0];

    TableViewSigninPromoItem* signinPromoItem =
        [[TableViewSigninPromoItem alloc]
            initWithType:BookmarksHomeItemTypePromo];
    signinPromoItem.configurator = [signinPromoViewMediator createConfigurator];
    signinPromoItem.text =
        l10n_util::GetNSString(IDS_IOS_SIGNIN_PROMO_BOOKMARKS_WITH_UNITY);
    signinPromoItem.delegate = signinPromoViewMediator;
    [signinPromoViewMediator signinPromoViewIsVisible];

    [self.sharedState.tableViewModel
                        addItem:signinPromoItem
        toSectionWithIdentifier:BookmarksHomeSectionIdentifierPromo];
  } else {
    if (!signinPromoViewMediator.invalidClosedOrNeverVisible) {
      // When the sign-in view is closed, the promo state changes, but
      // -[SigninPromoViewMediator signinPromoViewIsHidden] should not be
      // called.
      [signinPromoViewMediator signinPromoViewIsHidden];
    }

    DCHECK([self.sharedState.tableViewModel
        hasSectionForSectionIdentifier:BookmarksHomeSectionIdentifierPromo]);
    [self.sharedState.tableViewModel
        removeSectionWithIdentifier:BookmarksHomeSectionIdentifierPromo];
  }
  [self.sharedState.tableView reloadData];
  // Update the TabelView background to make sure the new state of the promo
  // does not affect the background.
  [self updateTableViewBackground];
}

#pragma mark - BookmarkModelBridgeObserver Callbacks

// BookmarkModelBridgeObserver Callbacks
// Instances of this class automatically observe the bookmark model.
// The bookmark model has loaded.
- (void)bookmarkModelLoaded:(bookmarks::BookmarkModel*)model {
  [self.consumer refreshContents];
}

// The node has changed, but not its children.
- (void)bookmarkModel:(bookmarks::BookmarkModel*)model
        didChangeNode:(const bookmarks::BookmarkNode*)bookmarkNode {
  // The root folder changed. Do nothing.
  if (bookmarkNode == self.sharedState.tableViewDisplayedRootNode) {
    return;
  }

  // A specific cell changed. Reload, if currently shown.
  if ([self itemForNode:bookmarkNode] != nil) {
    [self.consumer refreshContents];
  }
}

// The node has not changed, but its children have.
- (void)bookmarkModel:(bookmarks::BookmarkModel*)model
    didChangeChildrenForNode:(const bookmarks::BookmarkNode*)bookmarkNode {
  // In search mode, we want to refresh any changes (like undo).
  if (self.sharedState.currentlyShowingSearchResults) {
    [self.consumer refreshContents];
  }
  // The currently displayed folder's children changed. Reload everything.
  // (When adding new folder, table is already been updated. So no need to
  // reload here.)
  if (bookmarkNode == self.sharedState.tableViewDisplayedRootNode &&
      !self.addingNewFolder) {
    if (self.sharedState.currentlyInEditMode && ![self hasBookmarksOrFolders]) {
      [self.consumer setTableViewEditing:NO];
    }
    [self.consumer refreshContents];
    return;
  }
}

// The node has moved to a new parent folder.
- (void)bookmarkModel:(bookmarks::BookmarkModel*)model
          didMoveNode:(const bookmarks::BookmarkNode*)bookmarkNode
           fromParent:(const bookmarks::BookmarkNode*)oldParent
             toParent:(const bookmarks::BookmarkNode*)newParent {
  if (oldParent == self.sharedState.tableViewDisplayedRootNode ||
      newParent == self.sharedState.tableViewDisplayedRootNode) {
    // A folder was added or removed from the currently displayed folder.
    [self.consumer refreshContents];
  }
}

// `node` was deleted from `folder`.
- (void)bookmarkModel:(bookmarks::BookmarkModel*)model
        didDeleteNode:(const bookmarks::BookmarkNode*)node
           fromFolder:(const bookmarks::BookmarkNode*)folder {
  if (self.sharedState.currentlyShowingSearchResults) {
    [self.consumer refreshContents];
  } else if (self.sharedState.tableViewDisplayedRootNode == node) {
    self.sharedState.tableViewDisplayedRootNode = NULL;
    [self.consumer refreshContents];
  }
}

// All non-permanent nodes have been removed.
- (void)bookmarkModelRemovedAllNodes:(bookmarks::BookmarkModel*)model {
  // TODO(crbug.com/695749) Check if this case is applicable in the new UI.
}

- (void)bookmarkModel:(bookmarks::BookmarkModel*)model
    didChangeFaviconForNode:(const bookmarks::BookmarkNode*)bookmarkNode {
  // Only urls have favicons.
  DCHECK(bookmarkNode->is_url());

  // Update image of corresponding cell.
  BookmarksHomeNodeItem* nodeItem = [self itemForNode:bookmarkNode];
  if (!nodeItem) {
    return;
  }

  // Check that this cell is visible.
  NSIndexPath* indexPath =
      [self.sharedState.tableViewModel indexPathForItem:nodeItem];
  NSArray* visiblePaths = [self.sharedState.tableView indexPathsForVisibleRows];
  if (![visiblePaths containsObject:indexPath]) {
    return;
  }

  // Get the favicon from cache directly. (no need to fetch from server)
  [self.consumer loadFaviconAtIndexPath:indexPath fallbackToGoogleServer:NO];
}

- (BookmarksHomeNodeItem*)itemForNode:
    (const bookmarks::BookmarkNode*)bookmarkNode {
  NSArray<TableViewItem*>* items = [self.sharedState.tableViewModel
      itemsInSectionWithIdentifier:BookmarksHomeSectionIdentifierBookmarks];
  for (TableViewItem* item in items) {
    if (item.type == BookmarksHomeItemTypeBookmark) {
      BookmarksHomeNodeItem* nodeItem =
          base::mac::ObjCCastStrict<BookmarksHomeNodeItem>(item);
      if (nodeItem.bookmarkNode == bookmarkNode) {
        return nodeItem;
      }
    }
  }
  return nil;
}

#pragma mark - BookmarkPromoControllerDelegate

- (void)promoStateChanged:(BOOL)promoEnabled {
  [self computePromoTableViewData];
}

- (void)configureSigninPromoWithConfigurator:
            (SigninPromoViewConfigurator*)configurator
                             identityChanged:(BOOL)identityChanged {
  if (![self.sharedState.tableViewModel
          hasSectionForSectionIdentifier:BookmarksHomeSectionIdentifierPromo]) {
    return;
  }

  NSIndexPath* indexPath = [self.sharedState.tableViewModel
      indexPathForItemType:BookmarksHomeItemTypePromo
         sectionIdentifier:BookmarksHomeSectionIdentifierPromo];
  [self.consumer configureSigninPromoWithConfigurator:configurator
                                          atIndexPath:indexPath];
}

- (BOOL)isPerformingInitialSync {
  return _syncedBookmarksObserver->IsPerformingInitialSync();
}

#pragma mark - SigninPresenter

- (void)showSignin:(ShowSigninCommand*)command {
  // Proxy this call along to the consumer.
  [self.consumer showSignin:command];
}

#pragma mark - SyncObserverModelBridge

- (void)onSyncStateChanged {
  // If user starts or stops syncing bookmarks, we may have to remove or add the
  // slashed cloud icon. Also, permanent nodes ("Bookmarks Bar", "Other
  // Bookmarks") at the root node might be added after syncing.  So we need to
  // refresh here.
  [self.consumer refreshContents];
  if (self.sharedState.tableViewDisplayedRootNode !=
          self.sharedState.profileBookmarkModel->root_node() &&
      !self.isSyncDisabledByAdministrator) {
    [self updateTableViewBackground];
  }
}

#pragma mark - PrefObserverDelegate

- (void)onPreferenceChanged:(const std::string&)preferenceName {
  // Editing capability may need to be updated on the bookmarks UI.
  // Or managed bookmarks contents may need to be updated.
  if (preferenceName == bookmarks::prefs::kEditBookmarksEnabled ||
      preferenceName == bookmarks::prefs::kManagedBookmarks) {
    [self.consumer refreshContents];
  }
}

#pragma mark - Private Helpers

- (void)updateHeaderForProfileRootNode {
  TableViewTextHeaderFooterItem* profileHeader =
      [[TableViewTextHeaderFooterItem alloc]
          initWithType:BookmarksHomeItemTypeHeader];
  profileHeader.text =
      l10n_util::GetNSString(IDS_IOS_BOOKMARK_ONLY_ON_THIS_DEVICE);
  [self.sharedState.tableViewModel
                     setHeader:profileHeader
      forSectionWithIdentifier:BookmarksHomeSectionIdentifierRootProfile];
}

- (void)updateHeaderForAccountRootNode {
  TableViewTextHeaderFooterItem* accountHeader =
      [[TableViewTextHeaderFooterItem alloc]
          initWithType:BookmarksHomeItemTypeHeader];
  accountHeader.text =
      l10n_util::GetNSString(IDS_IOS_BOOKMARK_IN_YOUR_GOOGLE_ACCOUNT);
  [self.sharedState.tableViewModel
                     setHeader:accountHeader
      forSectionWithIdentifier:BookmarksHomeSectionIdentifierRootAccount];
}

// The original chrome browser state used for services that don't exist in
// incognito mode. E.g., `_syncSetupService`, `_syncService` and
// `ManagedBookmarkService`.
- (ChromeBrowserState*)originalBrowserState {
  return _browser->GetBrowserState()->GetOriginalChromeBrowserState();
}

- (BOOL)hasBookmarksOrFolders {
  if (self.sharedState.tableViewDisplayedRootNode ==
      self.sharedState.profileBookmarkModel->root_node()) {
    // The root node always has its permanent nodes. If all the permanent nodes
    // are empty, we treat it as if the root itself is empty.
    const auto& childrenOfRootNode =
        self.sharedState.tableViewDisplayedRootNode->children();
    for (const auto& child : childrenOfRootNode) {
      if (!child->children().empty()) {
        return YES;
      }
    }
    return NO;
  }
  return self.sharedState.tableViewDisplayedRootNode &&
         !self.sharedState.tableViewDisplayedRootNode->children().empty();
}

// Ensure all sections exists and are empty.
- (void)resetSections {
  NSArray<NSNumber*>* sectionsToDelete = @[
    @(BookmarksHomeSectionIdentifierBookmarks),
    @(BookmarksHomeSectionIdentifierRootProfile),
    @(BookmarksHomeSectionIdentifierRootAccount),
    @(BookmarksHomeSectionIdentifierMessages)
  ];

  for (NSNumber* section in sectionsToDelete) {
    [self deleteAllItemsOrAddSectionWithIdentifier:section.intValue];
  }
}

// Delete all items for the given `sectionIdentifier` section, or create it
// if it doesn't exist, hence ensuring the section exists and is empty.
- (void)deleteAllItemsOrAddSectionWithIdentifier:(NSInteger)sectionIdentifier {
  TableViewModel* model = self.sharedState.tableViewModel;
  if ([model hasSectionForSectionIdentifier:sectionIdentifier]) {
    [model deleteAllItemsFromSectionWithIdentifier:sectionIdentifier];
  } else {
    [model addSectionWithIdentifier:sectionIdentifier];
  }
  [model setHeader:nil forSectionWithIdentifier:sectionIdentifier];
}

// Returns YES if the user cannot turn on sync for enterprise policy reasons.
- (BOOL)isSyncDisabledByAdministrator {
  DCHECK(self.syncService);
  ChromeBrowserState* browserState = [self originalBrowserState];
  bool syncDisabledPolicy = self.syncService->GetDisableReasons().Has(
      syncer::SyncService::DISABLE_REASON_ENTERPRISE_POLICY);
  PrefService* prefService = browserState->GetPrefs();
  bool syncTypesDisabledPolicy =
      IsManagedSyncDataType(prefService, SyncSetupService::kSyncBookmarks);
  return syncDisabledPolicy || syncTypesDisabledPolicy;
}

// Returns weather the slashed cloud icon should be displayed for
// `bookmarkModel`.
- (BOOL)shouldDisplayCloudSlashIconWithBookmarkModel:
    (bookmarks::BookmarkModel*)bookmarkModel {
  if (bookmarkModel == self.sharedState.profileBookmarkModel) {
    return bookmark_utils_ios::ShouldDisplayCloudSlashIconForProfileModel(
        _syncSetupService);
  }
  CHECK_EQ(bookmarkModel, self.sharedState.accountBookmarkModel)
      << "bookmarkModel: " << bookmarkModel
      << ", profileBookmarkModel: " << self.sharedState.profileBookmarkModel
      << ", accountBookmarkModel: " << self.sharedState.accountBookmarkModel;
  return NO;
}

@end
