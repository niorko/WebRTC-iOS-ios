// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_CONTENT_WEB_STATE_CONTENT_WEB_STATE_H_
#define IOS_WEB_CONTENT_WEB_STATE_CONTENT_WEB_STATE_H_

#import "ios/web/public/web_state.h"

#import <memory>

#import <UIKit/UIKit.h>

#import "base/observer_list.h"
#import "build/blink_buildflags.h"
#import "ios/web/content/js_messaging/content_web_frames_manager.h"
#import "ios/web/content/navigation/content_navigation_manager.h"

@class CRWWebViewProxy;

#if !BUILDFLAG(USE_BLINK)
#error File can only be included when USE_BLINK is true
#endif

namespace web {

// ContentWebState is an implementation of WebState that's based on WebContents.
class ContentWebState : public WebState {
 public:
  explicit ContentWebState(const CreateParams& params);
  ~ContentWebState() override;

  // WebState implementation.
  WebStateDelegate* GetDelegate() override;
  void SetDelegate(WebStateDelegate* delegate) override;
  bool IsRealized() const final;
  WebState* ForceRealized() final;
  bool IsWebUsageEnabled() const override;
  void SetWebUsageEnabled(bool enabled) override;
  UIView* GetView() override;
  void DidCoverWebContent() override;
  void DidRevealWebContent() override;
  base::Time GetLastActiveTime() const final;
  base::Time GetCreationTime() const final;
  void WasShown() override;
  void WasHidden() override;
  void SetKeepRenderProcessAlive(bool keep_alive) override;
  BrowserState* GetBrowserState() const override;
  base::WeakPtr<WebState> GetWeakPtr() override;
  void OpenURL(const OpenURLParams& params) override;
  void LoadSimulatedRequest(const GURL& url,
                            NSString* response_html_string) override
      API_AVAILABLE(ios(15.0));
  void LoadSimulatedRequest(const GURL& url,
                            NSData* response_data,
                            NSString* mime_type) override
      API_AVAILABLE(ios(15.0));
  void Stop() override;
  const NavigationManager* GetNavigationManager() const override;
  NavigationManager* GetNavigationManager() override;
  WebFramesManager* GetPageWorldWebFramesManager() override;
  const SessionCertificatePolicyCache* GetSessionCertificatePolicyCache()
      const override;
  SessionCertificatePolicyCache* GetSessionCertificatePolicyCache() override;
  CRWSessionStorage* BuildSessionStorage() override;
  void LoadData(NSData* data, NSString* mime_type, const GURL& url) override;
  void ExecuteUserJavaScript(NSString* javaScript) override;
  NSString* GetStableIdentifier() const override;
  const std::string& GetContentsMimeType() const override;
  bool ContentIsHTML() const override;
  const std::u16string& GetTitle() const override;
  bool IsLoading() const override;
  double GetLoadingProgress() const override;
  bool IsVisible() const override;
  bool IsCrashed() const override;
  bool IsEvicted() const override;
  bool IsBeingDestroyed() const override;
  bool IsWebPageInFullscreenMode() const override;
  const FaviconStatus& GetFaviconStatus() const final;
  void SetFaviconStatus(const FaviconStatus& favicon_status) final;
  int GetNavigationItemCount() const override;
  const GURL& GetVisibleURL() const override;
  const GURL& GetLastCommittedURL() const override;
  GURL GetCurrentURL(URLVerificationTrustLevel* trust_level) const override;
  WebFramesManager* GetWebFramesManager(ContentWorld world) override;
  CRWWebViewProxyType GetWebViewProxy() const override;
  void AddObserver(WebStateObserver* observer) override;
  void RemoveObserver(WebStateObserver* observer) override;
  void CloseWebState() override;
  bool SetSessionStateData(NSData* data) override;
  NSData* SessionStateData() override;
  void SetSwipeRecognizerProvider(
      id<CRWSwipeRecognizerProvider> delegate) override;
  PermissionState GetStateForPermission(Permission permission) const override
      API_AVAILABLE(ios(15.0));
  void SetStateForPermission(PermissionState state,
                             Permission permission) override
      API_AVAILABLE(ios(15.0));
  NSDictionary<NSNumber*, NSNumber*>* GetStatesForAllPermissions()
      const override API_AVAILABLE(ios(15.0));
  void DownloadCurrentPage(NSString* destination_file,
                           id<CRWWebViewDownloadDelegate> delegate,
                           void (^handler)(id<CRWWebViewDownload>)) override
      API_AVAILABLE(ios(14.5));
  bool IsFindInteractionSupported() final;
  bool IsFindInteractionEnabled() final;
  void SetFindInteractionEnabled(bool enabled) final;
  id<CRWFindInteraction> GetFindInteraction() final API_AVAILABLE(ios(16));
  id GetActivityItem() API_AVAILABLE(ios(16.4)) final;
  void AddPolicyDecider(WebStatePolicyDecider* decider) override;
  void RemovePolicyDecider(WebStatePolicyDecider* decider) override;
  void DidChangeVisibleSecurityState() override;
  bool HasOpener() const override;
  void SetHasOpener(bool has_opener) override;
  bool CanTakeSnapshot() const override;
  void TakeSnapshot(const gfx::RectF& rect, SnapshotCallback callback) override;
  void CreateFullPagePdf(base::OnceCallback<void(NSData*)> callback) override;
  void CloseMediaPresentations() override;

 private:
  UIScrollView* web_view_;
  id<CRWWebViewProxy> web_view_proxy_;
  NSString* UUID_;
  base::ObserverList<WebStatePolicyDecider, true> policy_deciders_;
  base::ObserverList<WebStateObserver, true> observers_;
  std::unique_ptr<ContentNavigationManager> navigation_manager_;
  std::unique_ptr<ContentWebFramesManager> web_frames_manager_;
};

}  // namespace web

#endif  // IOS_WEB_CONTENT_WEB_STATE_CONTENT_WEB_STATE_H_
