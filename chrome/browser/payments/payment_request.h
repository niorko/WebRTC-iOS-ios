// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PAYMENTS_PAYMENT_REQUEST_H_
#define IOS_CHROME_BROWSER_PAYMENTS_PAYMENT_REQUEST_H_

#include <memory>
#include <set>
#include <string>
#include <vector>

#include "base/macros.h"
#include "components/payments/core/payment_options_provider.h"
#include "components/payments/core/payment_request_base_delegate.h"
#include "components/payments/core/payments_profile_comparator.h"
#include "ios/web/public/payments/payment_request.h"

namespace autofill {
class AutofillProfile;
class CreditCard;
class PersonalDataManager;
class RegionDataLoader;
}  // namespace autofill

namespace payments {
class AddressNormalizer;
class AddressNormalizerImpl;
class CurrencyFormatter;
}  // namespace payments

// A protocol implementd by any UI classes that the PaymentRequest object
// needs to communicate with in order to perform certain actions such as
// initiating UI to request full card details for payment.
@protocol PaymentRequestUIDelegate<NSObject>

- (void)openFullCardRequestUI;

@end

// Has a copy of web::PaymentRequest as provided by the page invoking the
// PaymentRequest API. Also caches credit cards and addresses provided by the
// |personal_data_manager| and manages shared resources and user selections for
// the current PaymentRequest flow. It must be initialized with a non-null
// instance of |personal_data_manager| that outlives this class.
class PaymentRequest : public payments::PaymentOptionsProvider,
                       public payments::PaymentRequestBaseDelegate {
 public:
  // |personal_data_manager| should not be null and should outlive this object.
  PaymentRequest(const web::PaymentRequest& web_payment_request,
                 autofill::PersonalDataManager* personal_data_manager,
                 id<PaymentRequestUIDelegate> payment_request_ui_delegate);
  ~PaymentRequest() override;

  // PaymentRequestBaseDelegate:
  autofill::PersonalDataManager* GetPersonalDataManager() override;
  const std::string& GetApplicationLocale() const override;
  bool IsIncognito() const override;
  bool IsSslCertificateValid() override;
  const GURL& GetLastCommittedURL() const override;
  void DoFullCardRequest(
      const autofill::CreditCard& credit_card,
      base::WeakPtr<autofill::payments::FullCardRequest::ResultDelegate>
          result_delegate) override;
  payments::AddressNormalizer* GetAddressNormalizer() override;
  autofill::RegionDataLoader* GetRegionDataLoader() override;
  ukm::UkmRecorder* GetUkmRecorder() override;
  std::string GetAuthenticatedEmail() const override;
  PrefService* GetPrefService() override;

  // Returns the web::PaymentRequest that was used to build this PaymentRequest.
  const web::PaymentRequest& web_payment_request() const {
    return web_payment_request_;
  }

  // Returns the payment details from |web_payment_request_|.
  const web::PaymentDetails& payment_details() const {
    return web_payment_request_.details;
  }

  // Updates the payment details of the |web_payment_request_|. It also updates
  // the cached references to the shipping options in |web_payment_request_| as
  // well as the reference to the selected shipping option.
  void UpdatePaymentDetails(const web::PaymentDetails& details);

  // PaymentOptionsProvider:
  bool request_shipping() const override;
  bool request_payer_name() const override;
  bool request_payer_phone() const override;
  bool request_payer_email() const override;
  payments::PaymentShippingType shipping_type() const override;

  // Returns the payments::CurrencyFormatter instance for this PaymentRequest.
  // Note: Having multiple currencies per PaymentRequest flow is not supported;
  // hence the CurrencyFormatter is cached here.
  payments::CurrencyFormatter* GetOrCreateCurrencyFormatter();

  // Adds |profile| to the list of cached profiles, updates the list of
  // available shipping and contact profiles, and returns a reference to the
  // cached copy of |profile|.
  virtual autofill::AutofillProfile* AddAutofillProfile(
      const autofill::AutofillProfile& profile);

  // Returns the available autofill profiles for this user to be used as
  // shipping profiles.
  const std::vector<autofill::AutofillProfile*>& shipping_profiles() const {
    return shipping_profiles_;
  }

  // Returns the currently selected shipping profile for this PaymentRequest
  // flow if there is one. Returns nullptr if there is no selected profile.
  autofill::AutofillProfile* selected_shipping_profile() const {
    return selected_shipping_profile_;
  }

  // Sets the currently selected shipping profile for this PaymentRequest flow.
  void set_selected_shipping_profile(autofill::AutofillProfile* profile) {
    selected_shipping_profile_ = profile;
  }

  // Returns the available autofill profiles for this user to be used as
  // contact profiles.
  const std::vector<autofill::AutofillProfile*>& contact_profiles() const {
    return contact_profiles_;
  }

  // Returns the currently selected contact profile for this PaymentRequest
  // flow if there is one. Returns nullptr if there is no selected profile.
  autofill::AutofillProfile* selected_contact_profile() const {
    return selected_contact_profile_;
  }

  // Sets the currently selected contact profile for this PaymentRequest flow.
  void set_selected_contact_profile(autofill::AutofillProfile* profile) {
    selected_contact_profile_ = profile;
  }

  // Returns the available autofill profiles for this user to be used as
  // billing profiles.
  const std::vector<autofill::AutofillProfile*>& billing_profiles() const {
    return shipping_profiles_;
  }

  const std::vector<std::string>& supported_card_networks() const {
    return supported_card_networks_;
  }

  const std::set<std::string>& basic_card_specified_networks() const {
    return basic_card_specified_networks_;
  }

  // Adds |credit_card| to the list of cached credit cards, updates the list of
  // available credit cards, and returns a reference to the cached copy of
  // |credit_card|.
  virtual autofill::CreditCard* AddCreditCard(
      const autofill::CreditCard& credit_card);

  // Returns the available autofill credit cards for this user that match a
  // supported type specified in |web_payment_request_|.
  const std::vector<autofill::CreditCard*>& credit_cards() const {
    return credit_cards_;
  }

  // Returns the currently selected credit card for this PaymentRequest flow if
  // there is one. Returns nullptr if there is no selected credit card.
  autofill::CreditCard* selected_credit_card() const {
    return selected_credit_card_;
  }

  // Sets the currently selected credit card for this PaymentRequest flow.
  void set_selected_credit_card(autofill::CreditCard* credit_card) {
    selected_credit_card_ = credit_card;
  }

  // Returns the available shipping options from |web_payment_request_|.
  const std::vector<web::PaymentShippingOption*>& shipping_options() const {
    return shipping_options_;
  }

  // Returns the selected shipping option from |web_payment_request_| if there
  // is one. Returns nullptr otherwise.
  web::PaymentShippingOption* selected_shipping_option() const {
    return selected_shipping_option_;
  }

  virtual payments::PaymentsProfileComparator* profile_comparator();

  // Returns whether the current PaymentRequest can be used to make a payment.
  bool CanMakePayment() const;

 protected:
  // Fetches the autofill profiles for this user from the PersonalDataManager,
  // and stores copies of them, owned by this PaymentRequest, in profile_cache_.
  void PopulateProfileCache();

  // Sets the available shipping and contact profiles as references to the
  // cached profiles ordered by completeness.
  void PopulateAvailableProfiles();

  // Fetches the autofill credit cards for this user from the
  // PersonalDataManager that match a supported type specified in
  // |web_payment_request_| and stores copies of them, owned by this
  // PaymentRequest, in credit_card_cache_.
  void PopulateCreditCardCache();

  // Sets the available credit cards as references to the cached credit cards.
  void PopulateAvailableCreditCards();

  // Sets the available shipping options as references to the shipping options
  // in |web_payment_request_|.
  void PopulateAvailableShippingOptions();

  // Sets the selected shipping option, if any.
  void SetSelectedShippingOption();

  // The web::PaymentRequest object as provided by the page invoking the Payment
  // Request API, owned by this object.
  web::PaymentRequest web_payment_request_;

  // Never null and outlives this object.
  autofill::PersonalDataManager* personal_data_manager_;

  // The PaymentRequestUIDelegate as provided by the UI object that originally
  // created this PaymentRequest object.
  __weak id<PaymentRequestUIDelegate> payment_request_ui_delegate_;

  // The address normalizer to use for the duration of the Payment Request.
  payments::AddressNormalizerImpl* address_normalizer_;

  // The currency formatter instance for this PaymentRequest flow.
  std::unique_ptr<payments::CurrencyFormatter> currency_formatter_;

  // Profiles returned by the Data Manager may change due to (e.g.) sync events,
  // meaning PaymentRequest may outlive them. Therefore, profiles are fetched
  // once and their copies are cached here. Whenever profiles are requested a
  // vector of pointers to these copies are returned.
  std::vector<std::unique_ptr<autofill::AutofillProfile>> profile_cache_;

  std::vector<autofill::AutofillProfile*> shipping_profiles_;
  autofill::AutofillProfile* selected_shipping_profile_;

  std::vector<autofill::AutofillProfile*> contact_profiles_;
  autofill::AutofillProfile* selected_contact_profile_;

  // Credit cards returnd by the Data Manager may change due to (e.g.)
  // sync events, meaning PaymentRequest may outlive them. Therefore, credit
  // cards are fetched once and their copies are cached here. Whenever credit
  // cards are requested a vector of pointers to these copies are returned.
  std::vector<std::unique_ptr<autofill::CreditCard>> credit_card_cache_;

  std::vector<autofill::CreditCard*> credit_cards_;
  autofill::CreditCard* selected_credit_card_;

  // A vector of supported basic card networks. This encompasses everything that
  // the merchant supports and should be used for support checks.
  std::vector<std::string> supported_card_networks_;
  // A subset of |supported_card_networks_| which is only the networks that have
  // been specified as part of the "basic-card" supported method. Callers should
  // use |supported_card_networks_| for merchant support checks.
  std::set<std::string> basic_card_specified_networks_;

  // A vector of pointers to the shipping options in |web_payment_request_|.
  std::vector<web::PaymentShippingOption*> shipping_options_;
  web::PaymentShippingOption* selected_shipping_option_;

  payments::PaymentsProfileComparator profile_comparator_;

  DISALLOW_COPY_AND_ASSIGN(PaymentRequest);
};

#endif  // IOS_CHROME_BROWSER_PAYMENTS_PAYMENT_REQUEST_H_
