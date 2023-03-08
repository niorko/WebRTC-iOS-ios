// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/password/password_checkup/password_checkup_view_controller.h"

#import "base/metrics/user_metrics.h"
#import "ios/chrome/browser/shared/ui/util/uikit_ui_util.h"
#import "ios/chrome/browser/ui/settings/password/password_checkup/password_checkup_commands.h"
#import "ios/chrome/browser/ui/settings/password/password_checkup/password_checkup_consumer.h"
#import "ios/chrome/browser/ui/settings/password/password_checkup/password_checkup_utils.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using password_manager::InsecurePasswordCounts;

namespace {

// Height of the image used as a header for the table view.
CGFloat const kHeaderImageHeight = 99;

// Helper method to get the right trailing image for the Password Check cell
// depending on the check state.
UIImage* GetHeaderImage(PasswordCheckupHomepageState password_checkup_state,
                        InsecurePasswordCounts counts) {
  bool has_compromised_passwords = counts.compromised_count > 0;
  bool has_insecure_passwords =
      counts.compromised_count > 0 || counts.dismissed_count > 0 ||
      counts.reused_count > 0 || counts.weak_count > 0;
  switch (password_checkup_state) {
    case PasswordCheckupHomepageStateDone:
      if (has_compromised_passwords) {
        return [UIImage imageNamed:@"password_checkup_header_red"];
      } else if (has_insecure_passwords) {
        return [UIImage imageNamed:@"password_checkup_header_yellow"];
      }
      return [UIImage imageNamed:@"password_checkup_header_green"];
    case PasswordCheckupHomepageStateRunning:
      return [UIImage imageNamed:@"password_checkup_header_loading"];
    case PasswordCheckupHomepageStateError:
    case PasswordCheckupHomepageStateDisabled:
      return nil;
  }
}

}  // namespace

@interface PasswordCheckupViewController () {
  // Whether Settings have been dismissed.
  BOOL _settingsAreDismissed;

  // Current PasswordCheckupHomepageState.
  PasswordCheckupHomepageState _passwordCheckupState;

  // Password counts associated with the different insecure types.
  InsecurePasswordCounts _insecurePasswordCounts;

  // Image view at the top of the screen, indicating the overall Password
  // Checkup status.
  UIImageView* _headerImageView;
}

@end

@implementation PasswordCheckupViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = l10n_util::GetNSString(IDS_IOS_PASSWORD_CHECKUP);

  _headerImageView = [self createHeaderImageView];
  self.tableView.tableHeaderView = _headerImageView;
  [self updateHeaderImage];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  // Update the navigation bar background color as it is different for the
  // PasswordCheckupViewController than for its parent.
  [self updateNavigationBarBackgroundColorForDismissal:NO];
}

- (void)willMoveToParentViewController:(UIViewController*)parent {
  [super willMoveToParentViewController:parent];
  if (!parent) {
    // Reset the navigation bar background color to what it was before getting
    // to the PasswordCheckupViewController.
    [self updateNavigationBarBackgroundColorForDismissal:YES];
  }
}

- (void)didMoveToParentViewController:(UIViewController*)parent {
  [super didMoveToParentViewController:parent];
  if (!parent) {
    [self.handler dismissPasswordCheckupViewController];
  }
}

- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if (self.traitCollection.verticalSizeClass !=
      previousTraitCollection.verticalSizeClass) {
    [self updateNavigationBarBackgroundColorForDismissal:NO];
    [self updateTableViewHeaderView];
  }
}

#pragma mark - SettingsControllerProtocol

- (void)reportDismissalUserAction {
  base::RecordAction(
      base::UserMetricsAction("MobilePasswordCheckupSettingsClose"));
}

- (void)reportBackUserAction {
  base::RecordAction(
      base::UserMetricsAction("MobilePasswordCheckupSettingsBack"));
}

- (void)settingsWillBeDismissed {
  DCHECK(!_settingsAreDismissed);

  _settingsAreDismissed = YES;
}

#pragma mark - PasswordCheckupConsumer

- (void)setPasswordCheckupHomepageState:(PasswordCheckupHomepageState)state
                 insecurePasswordCounts:
                     (InsecurePasswordCounts)insecurePasswordCounts {
  // If the state and the insecure password counts both haven't changed, there
  // is no need to update anything.
  if (_passwordCheckupState == state &&
      _insecurePasswordCounts == insecurePasswordCounts) {
    return;
  }

  // If state is PasswordCheckupHomepageStateDisabled, it means that there is no
  // saved password to check, so we return to the Password Manager.
  if (state == PasswordCheckupHomepageStateDisabled) {
    [self.handler dismissPasswordCheckupViewController];
  }

  _passwordCheckupState = state;
  _insecurePasswordCounts = insecurePasswordCounts;
  [self updateHeaderImage];
}

- (void)setAffiliatedGroupCount:(NSInteger)affiliatedGroupCount {
  // TODO(crbug.com/1406540): Add method's body.
}

#pragma mark - Private

// Creates the header image view.
- (UIImageView*)createHeaderImageView {
  UIImageView* headerImageView = [[UIImageView alloc] init];
  headerImageView.contentMode = UIViewContentModeScaleAspectFill;
  headerImageView.frame = CGRectMake(0, 0, 0, kHeaderImageHeight);
  return headerImageView;
}

// Updates the background color of the navigation bar. When iPhones are in
// landscape mode, we want to hide the header image, and so we want to update
// the background color of the navigation bar accordingly. We also want to set
// the background color back to `nil` when returning to the previous view
// controller to cleanup the color change made in this view controller.
- (void)updateNavigationBarBackgroundColorForDismissal:
    (BOOL)viewControllerWillBeDismissed {
  if (viewControllerWillBeDismissed || IsCompactHeight(self)) {
    self.navigationController.navigationBar.backgroundColor = nil;
    return;
  }
  self.navigationController.navigationBar.backgroundColor =
      [UIColor colorNamed:@"password_checkup_header_background_color"];
}

// Updates the table view's header view depending on whether the header image
// view should be shown or not. When we're in iPhone landscape mode, we want to
// hide the image header view.
- (void)updateTableViewHeaderView {
  if (IsCompactHeight(self)) {
    self.tableView.tableHeaderView = nil;
  } else {
    self.tableView.tableHeaderView = _headerImageView;
  }
}

// Updates the header image according to the current
// PasswordCheckupHomepageState.
- (void)updateHeaderImage {
  switch (_passwordCheckupState) {
    case PasswordCheckupHomepageStateDone:
    case PasswordCheckupHomepageStateRunning: {
      UIImage* headerImage =
          GetHeaderImage(_passwordCheckupState, _insecurePasswordCounts);
      [_headerImageView setImage:headerImage];
      break;
    }
    case PasswordCheckupHomepageStateError:
    case PasswordCheckupHomepageStateDisabled:
      break;
  }
  [self.tableView layoutIfNeeded];
}

@end
