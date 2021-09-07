// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_VIEW_PUBLIC_CWV_UI_DELEGATE_H_
#define IOS_WEB_VIEW_PUBLIC_CWV_UI_DELEGATE_H_

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

#import "cwv_export.h"

NS_ASSUME_NONNULL_BEGIN

@class CWVFavicon;
@class CWVHTMLElement;
@class CWVPreviewElementInfo;
@class CWVWebView;
@class CWVWebViewConfiguration;
@class CWVNavigationAction;

// UI delegate interface for a CWVWebView.  Embedders can implement the
// functions in order to customize library behavior.
CWV_EXPORT
@protocol CWVUIDelegate<NSObject>

@optional
// Instructs the delegate to create a new browsing window (f.e. in response to
// window.open JavaScript call). Page will not open a window and report a
// failure (f.e. return null from window.open) if this method returns nil or is
// not implemented. This method can not return |webView|.
- (nullable CWVWebView*)webView:(CWVWebView*)webView
    createWebViewWithConfiguration:(CWVWebViewConfiguration*)configuration
               forNavigationAction:(CWVNavigationAction*)action;

// Instructs the delegate to close |webView|. Called only for windows opened by
// DOM.
- (void)webViewDidClose:(CWVWebView*)webView;

// Instructs the delegate to show UI in response to window.alert JavaScript
// call.
- (void)webView:(CWVWebView*)webView
    runJavaScriptAlertPanelWithMessage:(NSString*)message
                               pageURL:(NSURL*)URL
                     completionHandler:(void (^)(void))completionHandler;

// Instructs the delegate to show UI in response to window.confirm JavaScript
// call.
- (void)webView:(CWVWebView*)webView
    runJavaScriptConfirmPanelWithMessage:(NSString*)message
                                 pageURL:(NSURL*)URL
                       completionHandler:(void (^)(BOOL))completionHandler;

// Instructs the delegate to show UI in response to window.prompt JavaScript
// call.
- (void)webView:(CWVWebView*)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString*)prompt
                              defaultText:(NSString*)defaultText
                                  pageURL:(NSURL*)URL
                        completionHandler:
                            (void (^)(NSString* _Nullable))completionHandler;

// Called when favicons become available in the current page.
- (void)webView:(CWVWebView*)webView
    didLoadFavicons:(NSArray<CWVFavicon*>*)favIcons;

// Equivalent of -[WKUIDelegate
// webView:contextMenuConfigurationForElement:completionHandler:].
- (void)webView:(CWVWebView*)webView
    contextMenuConfigurationForElement:(CWVHTMLElement*)element
                     completionHandler:
                         (void (^)(UIContextMenuConfiguration* _Nullable))
                             completionHandler API_AVAILABLE(ios(13.0));

// Equivalent of -[WKUIDelegate
// webView:contextMenuWillPresentForElement:].
- (void)webView:(CWVWebView*)webView
    contextMenuWillPresentForLinkWithURL:(NSURL*)linkURL
    API_AVAILABLE(ios(13.0));

// Equivalent of -[WKUIDelegate
// webView:contextMenuForElement:willCommitWithAnimator:].
- (void)webView:(CWVWebView*)webView
    contextMenuForLinkWithURL:(NSURL*)linkURL
       willCommitWithAnimator:
           (id<UIContextMenuInteractionCommitAnimating>)animator
    API_AVAILABLE(ios(13.0));

// Equivalent of -[WKUIDelegate
// webView:contextMenuDidEndForElement:].
- (void)webView:(CWVWebView*)webView
    contextMenuDidEndForLinkWithURL:(NSURL*)linkURL API_AVAILABLE(ios(13.0));

@end

NS_ASSUME_NONNULL_END

#endif  // IOS_WEB_VIEW_PUBLIC_CWV_UI_DELEGATE_H_
