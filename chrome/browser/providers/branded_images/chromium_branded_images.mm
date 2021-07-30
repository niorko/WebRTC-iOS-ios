// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/notreached.h"
#include "ios/chrome/grit/ios_theme_resources.h"
#import "ios/public/provider/chrome/browser/branded_images/branded_images_api.h"
#include "ui/base/resource/resource_bundle.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace ios {
namespace provider {

UIImage* GetBrandedImage(BrandedImage branded_image) {
  switch (branded_image) {
    case BrandedImage::kClearBrowsingDataAccountActivity: {
      ui::ResourceBundle& rb = ui::ResourceBundle::GetSharedInstance();
      return rb.GetNativeImageNamed(IDR_IOS_SETTINGS_INFO_24).ToUIImage();
    }

    case BrandedImage::kClearBrowsingDataSiteData: {
      ui::ResourceBundle& rb = ui::ResourceBundle::GetSharedInstance();
      return rb.GetNativeImageNamed(IDR_IOS_SETTINGS_INFO_24).ToUIImage();
    }

    case BrandedImage::kWhatsNewLogo: {
      ui::ResourceBundle& rb = ui::ResourceBundle::GetSharedInstance();
      return rb.GetNativeImageNamed(IDR_IOS_PROMO_INFO).ToUIImage();
    }

    case BrandedImage::kWhatsNewLogoRoundedRectangle: {
      ui::ResourceBundle& rb = ui::ResourceBundle::GetSharedInstance();
      return rb.GetNativeImageNamed(IDR_IOS_PROMO_INFO).ToUIImage();
    }

    case BrandedImage::kDownloadGoogleDrive:
      return [UIImage imageNamed:@"download_drivium"];

    case BrandedImage::kOmniboxAnswer:
      return nil;

    case BrandedImage::kStaySafePromo:
      return [UIImage imageNamed:@"chromium_stay_safe"];

    case BrandedImage::kMadeForIOSPromo:
      return [UIImage imageNamed:@"chromium_ios_made"];

    case BrandedImage::kMadeForIPadOSPromo:
      return [UIImage imageNamed:@"chromium_ipados_made"];

    case BrandedImage::kNonModalDefaultBrowserPromo:
      return [UIImage imageNamed:@"chromium_non_default_promo"];
  }

  NOTREACHED();
  return nil;
}

}  // namespace provider
}  // namespace ios
