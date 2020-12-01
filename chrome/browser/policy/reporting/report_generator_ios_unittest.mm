// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/policy/reporting/report_generator_ios.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#include <vector>

#include "base/files/file_path.h"
#include "base/run_loop.h"
#include "base/test/bind.h"
#include "base/test/metrics/histogram_tester.h"
#include "components/policy/core/common/cloud/cloud_policy_util.h"
#include "components/policy/core/common/mock_policy_service.h"
#include "components/policy/core/common/policy_map.h"
#include "components/policy/core/common/schema_registry.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state_manager.h"
#import "ios/chrome/browser/policy/browser_state_policy_connector_mock.h"
#include "ios/chrome/browser/policy/reporting/reporting_delegate_factory_ios.h"
#include "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/signin/authentication_service_fake.h"
#include "ios/chrome/test/ios_chrome_scoped_testing_chrome_browser_state_manager.h"
#include "ios/web/public/test/web_task_environment.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/platform_test.h"

namespace em = enterprise_management;

namespace enterprise_reporting {

namespace {

const base::FilePath kProfilePath = base::FilePath("/fake/profile/default");

}  // namespace

class ReportGeneratorIOSTest : public PlatformTest {
 public:
  using ReportRequest = definition::ReportRequest;

  ReportGeneratorIOSTest() : generator_(&delegate_factory_) {
    TestChromeBrowserState::Builder builder;
    builder.SetPath(kProfilePath);
    builder.AddTestingFactory(
        AuthenticationServiceFactory::GetInstance(),
        base::BindRepeating(
            &AuthenticationServiceFake::CreateAuthenticationService));
    InitMockPolicyService();
    builder.SetPolicyConnector(
        std::make_unique<BrowserStatePolicyConnectorMock>(
            std::move(policy_service_), &schema_registry_));
    std::unique_ptr<TestChromeBrowserState> browser_state = builder.Build();

    InitPolicyMap();
    scoped_browser_state_manager_ =
        std::make_unique<IOSChromeScopedTestingChromeBrowserStateManager>(
            std::make_unique<TestChromeBrowserStateManager>(
                std::move(browser_state)));
  }

  ReportGeneratorIOSTest(const ReportGeneratorIOSTest&) = delete;
  ReportGeneratorIOSTest& operator=(const ReportGeneratorIOSTest&) = delete;
  ~ReportGeneratorIOSTest() override = default;

  void InitMockPolicyService() {
    policy_service_ = std::make_unique<policy::MockPolicyService>();

    ON_CALL(*policy_service_.get(),
            GetPolicies(::testing::Eq(policy::PolicyNamespace(
                policy::POLICY_DOMAIN_CHROME, std::string()))))
        .WillByDefault(::testing::ReturnRef(policy_map_));
  }

  void InitPolicyMap() {
    policy_map_.Set("kPolicyName1", policy::POLICY_LEVEL_MANDATORY,
                    policy::POLICY_SCOPE_USER, policy::POLICY_SOURCE_CLOUD,
                    base::Value(std::vector<base::Value>()), nullptr);
    policy_map_.Set("kPolicyName2", policy::POLICY_LEVEL_RECOMMENDED,
                    policy::POLICY_SCOPE_MACHINE, policy::POLICY_SOURCE_MERGED,
                    base::Value(true), nullptr);
  }


  std::vector<std::unique_ptr<ReportRequest>> GenerateRequests() {
    histogram_tester_ = std::make_unique<base::HistogramTester>();
    base::RunLoop run_loop;
    std::vector<std::unique_ptr<ReportRequest>> reqs;
    generator_.Generate(
        ReportType::kFull,
        base::BindLambdaForTesting(
            [&run_loop, &reqs](ReportGenerator::ReportRequests requests) {
              while (!requests.empty()) {
                reqs.push_back(std::move(requests.front()));
                requests.pop();
              }
              run_loop.Quit();
            }));
    run_loop.Run();
    VerifyMetrics(reqs);
    return reqs;
  }

  void VerifyMetrics(std::vector<std::unique_ptr<ReportRequest>>& rets) {
    histogram_tester_->ExpectUniqueSample(
        "Enterprise.CloudReportingRequestCount", rets.size(), 1);
    histogram_tester_->ExpectUniqueSample(
        "Enterprise.CloudReportingBasicRequestSize",
        /*basic request size floor to KB*/ 0, 1);
  }

 private:
  web::WebTaskEnvironment task_environment_;

  ReportingDelegateFactoryIOS delegate_factory_;
  ReportGenerator generator_;

  std::unique_ptr<base::HistogramTester> histogram_tester_;

  std::unique_ptr<policy::MockPolicyService> policy_service_;
  policy::SchemaRegistry schema_registry_;
  policy::PolicyMap policy_map_;

  std::unique_ptr<IOSChromeScopedTestingChromeBrowserStateManager>
      scoped_browser_state_manager_;
};

TEST_F(ReportGeneratorIOSTest, GenerateBasicReport) {
  auto requests = GenerateRequests();
  EXPECT_EQ(1u, requests.size());

  // Verify the basic request
  auto* basic_request = requests[0].get();

  EXPECT_NE(std::string(), basic_request->computer_name());
  EXPECT_EQ(std::string(), basic_request->serial_number());
  EXPECT_EQ(
      policy::GetBrowserDeviceIdentifier()->SerializePartialAsString(),
      basic_request->browser_device_identifier().SerializePartialAsString());
  EXPECT_NE(std::string(), basic_request->device_model());

  // Verify the OS report
  EXPECT_TRUE(basic_request->has_os_report());
  auto& os_report = basic_request->os_report();
  EXPECT_NE(std::string(), os_report.name());
  EXPECT_NE(std::string(), os_report.arch());
  EXPECT_NE(std::string(), os_report.version());

  // Ensure there are no partial reports
  EXPECT_EQ(0, basic_request->partial_report_types_size());

  // Verify the browser report
  EXPECT_TRUE(basic_request->has_browser_report());
  auto& browser_report = basic_request->browser_report();
  EXPECT_NE(std::string(), browser_report.browser_version());
  EXPECT_TRUE(browser_report.has_channel());
  EXPECT_NE(std::string(), browser_report.executable_path());

  // Verify the profile report
  EXPECT_EQ(1, browser_report.chrome_user_profile_infos_size());
  auto profile_info = browser_report.chrome_user_profile_infos(0);
  EXPECT_EQ(kProfilePath.AsUTF8Unsafe(), profile_info.id());
  EXPECT_EQ(kProfilePath.BaseName().AsUTF8Unsafe(), profile_info.name());
  EXPECT_TRUE(profile_info.has_is_detail_available());
  EXPECT_TRUE(profile_info.is_detail_available());
  EXPECT_EQ(2, profile_info.chrome_policies_size());
}

}  // namespace enterprise_reporting
