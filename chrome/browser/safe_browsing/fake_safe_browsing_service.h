// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_SAFE_BROWSING_FAKE_SAFE_BROWSING_SERVICE_H_
#define IOS_CHROME_BROWSER_SAFE_BROWSING_FAKE_SAFE_BROWSING_SERVICE_H_

#include "ios/chrome/browser/safe_browsing/safe_browsing_service.h"

// A fake SafeBrowsingService whose database treats all URLs as safe.
class FakeSafeBrowsingService : public SafeBrowsingService {
 public:
  FakeSafeBrowsingService();

  FakeSafeBrowsingService(const FakeSafeBrowsingService&) = delete;
  FakeSafeBrowsingService& operator=(const FakeSafeBrowsingService&) = delete;

  // SafeBrowsingService:
  void Initialize(PrefService* prefs,
                  const base::FilePath& user_data_path) override;
  void ShutDown() override;
  std::unique_ptr<safe_browsing::SafeBrowsingUrlCheckerImpl> CreateUrlChecker(
      safe_browsing::ResourceType resource_type,
      web::WebState* web_state) override;

 protected:
  ~FakeSafeBrowsingService() override;
};

#endif  // IOS_CHROME_BROWSER_SAFE_BROWSING_FAKE_SAFE_BROWSING_SERVICE_H_
