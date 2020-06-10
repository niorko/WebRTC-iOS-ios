// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_INFOBAR_BANNER_SAVE_CARD_INFOBAR_BANNER_OVERLAY_REQUEST_CONFIG_H_
#define IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_INFOBAR_BANNER_SAVE_CARD_INFOBAR_BANNER_OVERLAY_REQUEST_CONFIG_H_

#include "base/strings/string16.h"
#include "ios/chrome/browser/overlays/public/overlay_request_config.h"
#include "ios/chrome/browser/overlays/public/overlay_user_data.h"

namespace infobars {
class InfoBar;
}

namespace save_card_infobar_overlays {

// Configuration object for OverlayRequests for the banner UI for an InfoBar
// with a AutofillSaveCardInfoBarDelegateMobile.
class SaveCardBannerRequestConfig
    : public OverlayRequestConfig<SaveCardBannerRequestConfig> {
 public:
  ~SaveCardBannerRequestConfig() override;

  // The message text.
  base::string16 message_text() const { return message_text_; }

  // The label for the card.
  base::string16 card_label() const { return card_label_; }

  // The button label text.
  base::string16 button_label_text() const { return button_label_text_; }

  // The name of the icon image.
  NSString* icon_image_name() const { return icon_image_name_; }

 private:
  OVERLAY_USER_DATA_SETUP(SaveCardBannerRequestConfig);
  explicit SaveCardBannerRequestConfig(infobars::InfoBar* infobar);

  // OverlayUserData:
  void CreateAuxiliaryData(base::SupportsUserData* user_data) override;

  // The InfoBar causing this banner.
  infobars::InfoBar* infobar_ = nullptr;
  // Configuration data extracted from |infobar_|'s save card delegate.
  base::string16 message_text_;
  base::string16 card_label_;
  base::string16 button_label_text_;
  NSString* icon_image_name_ = nil;
};

}  // namespace save_card_infobar_overlays

#endif  // IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_INFOBAR_BANNER_SAVE_CARD_INFOBAR_BANNER_OVERLAY_REQUEST_CONFIG_H_
