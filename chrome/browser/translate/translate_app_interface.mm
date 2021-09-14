// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/translate/translate_app_interface.h"

#include "base/command_line.h"
#include "base/memory/singleton.h"
#include "base/strings/sys_string_conversions.h"
#include "base/strings/utf_string_conversions.h"
#include "components/translate/core/browser/translate_infobar_delegate.h"
#include "components/translate/core/browser/translate_manager.h"
#include "components/translate/core/browser/translate_prefs.h"
#include "components/translate/core/common/language_detection_details.h"
#include "components/translate/core/common/translate_switches.h"
#import "components/translate/ios/browser/js_translate_manager.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/translate/chrome_ios_translate_client.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#import "ios/chrome/test/app/tab_test_util.h"
#import "ios/chrome/test/fakes/fake_language_detection_tab_helper_observer.h"
#import "ios/web/public/js_messaging/web_frame.h"
#import "ios/web/public/js_messaging/web_frame_util.h"
#include "net/base/network_change_notifier.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Simulates a given network connection type for tests.
// TODO(crbug.com/938598): Refactor this and similar net::NetworkChangeNotifier
// subclasses for testing into a separate file.
class FakeNetworkChangeNotifier : public net::NetworkChangeNotifier {
 public:
  FakeNetworkChangeNotifier(
      net::NetworkChangeNotifier::ConnectionType connection_type_to_return)
      : connection_type_to_return_(connection_type_to_return) {}

 private:
  ConnectionType GetCurrentConnectionType() const override {
    return connection_type_to_return_;
  }

  // The currently simulated network connection type. If this is set to
  // CONNECTION_NONE, then NetworkChangeNotifier::IsOffline will return true.
  net::NetworkChangeNotifier::ConnectionType connection_type_to_return_ =
      net::NetworkChangeNotifier::CONNECTION_UNKNOWN;

  DISALLOW_COPY_AND_ASSIGN(FakeNetworkChangeNotifier);
};

// Helper singleton object to hold states for fake objects to facility testing.
class TranslateAppInterfaceHelper {
 public:
  static TranslateAppInterfaceHelper* GetInstance() {
    return base::Singleton<TranslateAppInterfaceHelper>::get();
  }

  FakeLanguageDetectionTabHelperObserver& tab_helper_observer() const {
    return *tab_helper_observer_;
  }
  void set_tab_helper_observer(
      std::unique_ptr<FakeLanguageDetectionTabHelperObserver> observer) {
    tab_helper_observer_ = std::move(observer);
  }

  void SetUpFakeWiFiConnection() {
    // Disables the net::NetworkChangeNotifier singleton and replace it with a
    // FakeNetworkChangeNotifier to simulate a WIFI network connection.
    network_change_notifier_disabler_ =
        std::make_unique<net::NetworkChangeNotifier::DisableForTest>();
    network_change_notifier_ = std::make_unique<FakeNetworkChangeNotifier>(
        net::NetworkChangeNotifier::CONNECTION_WIFI);
  }
  void TearDownFakeWiFiConnection() {
    // Note: Tears down in the opposite order of construction.
    network_change_notifier_.reset();
    network_change_notifier_disabler_.reset();
  }

 private:
  TranslateAppInterfaceHelper() {}
  ~TranslateAppInterfaceHelper() = default;
  friend struct base::DefaultSingletonTraits<TranslateAppInterfaceHelper>;

  // Observes the language detection tab helper and captures the translation
  // details for inspection by tests.
  std::unique_ptr<FakeLanguageDetectionTabHelperObserver> tab_helper_observer_;
  // Helps fake the network condition for tests.
  std::unique_ptr<net::NetworkChangeNotifier::DisableForTest>
      network_change_notifier_disabler_;
  std::unique_ptr<FakeNetworkChangeNotifier> network_change_notifier_;
};

}  // namespace

#pragma mark - FakeJSTranslateManager

// Fake translate manager to be used in tests so no network is needed.
// Translating the page just adds a 'Translated' button to the page, without
// changing the text.
@interface FakeJSTranslateManager : JsTranslateManager {
  web::WebState* _webState;
}

- (instancetype)initWithWebState:(web::WebState*)webState;

@end

@implementation FakeJSTranslateManager

- (instancetype)initWithWebState:(web::WebState*)webState {
  if ((self = [super initWithWebState:webState])) {
    _webState = webState;
  }
  return self;
}

- (void)startTranslationFrom:(const std::string&)source
                          to:(const std::string&)target {
  // Add a button with the 'Translated' label to the web page.
  // The test can check it to determine if this method has been called.
  _webState->ExecuteJavaScript(
      u"myButton = document.createElement('button');"
      u"myButton.setAttribute('id', 'translated-button');"
      u"myButton.appendChild(document.createTextNode('Translated'));"
      u"document.body.prepend(myButton);");
}

- (void)revertTranslation {
  // Removes the button with 'translated-button' id from the web page, if any.
  _webState->ExecuteJavaScript(
      u"myButton = document.getElementById('translated-button');"
      u"myButton.remove();");
}

- (void)injectWithTranslateScript:(const std::string&)translate_script {
  // No need to set the |translate_script| JavaScript since it will never be
  // used by this fake object. Instead just invoke host with 'translate.ready'
  // followed by 'translate.status'.
  base::Value translate_ready_dict(base::Value::Type::DICTIONARY);
  translate_ready_dict.SetKey("command", base::Value("translate.ready"));
  translate_ready_dict.SetKey("errorCode", base::Value(0));
  translate_ready_dict.SetKey("loadTime", base::Value(0));
  translate_ready_dict.SetKey("readyTime", base::Value(0));

  std::vector<base::Value> translate_ready_params;
  translate_ready_params.push_back(std::move(translate_ready_dict));
  GetMainFrame(_webState)->CallJavaScriptFunction("message.invokeOnHost",
                                                  translate_ready_params);

  base::Value translate_status_dict(base::Value::Type::DICTIONARY);
  translate_status_dict.SetKey("command", base::Value("translate.status"));
  translate_status_dict.SetKey("errorCode", base::Value(0));
  translate_status_dict.SetKey("pageSourceLanguage", base::Value("fr"));
  translate_status_dict.SetKey("translationTime", base::Value(0));

  std::vector<base::Value> translate_status_params;
  translate_status_params.push_back(std::move(translate_status_dict));
  GetMainFrame(_webState)->CallJavaScriptFunction("message.invokeOnHost",
                                                  translate_status_params);
}

@end

#pragma mark - TranslateAppInterface

@implementation TranslateAppInterface

#pragma mark public methods

+ (void)setUpWithScriptServer:(NSString*)translateScriptServerURL {
  // Allows the offering of translate in builds without an API key.
  translate::TranslateManager::SetIgnoreMissingKeyForTesting(true);
  [self setUpLanguageDetectionTabHelperObserver];
  [self setDefaultTranslatePrefs];
  // Sets up a fake JsTranslateManager that does not use the translate script.
  [self setUpFakeJSTranslateManagerInCurrentTab];
  TranslateAppInterfaceHelper::GetInstance()->SetUpFakeWiFiConnection();

  // Sets URL for the translate script to hit a HTTP server selected by
  // the test app
  base::CommandLine* command_line = base::CommandLine::ForCurrentProcess();
  command_line->AppendSwitchASCII(
      translate::switches::kTranslateScriptURL,
      base::SysNSStringToUTF8(translateScriptServerURL));
}

+ (void)tearDown {
  TranslateAppInterfaceHelper::GetInstance()->TearDownFakeWiFiConnection();
  [self setDefaultTranslatePrefs];
  [TranslateAppInterface tearDownLanguageDetectionTabHelperObserver];
  // Stops allowing the offering of translate in builds without an API key.
  translate::TranslateManager::SetIgnoreMissingKeyForTesting(false);
}

+ (void)setUpLanguageDetectionTabHelperObserver {
  TranslateAppInterfaceHelper::GetInstance()->set_tab_helper_observer(
      std::make_unique<FakeLanguageDetectionTabHelperObserver>(
          chrome_test_util::GetCurrentWebState()));
}

+ (void)tearDownLanguageDetectionTabHelperObserver {
  TranslateAppInterfaceHelper::GetInstance()->set_tab_helper_observer(nullptr);
}

+ (void)resetLanguageDetectionTabHelperObserver {
  TranslateAppInterfaceHelper::GetInstance()
      ->tab_helper_observer()
      .ResetLanguageDetectionDetails();
}

+ (BOOL)isLanguageDetected {
  return TranslateAppInterfaceHelper::GetInstance()
             ->tab_helper_observer()
             .GetLanguageDetectionDetails() != nullptr;
}

+ (NSString*)contentLanguage {
  translate::LanguageDetectionDetails* details =
      TranslateAppInterfaceHelper::GetInstance()
          ->tab_helper_observer()
          .GetLanguageDetectionDetails();
  return base::SysUTF8ToNSString(details->content_language);
}

+ (NSString*)htmlRootLanguage {
  translate::LanguageDetectionDetails* details =
      TranslateAppInterfaceHelper::GetInstance()
          ->tab_helper_observer()
          .GetLanguageDetectionDetails();
  return base::SysUTF8ToNSString(details->html_root_language);
}

+ (NSString*)adoptedLanguage {
  translate::LanguageDetectionDetails* details =
      TranslateAppInterfaceHelper::GetInstance()
          ->tab_helper_observer()
          .GetLanguageDetectionDetails();
  return base::SysUTF8ToNSString(details->adopted_language);
}

+ (void)setUpFakeJSTranslateManagerInCurrentTab {
  ChromeIOSTranslateClient* client = ChromeIOSTranslateClient::FromWebState(
      chrome_test_util::GetCurrentWebState());
  translate::IOSTranslateDriver* driver =
      static_cast<translate::IOSTranslateDriver*>(client->GetTranslateDriver());
  FakeJSTranslateManager* fakeJSTranslateManager =
      [[FakeJSTranslateManager alloc]
          initWithWebState:chrome_test_util::GetCurrentWebState()];
  driver->translate_controller()->SetJsTranslateManagerForTesting(
      fakeJSTranslateManager);
}

+ (BOOL)shouldAutoTranslateFromLanguage:(NSString*)source
                             toLanguage:(NSString*)target {
  std::unique_ptr<translate::TranslatePrefs> prefs(
      ChromeIOSTranslateClient::CreateTranslatePrefs(
          chrome_test_util::GetOriginalBrowserState()->GetPrefs()));
  return prefs->IsLanguagePairOnAlwaysTranslateList(
      base::SysNSStringToUTF8(source), base::SysNSStringToUTF8(target));
}

+ (BOOL)isBlockedLanguage:(NSString*)language {
  std::unique_ptr<translate::TranslatePrefs> prefs(
      ChromeIOSTranslateClient::CreateTranslatePrefs(
          chrome_test_util::GetOriginalBrowserState()->GetPrefs()));
  return prefs->IsBlockedLanguage(base::SysNSStringToUTF8(language));
}

+ (BOOL)isBlockedSite:(NSString*)hostName {
  std::unique_ptr<translate::TranslatePrefs> prefs(
      ChromeIOSTranslateClient::CreateTranslatePrefs(
          chrome_test_util::GetOriginalBrowserState()->GetPrefs()));
  return prefs->IsSiteOnNeverPromptList(base::SysNSStringToUTF8(hostName));
}

+ (int)infobarAutoAlwaysThreshold {
  return translate::TranslateInfoBarDelegate::GetAutoAlwaysThreshold();
}

+ (int)infobarAutoNeverThreshold {
  return translate::TranslateInfoBarDelegate::GetAutoNeverThreshold();
}

+ (int)infobarMaximumNumberOfAutoAlways {
  return translate::TranslateInfoBarDelegate::GetMaximumNumberOfAutoAlways();
}

+ (int)infobarMaximumNumberOfAutoNever {
  return translate::TranslateInfoBarDelegate::GetMaximumNumberOfAutoNever();
}

#pragma mark private methods

// Reset translate prefs to default.
+ (void)setDefaultTranslatePrefs {
  std::unique_ptr<translate::TranslatePrefs> prefs(
      ChromeIOSTranslateClient::CreateTranslatePrefs(
          chrome_test_util::GetOriginalBrowserState()->GetPrefs()));
  prefs->ResetToDefaults();
}

@end
