// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/promos_manager/promos_manager.h"

#import "base/values.h"
#import "components/prefs/pref_service.h"
#import "ios/chrome/browser/pref_names.h"
#import "ios/chrome/browser/promos_manager/features.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#pragma mark - PromosManager

#pragma mark - Constructor/Destructor

PromosManager::PromosManager(PrefService* local_state)
    : local_state_(local_state) {
  DCHECK(local_state_);
}

PromosManager::~PromosManager() = default;

#pragma mark - Public

void PromosManager::Init() {
  if (!IsFullscreenPromosManagerEnabled())
    return;

  DCHECK(local_state_);

  const base::Value::List& stored_active_promos =
      local_state_->GetValueList(prefs::kIosPromosManagerActivePromos);
  const base::Value::List& stored_impression_history =
      local_state_->GetValueList(prefs::kIosPromosManagerImpressions);

  active_promos_ = stored_active_promos.Clone();
  impression_history_ = stored_impression_history.Clone();
}
