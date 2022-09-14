// Copyright 2016 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PASSWORDS_IOS_CHROME_PASSWORD_MANAGER_INFOBAR_DELEGATE_H_
#define IOS_CHROME_BROWSER_PASSWORDS_IOS_CHROME_PASSWORD_MANAGER_INFOBAR_DELEGATE_H_

#include <memory>

#include "components/infobars/core/confirm_infobar_delegate.h"
#include "components/password_manager/core/browser/password_manager_metrics_util.h"
#include "ios/chrome/browser/signin/authentication_service.h"

@protocol ApplicationCommands;

namespace password_manager {
class PasswordFormManagerForUI;
}

// Base class for password manager infobar delegates, e.g.
// IOSChromeSavePasswordInfoBarDelegate.
class IOSChromePasswordManagerInfoBarDelegate : public ConfirmInfoBarDelegate {
 public:
  IOSChromePasswordManagerInfoBarDelegate(
      const IOSChromePasswordManagerInfoBarDelegate&) = delete;
  IOSChromePasswordManagerInfoBarDelegate& operator=(
      const IOSChromePasswordManagerInfoBarDelegate&) = delete;

  ~IOSChromePasswordManagerInfoBarDelegate() override;

  // Getter for the message displayed in addition to the title. If no message
  // was set, this returns an empty string.
  NSString* GetDetailsMessageText() const;

  // The Username being saved or updated by the Infobar.
  NSString* GetUserNameText() const;

  // The Password being saved or updated by the Infobar.
  NSString* GetPasswordText() const;

  // The URL host for which the credentials are being saved for.
  NSString* GetURLHostText() const;

  // Sets the dispatcher for this delegate.
  void set_handler(id<ApplicationCommands> handler);

 protected:
  IOSChromePasswordManagerInfoBarDelegate(
      NSString* user_email,
      bool is_sync_user,
      std::unique_ptr<password_manager::PasswordFormManagerForUI> form_manager);

  password_manager::PasswordFormManagerForUI* form_to_save() const {
    return form_to_save_.get();
  }

  bool is_sync_user() const { return is_sync_user_; }

  NSString* user_email() { return user_email_; }

  void set_infobar_response(
      password_manager::metrics_util::UIDismissalReason response) {
    infobar_response_ = response;
  }

  password_manager::metrics_util::UIDismissalReason infobar_response() const {
    return infobar_response_;
  }

 private:
  // The password_manager::PasswordFormManager managing the form we're asking
  // the user about, and should save as per their decision.
  std::unique_ptr<password_manager::PasswordFormManagerForUI> form_to_save_;

  // ConfirmInfoBarDelegate implementation.
  int GetIconId() const override;

  // Used to track the results we get from the info bar.
  password_manager::metrics_util::UIDismissalReason infobar_response_;

  // Whether to show the additional footer.
  const bool is_sync_user_;

  NSString* user_email_;

  // Handler for calling Application commands.
  __weak id<ApplicationCommands> handler_ = nil;
};
#endif  // IOS_CHROME_BROWSER_PASSWORDS_IOS_CHROME_PASSWORD_MANAGER_INFOBAR_DELEGATE_H_
