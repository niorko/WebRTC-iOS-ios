// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/autofill/autofill_profile_edit_mediator.h"

#import "base/strings/sys_string_conversions.h"
#import "base/test/scoped_feature_list.h"
#import "components/autofill/core/browser/autofill_test_utils.h"
#import "components/autofill/core/browser/personal_data_manager.h"
#import "components/autofill/core/common/autofill_features.h"
#import "ios/chrome/browser/autofill/personal_data_manager_factory.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/browser/ui/settings/autofill/autofill_profile_edit_consumer.h"
#import "ios/chrome/browser/ui/settings/autofill/autofill_profile_edit_mediator_delegate.h"
#import "ios/chrome/browser/ui/settings/autofill/cells/country_item.h"
#import "ios/chrome/browser/ui/settings/personal_data_manager_finished_profile_tasks_waiter.h"
#import "ios/chrome/browser/webdata_services/web_data_service_factory.h"
#import "ios/chrome/test/ios_chrome_scoped_testing_local_state.h"
#import "ios/web/public/test/web_task_environment.h"
#import "testing/gtest_mac.h"
#import "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

typedef NS_ENUM(NSInteger, ItemType) {
  ItemTypeCountry = kItemTypeEnumZero,
};

}  // namespace

@interface FakeAutofillProfileEditConsumer
    : NSObject <AutofillProfileEditConsumer>
// If YES, denote that the particular field requires a value.
@property(nonatomic, assign) BOOL line1Required;
@property(nonatomic, assign) BOOL cityRequired;
@property(nonatomic, assign) BOOL stateRequired;
@property(nonatomic, assign) BOOL zipRequired;

// Stores the value displayed in the fields.
@property(nonatomic, assign) NSString* honorificPrefix;
@property(nonatomic, assign) NSString* companyName;
@property(nonatomic, assign) NSString* fullName;
@property(nonatomic, assign) NSString* homeAddressLine1;
@property(nonatomic, assign) NSString* homeAddressLine2;
@property(nonatomic, assign) NSString* homeAddressCity;
@property(nonatomic, assign) NSString* homeAddressState;
@property(nonatomic, assign) NSString* homeAddressZip;
@property(nonatomic, assign) NSString* homeAddressCountry;
@property(nonatomic, assign) NSString* homePhoneWholeNumber;
@property(nonatomic, assign) NSString* emailAddress;

// YES, if the profile's source is autofill::AutofillProfile::Source::kAccount.
@property(nonatomic, assign) BOOL accountProfile;

@property(nonatomic, assign) NSString* countrySelected;
@end

@implementation FakeAutofillProfileEditConsumer

- (void)didSelectCountry:(NSString*)country {
  self.countrySelected = country;
}

@end

class AutofillProfileEditMediatorTest : public PlatformTest {
 protected:
  AutofillProfileEditMediatorTest() {
    TestChromeBrowserState::Builder test_cbs_builder;
    // Profile edit requires a PersonalDataManager which itself needs the
    // WebDataService; this is not initialized on a TestChromeBrowserState by
    // default.
    test_cbs_builder.AddTestingFactory(
        ios::WebDataServiceFactory::GetInstance(),
        ios::WebDataServiceFactory::GetDefaultFactory());
    chrome_browser_state_ = test_cbs_builder.Build();
    personal_data_manager_ =
        autofill::PersonalDataManagerFactory::GetForBrowserState(
            chrome_browser_state_.get());
    personal_data_manager_->OnSyncServiceInitialized(nullptr);

    if (base::FeatureList::IsEnabled(
            autofill::features::kAutofillUseAlternativeStateNameMap)) {
      personal_data_manager_->personal_data_manager_cleaner_for_testing()
          ->alternative_state_name_map_updater_for_testing()
          ->set_local_state_for_testing(local_state_.Get());
    }

    autofill::AutofillProfile autofill_profile;

    autofill_profile_edit_mediator_delegate_mock_ =
        OCMProtocolMock(@protocol(AutofillProfileEditMediatorDelegate));

    autofill_profile_edit_mediator_ = [[AutofillProfileEditMediator alloc]
           initWithDelegate:autofill_profile_edit_mediator_delegate_mock_
        personalDataManager:personal_data_manager_
            autofillProfile:&autofill_profile
                countryCode:@"US"];
    fake_consumer_ = [[FakeAutofillProfileEditConsumer alloc] init];
    autofill_profile_edit_mediator_.consumer = fake_consumer_;
  }

  AutofillProfileEditMediator* autofill_profile_edit_mediator_;
  FakeAutofillProfileEditConsumer* fake_consumer_;

 private:
  web::WebTaskEnvironment task_environment_;
  IOSChromeScopedTestingLocalState local_state_;
  std::unique_ptr<TestChromeBrowserState> chrome_browser_state_;
  autofill::PersonalDataManager* personal_data_manager_;
  id autofill_profile_edit_mediator_delegate_mock_;
};

// Tests that the consumer is initialised and informed of the required fields on
// initialisation.
TEST_F(AutofillProfileEditMediatorTest, TestRequiredFieldsOnInitialisation) {
  EXPECT_TRUE([fake_consumer_ line1Required]);
  EXPECT_TRUE([fake_consumer_ cityRequired]);
  EXPECT_TRUE([fake_consumer_ stateRequired]);
  EXPECT_TRUE([fake_consumer_ zipRequired]);
}

// Tests that the consumer is informed of the required fields on country
// selection.
TEST_F(AutofillProfileEditMediatorTest, TestRequiredFieldsOnCountrySelection) {
  CountryItem* countryItem = [[CountryItem alloc] initWithType:ItemTypeCountry];
  countryItem.text = @"Germany";
  countryItem.countryCode = @"DE";
  [autofill_profile_edit_mediator_ didSelectCountry:countryItem];
  EXPECT_TRUE([fake_consumer_ line1Required]);
  EXPECT_TRUE([fake_consumer_ cityRequired]);
  EXPECT_FALSE([fake_consumer_ stateRequired]);
  EXPECT_TRUE([fake_consumer_ zipRequired]);
  EXPECT_NSEQ([fake_consumer_ countrySelected], @"Germany");
}
