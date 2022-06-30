// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_IMAGE_UTIL_IMAGE_COPIER_H_
#define IOS_CHROME_BROWSER_UI_IMAGE_UTIL_IMAGE_COPIER_H_

#import <UIKit/UIKit.h>

class Browser;
class GURL;

namespace web {
struct Referrer;
class WebState;
}

// Object copying images to the system's pasteboard.
@interface ImageCopier : NSObject

// Init the ImageCopier.
- (instancetype)initWithBrowser:(Browser*)browser;

// Copies the image at `url`. `web_state` is used for fetching image data by
// JavaScript. `referrer` is used for download. `baseViewController` used to
// display alerts.
- (void)copyImageAtURL:(const GURL&)url
              referrer:(const web::Referrer&)referrer
              webState:(web::WebState*)webState
    baseViewController:(UIViewController*)baseViewController;

@end

#endif  // IOS_CHROME_BROWSER_UI_IMAGE_UTIL_IMAGE_COPIER_H_
