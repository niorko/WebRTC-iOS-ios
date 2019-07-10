// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/navigation/crw_web_view_navigation_observer.h"

#include "base/logging.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/net/http_response_headers_util.h"
#include "ios/web/common/features.h"
#include "ios/web/common/url_util.h"
#import "ios/web/navigation/crw_navigation_item_holder.h"
#import "ios/web/navigation/crw_pending_navigation_info.h"
#import "ios/web/navigation/crw_web_view_navigation_observer_delegate.h"
#import "ios/web/navigation/crw_wk_navigation_handler.h"
#import "ios/web/navigation/crw_wk_navigation_states.h"
#import "ios/web/navigation/navigation_context_impl.h"
#import "ios/web/navigation/wk_navigation_util.h"
#import "ios/web/public/web_client.h"
#import "ios/web/web_state/web_state_impl.h"
#import "ios/web/web_view/wk_web_view_util.h"
#import "net/base/mac/url_conversions.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using web::NavigationManagerImpl;

using web::wk_navigation_util::IsRestoreSessionUrl;
using web::wk_navigation_util::IsPlaceholderUrl;

@interface CRWWebViewNavigationObserver ()

// Dictionary where keys are the names of WKWebView properties and values are
// selector names which should be called when a corresponding property has
// changed. e.g. @{ @"URL" : @"webViewURLDidChange" } means that
// -[self webViewURLDidChange] must be called every time when WKWebView.URL is
// changed.
@property(weak, nonatomic, readonly) NSDictionary* WKWebViewObservers;

@property(nonatomic, assign, readonly) web::WebStateImpl* webStateImpl;

// The WKNavigationDelegate handler class.
@property(nonatomic, readonly, strong)
    CRWWKNavigationHandler* navigationHandler;

// The actual URL of the document object (i.e., the last committed URL).
@property(nonatomic, readonly) const GURL& documentURL;

// The NavigationManagerImpl associated with the web state.
@property(nonatomic, readonly) NavigationManagerImpl* navigationManagerImpl;

@end

@implementation CRWWebViewNavigationObserver

#pragma mark - Property

- (void)setWebView:(WKWebView*)webView {
  for (NSString* keyPath in self.WKWebViewObservers) {
    [_webView removeObserver:self forKeyPath:keyPath];
  }

  _webView = webView;

  for (NSString* keyPath in self.WKWebViewObservers) {
    [_webView addObserver:self forKeyPath:keyPath options:0 context:nullptr];
  }
}

- (NSDictionary*)WKWebViewObservers {
  return @{
    @"estimatedProgress" : @"webViewEstimatedProgressDidChange",
    @"loading" : @"webViewLoadingStateDidChange",
    @"canGoForward" : @"webViewBackForwardStateDidChange",
    @"canGoBack" : @"webViewBackForwardStateDidChange",
    @"URL" : @"webViewURLDidChange",
  };
}

- (NavigationManagerImpl*)navigationManagerImpl {
  return self.webStateImpl ? &(self.webStateImpl->GetNavigationManagerImpl())
                           : nil;
}

- (web::WebStateImpl*)webStateImpl {
  return [self.delegate webStateImplForNavigationObserver:self];
}

- (CRWWKNavigationHandler*)navigationHandler {
  return [self.delegate navigationHandlerForNavigationObserver:self];
}

- (const GURL&)documentURL {
  return [self.delegate documentURLForNavigationObserver:self];
}

#pragma mark - KVO Observation

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
  NSString* dispatcherSelectorName = self.WKWebViewObservers[keyPath];
  DCHECK(dispatcherSelectorName);
  if (dispatcherSelectorName) {
    // With ARC memory management, it is not known what a method called
    // via a selector will return. If a method returns a retained value
    // (e.g. NS_RETURNS_RETAINED) that returned object will leak as ARC is
    // unable to property insert the correct release calls for it.
    // All selectors used here return void and take no parameters so it's safe
    // to call a function mapping to the method implementation manually.
    SEL selector = NSSelectorFromString(dispatcherSelectorName);
    IMP methodImplementation = [self methodForSelector:selector];
    if (methodImplementation) {
      void (*methodCallFunction)(id, SEL) =
          reinterpret_cast<void (*)(id, SEL)>(methodImplementation);
      methodCallFunction(self, selector);
    }
  }
}

// Called when WKWebView estimatedProgress has been changed.
- (void)webViewEstimatedProgressDidChange {
  self.webStateImpl->SendChangeLoadProgress(self.webView.estimatedProgress);
}

// Called when WKWebView loading state has been changed.
- (void)webViewLoadingStateDidChange {
  if (self.webView.loading)
    return;

  GURL webViewURL = net::GURLWithNSURL(self.webView.URL);

  if (![self.navigationHandler isCurrentNavigationBackForward])
    return;

  web::NavigationContextImpl* existingContext = [self.navigationHandler
      contextForPendingMainFrameNavigationWithURL:webViewURL];

  // When traversing history restored from a previous session, WKWebView does
  // not fire 'pageshow', 'onload', 'popstate' or any of the
  // WKNavigationDelegate callbacks for back/forward navigation from an about:
  // scheme placeholder URL to another entry or if either of the redirect fails
  // to load (e.g. in airplane mode). Loading state KVO is the only observable
  // event in this scenario, so force a reload to trigger redirect from
  // restore_session.html to the restored URL.
  bool previousURLHasAboutScheme =
      self.documentURL.SchemeIs(url::kAboutScheme) ||
      IsPlaceholderUrl(self.documentURL) ||
      web::GetWebClient()->IsAppSpecificURL(self.documentURL);
  bool is_back_forward_navigation =
      existingContext &&
      (existingContext->GetPageTransition() & ui::PAGE_TRANSITION_FORWARD_BACK);
  if (web::GetWebClient()->IsSlimNavigationManagerEnabled() &&
      IsRestoreSessionUrl(webViewURL)) {
    if (previousURLHasAboutScheme || is_back_forward_navigation) {
      [self.webView reload];
      self.navigationHandler.navigationState =
          web::WKNavigationState::REQUESTED;
      return;
    }
  }

  // For failed navigations, WKWebView will sometimes revert to the previous URL
  // before committing the current navigation or resetting the web view's
  // |isLoading| property to NO.  If this is the first navigation for the web
  // view, this will result in an empty URL.
  BOOL navigationWasCommitted = self.navigationHandler.navigationState !=
                                web::WKNavigationState::REQUESTED;
  if (!navigationWasCommitted &&
      (webViewURL.is_empty() || webViewURL == self.documentURL)) {
    return;
  }

  if (!navigationWasCommitted &&
      !self.navigationHandler.pendingNavigationInfo.cancelled) {
    // A fast back-forward navigation does not call |didCommitNavigation:|, so
    // signal page change explicitly.
    DCHECK_EQ(self.documentURL.GetOrigin(), webViewURL.GetOrigin());
    BOOL isSameDocumentNavigation =
        [self isKVOChangePotentialSameDocumentNavigationToURL:webViewURL];

    [self.delegate navigationObserver:self
                 didChangeDocumentURL:webViewURL
                           forContext:existingContext];
    if (!existingContext) {
      // This URL was not seen before, so register new load request.
      [self.delegate navigationObserver:self
                          didLoadNewURL:webViewURL
              forSameDocumentNavigation:isSameDocumentNavigation];
    } else {
      // Same document navigation does not contain response headers.
      net::HttpResponseHeaders* headers =
          isSameDocumentNavigation
              ? nullptr
              : self.webStateImpl->GetHttpResponseHeaders();
      existingContext->SetResponseHeaders(headers);
      existingContext->SetIsSameDocument(isSameDocumentNavigation);
      existingContext->SetHasCommitted(!isSameDocumentNavigation);
      self.webStateImpl->OnNavigationStarted(existingContext);
      [self.delegate navigationObserver:self
               didChangePageWithContext:existingContext];
      self.webStateImpl->OnNavigationFinished(existingContext);
    }
  }

  [self.delegate navigationObserverDidChangeSSLStatus:self];
  [self.delegate navigationObserver:self didFinishNavigation:existingContext];
}

// Called when WKWebView canGoForward/canGoBack state has been changed.
- (void)webViewBackForwardStateDidChange {
  // Don't trigger for LegacyNavigationManager because its back/foward state
  // doesn't always match that of WKWebView.
  if (web::GetWebClient()->IsSlimNavigationManagerEnabled())
    self.webStateImpl->OnBackForwardStateChanged();
}

// Called when WKWebView URL has been changed.
- (void)webViewURLDidChange {
  // TODO(crbug.com/966412): Determine if there are any cases where this still
  // happens, and if so whether anything should be done when it does.
  if (!self.webView.URL) {
    DVLOG(1) << "Received nil URL callback";
    return;
  }
  GURL URL(net::GURLWithNSURL(self.webView.URL));
  // URL changes happen at four points:
  // 1) When a load starts; at this point, the load is provisional, and
  //    it should be ignored until it's committed, since the document/window
  //    objects haven't changed yet.
  // 2) When a non-document-changing URL change happens (hash change,
  //    history.pushState, etc.). This URL change happens instantly, so should
  //    be reported.
  // 3) When a navigation error occurs after provisional navigation starts,
  //    the URL reverts to the previous URL without triggering a new navigation.
  // 4) When a SafeBrowsing warning is displayed after
  //    decidePolicyForNavigationAction but before a provisional navigation
  //    starts, and the user clicks the "Go Back" link on the warning page.
  //
  // If |isLoading| is NO, then it must be case 2, 3, or 4. If the last
  // committed URL (_documentURL) matches the current URL, assume that it is
  // case 4 if a SafeBrowsing warning is currently displayed and case 3
  // otherwise. If the URL does not match, assume it is a non-document-changing
  // URL change, and handle accordingly.
  //
  // If |isLoading| is YES, then it could either be case 1, or it could be case
  // 2 on a page that hasn't finished loading yet. If it's possible that it
  // could be a same-page navigation (in which case there may not be any other
  // callback about the URL having changed), then check the actual page URL via
  // JavaScript. If the origin of the new URL matches the last committed URL,
  // then check window.location.href, and if it matches, trust it. The origin
  // check ensures that if a site somehow corrupts window.location.href it can't
  // do a redirect to a slow-loading target page while it is still loading to
  // spoof the origin. On a document-changing URL change, the
  // window.location.href will match the previous URL at this stage, not the web
  // view's current URL.
  if (!self.webView.loading) {
    if (self.documentURL == URL) {
      if (!web::IsSafeBrowsingWarningDisplayedInWebView(self.webView))
        return;

      self.navigationManagerImpl->DiscardNonCommittedItems();
      self.webStateImpl->SetIsLoading(false);
      self.navigationHandler.pendingNavigationInfo = nil;
      if (web::GetWebClient()->IsSlimNavigationManagerEnabled()) {
        // Right after a history navigation that gets cancelled by a tap on
        // "Go Back", WKWebView's current back/forward list item will still be
        // for the unsafe page; updating this is the responsibility of the
        // WebProcess, so only happens after an IPC round-trip to and from the
        // WebProcess with no notification to the embedder. This means that
        // WKBasedNavigationManagerImpl::WKWebViewCache::GetCurrentItemIndex()
        // will be the index of the unsafe page's item. To get back into a
        // consistent state, force a reload.
        [self.webView reload];
      } else {
        // Tapping "Go Back" on a SafeBrowsing interstitial can change whether
        // there are any forward or back items, e.g., by returning to or
        // moving away from the forward-most or back-most item.
        self.webStateImpl->OnBackForwardStateChanged();
      }
      return;
    }

    // At this point, self.webView, self.webView.backForwardList.currentItem and
    // its associated NavigationItem should all have the same URL, except in two
    // edge cases:
    // 1. location.replace that only changes hash: WebKit updates
    // self.webView.URL
    //    and currentItem.URL, and NavigationItem URL must be synced.
    // 2. location.replace to about: URL: a WebKit bug causes only
    // self.webView.URL,
    //    but not currentItem.URL to be updated. NavigationItem URL should be
    //    synced to self.webView.URL.
    // This needs to be done before |URLDidChangeWithoutDocumentChange| so any
    // WebStateObserver callbacks will see the updated URL.
    // TODO(crbug.com/809287) use currentItem.URL instead of self.webView.URL to
    // update NavigationItem URL.
    if (web::GetWebClient()->IsSlimNavigationManagerEnabled()) {
      const GURL webViewURL = net::GURLWithNSURL(self.webView.URL);
      web::NavigationItem* currentItem = nullptr;
      if (self.webView.backForwardList.currentItem) {
        currentItem = [[CRWNavigationItemHolder
            holderForBackForwardListItem:self.webView.backForwardList
                                             .currentItem] navigationItem];
      } else {
        // WKBackForwardList.currentItem may be nil in a corner case when
        // location.replace is called with about:blank#hash in an empty window
        // open tab. See crbug.com/866142.
        DCHECK(self.webStateImpl->HasOpener());
        DCHECK(!self.navigationManagerImpl->GetTransientItem());
        DCHECK(!self.navigationManagerImpl->GetPendingItem());
        currentItem = self.navigationManagerImpl->GetLastCommittedItem();
      }
      if (currentItem && webViewURL != currentItem->GetURL())
        currentItem->SetURL(webViewURL);
    }

    [self.delegate navigationObserver:self
        URLDidChangeWithoutDocumentChange:URL];
  } else if ([self isKVOChangePotentialSameDocumentNavigationToURL:URL]) {
    WKNavigation* navigation =
        [self.navigationHandler.navigationStates lastAddedNavigation];
    [self.webView
        evaluateJavaScript:@"window.location.href"
         completionHandler:^(id result, NSError* error) {
           // If the web view has gone away, or the location
           // couldn't be retrieved, abort.
           if (!self.webView || ![result isKindOfClass:[NSString class]]) {
             return;
           }
           GURL JSURL(base::SysNSStringToUTF8(result));
           // Check that window.location matches the new URL. If
           // it does not, this is a document-changing URL change as
           // the window location would not have changed to the new
           // URL when the script was called.
           BOOL windowLocationMatchesNewURL = JSURL == URL;
           // Re-check origin in case navigaton has occurred since
           // start of JavaScript evaluation.
           BOOL newURLOriginMatchesDocumentURLOrigin =
               self.documentURL.GetOrigin() == URL.GetOrigin();
           // Check that the web view URL still matches the new URL.
           // TODO(crbug.com/563568): webViewURLMatchesNewURL check
           // may drop same document URL changes if pending URL
           // change occurs immediately after. Revisit heuristics to
           // prevent this.
           BOOL webViewURLMatchesNewURL =
               net::GURLWithNSURL(self.webView.URL) == URL;
           // Check that the new URL is different from the current
           // document URL. If not, URL change should not be reported.
           BOOL URLDidChangeFromDocumentURL = URL != self.documentURL;
           // Check if a new different document navigation started before the JS
           // completion block fires. Check WKNavigationState to make sure this
           // navigation has started in WKWebView. If so, don't run the block to
           // avoid clobbering global states. See crbug.com/788452.
           // TODO(crbug.com/788465): simplify hisgtory state handling to avoid
           // this hack.
           WKNavigation* last_added_navigation =
               [self.navigationHandler.navigationStates lastAddedNavigation];
           BOOL differentDocumentNavigationStarted =
               navigation != last_added_navigation &&
               [self.navigationHandler.navigationStates
                   stateForNavigation:last_added_navigation] >=
                   web::WKNavigationState::STARTED;
           if (windowLocationMatchesNewURL &&
               newURLOriginMatchesDocumentURLOrigin &&
               webViewURLMatchesNewURL && URLDidChangeFromDocumentURL &&
               !differentDocumentNavigationStarted) {
             [self.delegate navigationObserver:self
                 URLDidChangeWithoutDocumentChange:URL];
           }
         }];
  }
}

#pragma mark - Private

// Returns YES if a KVO change to |newURL| could be a 'navigation' within the
// document (hash change, pushState/replaceState, etc.). This should only be
// used in the context of a URL KVO callback firing, and only if |isLoading| is
// YES for the web view (since if it's not, no guesswork is needed).
- (BOOL)isKVOChangePotentialSameDocumentNavigationToURL:(const GURL&)newURL {
  // If the origin changes, it can't be same-document.
  if (self.documentURL.GetOrigin().is_empty() ||
      self.documentURL.GetOrigin() != newURL.GetOrigin()) {
    return NO;
  }
  if (self.navigationHandler.navigationState ==
      web::WKNavigationState::REQUESTED) {
    // Normally LOAD_REQUESTED indicates that this is a regular, pending
    // navigation, but it can also happen during a fast-back navigation across
    // a hash change, so that case is potentially a same-document navigation.
    return web::GURLByRemovingRefFromGURL(newURL) ==
           web::GURLByRemovingRefFromGURL(self.documentURL);
  }
  // If it passes all the checks above, it might be (but there's no guarantee
  // that it is).
  return YES;
}

@end
