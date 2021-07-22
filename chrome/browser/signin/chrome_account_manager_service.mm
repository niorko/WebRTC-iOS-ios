// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/signin/chrome_account_manager_service.h"

#include "base/check.h"
#include "base/strings/sys_string_conversions.h"
#include "components/prefs/pref_service.h"
#include "components/signin/public/base/signin_pref_names.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#include "ios/public/provider/chrome/browser/signin/chrome_identity_service.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Helper base class for functors.
template <typename T>
class Functor {
 public:
  explicit Functor(const PatternAccountRestriction& restriction)
      : restriction_(restriction) {}

  Functor(const Functor&) = delete;
  Functor& operator=(const Functor&) = delete;

  ios::ChromeIdentityService::IdentityIteratorCallback Callback() {
    // The callback is invoked synchronously and does not escape the scope
    // in which the Functor is defined. Thus it is safe to use Unretained
    // here.
    return base::BindRepeating(&Functor::Run, base::Unretained(this));
  }

 private:
  ios::IdentityIteratorCallbackResult Run(ChromeIdentity* identity) {
    // Filtering the ChromeIdentity.
    const std::string email = base::SysNSStringToUTF8(identity.userEmail);
    if (restriction_.IsAccountRestricted(email))
      return ios::kIdentityIteratorContinueIteration;

    return static_cast<T*>(this)->Run(identity);
  }

  const PatternAccountRestriction& restriction_;
};

// Helper class used to implement HasIdentities().
class FunctorHasIdentities : public Functor<FunctorHasIdentities> {
 public:
  explicit FunctorHasIdentities(const PatternAccountRestriction& restriction)
      : Functor(restriction) {}

  ios::IdentityIteratorCallbackResult Run(ChromeIdentity* identity) {
    has_identities_ = true;
    return ios::kIdentityIteratorInterruptIteration;
  }

  bool has_identities() const { return has_identities_; }

 private:
  bool has_identities_ = false;
};

// Helper class used to implement GetIdentityWithGaiaID().
class FunctorLookupIdentityByGaiaID
    : public Functor<FunctorLookupIdentityByGaiaID> {
 public:
  FunctorLookupIdentityByGaiaID(const PatternAccountRestriction& restriction,
                                NSString* gaia_id)
      : Functor(restriction), lookup_gaia_id_(gaia_id) {
    DCHECK(lookup_gaia_id_.length);
  }

  ios::IdentityIteratorCallbackResult Run(ChromeIdentity* identity) {
    if ([lookup_gaia_id_ isEqualToString:identity.gaiaID]) {
      identity_ = identity;
      return ios::kIdentityIteratorInterruptIteration;
    }
    return ios::kIdentityIteratorContinueIteration;
  }

  ChromeIdentity* identity() const { return identity_; }

 private:
  NSString* lookup_gaia_id_ = nil;
  ChromeIdentity* identity_ = nil;
};

// Helper class used to implement GetAllIdentities().
class FunctorCollectIdentities : public Functor<FunctorCollectIdentities> {
 public:
  FunctorCollectIdentities(const PatternAccountRestriction& restriction)
      : Functor(restriction), identities_([NSMutableArray array]) {}

  ios::IdentityIteratorCallbackResult Run(ChromeIdentity* identity) {
    [identities_ addObject:identity];
    return ios::kIdentityIteratorContinueIteration;
  }

  NSArray<ChromeIdentity*>* identities() const { return [identities_ copy]; }

 private:
  NSMutableArray<ChromeIdentity*>* identities_ = nil;
};

// Helper class used to implement GetDefaultIdentity().
class FunctorGetFirstIdentity : public Functor<FunctorGetFirstIdentity> {
 public:
  FunctorGetFirstIdentity(const PatternAccountRestriction& restriction)
      : Functor(restriction) {}

  ios::IdentityIteratorCallbackResult Run(ChromeIdentity* identity) {
    default_identity_ = identity;
    return ios::kIdentityIteratorInterruptIteration;
  }

  ChromeIdentity* default_identity() const { return default_identity_; }

 private:
  ChromeIdentity* default_identity_ = nil;
};

// Returns the PatternAccountRestriction according to the given PrefService.
PatternAccountRestriction PatternAccountRestrictionFromPreference(
    PrefService* pref_service) {
  const base::ListValue* patterns_pref =
      pref_service ? pref_service->GetList(prefs::kRestrictAccountsToPatterns)
                   : new base::ListValue();
  auto maybe_restriction = PatternAccountRestrictionFromValue(patterns_pref);
  CHECK(maybe_restriction);
  return *std::move(maybe_restriction);
}

}  // anonymous namespace.

ChromeAccountManagerService::ChromeAccountManagerService(
    PrefService* pref_service)
    : pref_service_(pref_service),
      restriction_(PatternAccountRestrictionFromPreference(pref_service)) {
  // pref_service is null in test environment. In prod environment pref_service
  // comes from GetApplicationContext()->GetLocalState() and couldn't be null.
  if (pref_service) {
    registrar_.Init(pref_service_);
    registrar_.Add(
        prefs::kRestrictAccountsToPatterns,
        base::BindRepeating(&ChromeAccountManagerService::UpdateRestriction,
                            base::Unretained(this)));

    // Force initialisation of `restriction_`.
    UpdateRestriction();
  }
}

bool ChromeAccountManagerService::HasIdentities() {
  FunctorHasIdentities helper(restriction_);
  ios::GetChromeBrowserProvider()
      .GetChromeIdentityService()
      ->IterateOverIdentities(helper.Callback());
  return helper.has_identities();
}

bool ChromeAccountManagerService::IsValidIdentity(ChromeIdentity* identity) {
  return GetIdentityWithGaiaID(identity.gaiaID) != nil;
}

ChromeIdentity* ChromeAccountManagerService::GetIdentityWithGaiaID(
    NSString* gaia_id) {
  // Do not iterate if the gaia ID is invalid.
  if (!gaia_id.length)
    return nil;

  FunctorLookupIdentityByGaiaID helper(restriction_, gaia_id);
  ios::GetChromeBrowserProvider()
      .GetChromeIdentityService()
      ->IterateOverIdentities(helper.Callback());
  return helper.identity();
}

ChromeIdentity* ChromeAccountManagerService::GetIdentityWithGaiaID(
    base::StringPiece gaia_id) {
  // Do not iterate if the gaia ID is invalid. This is duplicated here
  // to avoid allocating a NSString unnecessarily.
  if (gaia_id.empty())
    return nil;

  // Use the NSString* overload to avoid duplicating implementation.
  return GetIdentityWithGaiaID(base::SysUTF8ToNSString(gaia_id));
}

NSArray<ChromeIdentity*>* ChromeAccountManagerService::GetAllIdentities() {
  FunctorCollectIdentities helper(restriction_);
  ios::GetChromeBrowserProvider()
      .GetChromeIdentityService()
      ->IterateOverIdentities(helper.Callback());
  return [helper.identities() copy];
}

ChromeIdentity* ChromeAccountManagerService::GetDefaultIdentity() {
  FunctorGetFirstIdentity helper(restriction_);
  ios::GetChromeBrowserProvider()
      .GetChromeIdentityService()
      ->IterateOverIdentities(helper.Callback());
  return helper.default_identity();
}

void ChromeAccountManagerService::UpdateRestriction() {
  restriction_ = PatternAccountRestrictionFromPreference(pref_service_);
}

void ChromeAccountManagerService::Shutdown() {
  if (pref_service_) {
    registrar_.RemoveAll();
    pref_service_ = nullptr;
  }
}
