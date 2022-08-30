// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/autocomplete/omnibox_pedal_implementation.h"

#include "components/omnibox/browser/actions/omnibox_pedal.h"
#include "components/omnibox/browser/autocomplete_input.h"
#include "components/omnibox/browser/autocomplete_provider_client.h"
#include "components/omnibox/browser/buildflags.h"
#include "components/omnibox/browser/omnibox_client.h"
#include "components/omnibox/browser/omnibox_field_trial.h"
#include "components/omnibox/common/omnibox_features.h"
#include "components/omnibox/resources/grit/omnibox_pedal_synonyms.h"
#include "components/prefs/pref_service.h"
#include "components/strings/grit/components_strings.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// =============================================================================

class OmniboxPedalClearBrowsingData : public OmniboxPedal {
 public:
  explicit OmniboxPedalClearBrowsingData(bool incognito)
      : OmniboxPedal(
            OmniboxPedalId::CLEAR_BROWSING_DATA,
            LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_CLEAR_BROWSING_DATA_HINT,
                IDS_OMNIBOX_PEDAL_CLEAR_BROWSING_DATA_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_CLEAR_BROWSING_DATA_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_CLEAR_BROWSING_DATA),
            GURL()),
        incognito_(incognito) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    // Note about translation strings: English preserves original separated
    // synonym group structure, but these strings are not translated (grit
    // message sets translateable=false). Non-English uses simplified whole
    // phrase trigger lists, and this string is translated.
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_CLEAR_BROWSING_DATA_ONE_OPTIONAL_GOOGLE_CHROME
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_CLEAR_BROWSING_DATA_ONE_OPTIONAL_GOOGLE_CHROME,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_CLEAR_BROWSING_DATA_ONE_REQUIRED_DELETE,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_CLEAR_BROWSING_DATA_ONE_REQUIRED_INFORMATION,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_CLEAR_BROWSING_DATA_ONE_REQUIRED_CLEAR_BROWSER_CACHE
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_CLEAR_BROWSING_DATA_ONE_REQUIRED_CLEAR_BROWSER_CACHE,
          },
#endif
      };
    }
  }

  // This method override enables this Pedal to spoof its ID for metrics
  // reporting, making it possible to distinguish incognito usage.
  OmniboxPedalId GetMetricsId() const override {
    return incognito_ ? OmniboxPedalId::INCOGNITO_CLEAR_BROWSING_DATA : id();
  }

 protected:
  ~OmniboxPedalClearBrowsingData() override = default;
  bool incognito_;
};

// =============================================================================

class OmniboxPedalManagePasswords : public OmniboxPedal {
 public:
  OmniboxPedalManagePasswords()
      : OmniboxPedal(
            OmniboxPedalId::MANAGE_PASSWORDS,
            LabelStrings(IDS_IOS_OMNIBOX_PEDAL_MANAGE_PASSWORDS_HINT,
                         IDS_OMNIBOX_PEDAL_MANAGE_PASSWORDS_SUGGESTION_CONTENTS,
                         IDS_ACC_OMNIBOX_PEDAL_MANAGE_PASSWORDS_SUFFIX,
                         IDS_ACC_OMNIBOX_PEDAL_MANAGE_PASSWORDS),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_PASSWORDS_ONE_OPTIONAL_GOOGLE_CHROME
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_PASSWORDS_ONE_OPTIONAL_GOOGLE_CHROME,
          },
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_PASSWORDS_ONE_OPTIONAL_MANAGER,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_PASSWORDS_ONE_REQUIRED_PASSWORDS,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_PASSWORDS_ONE_REQUIRED_MANAGE_CHROME_PASSWORDS
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_PASSWORDS_ONE_REQUIRED_MANAGE_CHROME_PASSWORDS,
          },
#endif
      };
    }
  }

 protected:
  ~OmniboxPedalManagePasswords() override = default;
};

// =============================================================================

class OmniboxPedalSetChromeAsDefaultBrowser : public OmniboxPedal {
 public:
  explicit OmniboxPedalSetChromeAsDefaultBrowser()
      : OmniboxPedal(
            OmniboxPedalId::SET_CHROME_AS_DEFAULT_BROWSER,
            LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_SET_CHROME_AS_DEFAULT_BROWSER_HINT,
                IDS_OMNIBOX_PEDAL_SET_CHROME_AS_DEFAULT_BROWSER_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_SET_CHROME_AS_DEFAULT_BROWSER_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_SET_CHROME_AS_DEFAULT_BROWSER),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_SET_CHROME_AS_DEFAULT_BROWSER_ONE_REQUIRED_HOW_TO_MAKE_CHROME_MY_DEFAULT_BROWSER
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_SET_CHROME_AS_DEFAULT_BROWSER_ONE_REQUIRED_HOW_TO_MAKE_CHROME_MY_DEFAULT_BROWSER,
          },
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_SET_CHROME_AS_DEFAULT_BROWSER_ONE_OPTIONAL_SELECT,
          },
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_SET_CHROME_AS_DEFAULT_BROWSER_ONE_OPTIONAL_DEFAULT_BROWSER,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_SET_CHROME_AS_DEFAULT_BROWSER_ONE_REQUIRED_ALWAYS_OPEN_LINKS_IN_CHROME
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_SET_CHROME_AS_DEFAULT_BROWSER_ONE_REQUIRED_ALWAYS_OPEN_LINKS_IN_CHROME,
          },
#endif
      };
    }
  }

 protected:
  ~OmniboxPedalSetChromeAsDefaultBrowser() override = default;
};

// =============================================================================

class OmniboxPedalUpdateCreditCard : public OmniboxPedal {
 public:
  OmniboxPedalUpdateCreditCard()
      : OmniboxPedal(
            OmniboxPedalId::UPDATE_CREDIT_CARD,
            LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_UPDATE_CREDIT_CARD_HINT,
                IDS_OMNIBOX_PEDAL_UPDATE_CREDIT_CARD_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_UPDATE_CREDIT_CARD_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_UPDATE_CREDIT_CARD),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_UPDATE_CREDIT_CARD_ONE_OPTIONAL_GOOGLE_CHROME
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_UPDATE_CREDIT_CARD_ONE_OPTIONAL_GOOGLE_CHROME,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_UPDATE_CREDIT_CARD_ONE_REQUIRED_CHANGE,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_UPDATE_CREDIT_CARD_ONE_REQUIRED_CREDIT_CARD_INFORMATION,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_UPDATE_CREDIT_CARD_ONE_REQUIRED_MANAGE_PAYMENT_METHODS
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_UPDATE_CREDIT_CARD_ONE_REQUIRED_MANAGE_PAYMENT_METHODS,
          },
#endif
      };
    }
  }

 protected:
  ~OmniboxPedalUpdateCreditCard() override = default;
};

// =============================================================================

class OmniboxPedalLaunchIncognito : public OmniboxPedal {
 public:
  OmniboxPedalLaunchIncognito()
      : OmniboxPedal(
            OmniboxPedalId::LAUNCH_INCOGNITO,
            LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_LAUNCH_INCOGNITO_HINT,
                IDS_IOS_OMNIBOX_PEDAL_LAUNCH_INCOGNITO_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_LAUNCH_INCOGNITO_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_LAUNCH_INCOGNITO),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_LAUNCH_INCOGNITO_ONE_OPTIONAL_GOOGLE_CHROME
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_LAUNCH_INCOGNITO_ONE_OPTIONAL_GOOGLE_CHROME,
          },
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_LAUNCH_INCOGNITO_ONE_OPTIONAL_CREATE,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_LAUNCH_INCOGNITO_ONE_REQUIRED_INCOGNITO_WINDOW,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_LAUNCH_INCOGNITO_ONE_REQUIRED_ENTER_INCOGNITO_MODE
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_LAUNCH_INCOGNITO_ONE_REQUIRED_ENTER_INCOGNITO_MODE,
          },
#endif
      };
    }
  }

  bool IsReadyToTrigger(
      const AutocompleteInput& input,
      const AutocompleteProviderClient& client) const override {
    return client.IsIncognitoModeAvailable();
  }

 protected:
  ~OmniboxPedalLaunchIncognito() override = default;
};

// =============================================================================

class OmniboxPedalRunChromeSafetyCheck : public OmniboxPedal {
 public:
  OmniboxPedalRunChromeSafetyCheck()
      : OmniboxPedal(
            OmniboxPedalId::RUN_CHROME_SAFETY_CHECK,
            OmniboxPedal::LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_RUN_CHROME_SAFETY_CHECK_HINT,
                IDS_OMNIBOX_PEDAL_RUN_CHROME_SAFETY_CHECK_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_RUN_CHROME_SAFETY_CHECK_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_RUN_CHROME_SAFETY_CHECK),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_RUN_CHROME_SAFETY_CHECK_ONE_OPTIONAL_ACTIVATE
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_RUN_CHROME_SAFETY_CHECK_ONE_OPTIONAL_ACTIVATE,
          },
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_RUN_CHROME_SAFETY_CHECK_ONE_OPTIONAL_GOOGLE_CHROME,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_RUN_CHROME_SAFETY_CHECK_ONE_REQUIRED_CHECKUP,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_RUN_CHROME_SAFETY_CHECK_ONE_REQUIRED_PASSWORDS,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_RUN_CHROME_SAFETY_CHECK_ONE_REQUIRED_RUN_CHROME_SAFETY_CHECK
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_RUN_CHROME_SAFETY_CHECK_ONE_REQUIRED_RUN_CHROME_SAFETY_CHECK,
          },
#endif
      };
    }
  }

 protected:
  ~OmniboxPedalRunChromeSafetyCheck() override = default;
};

// =============================================================================

class OmniboxPedalManageChromeSettings : public OmniboxPedal {
 public:
  OmniboxPedalManageChromeSettings()
      : OmniboxPedal(
            OmniboxPedalId::MANAGE_CHROME_SETTINGS,
            LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_MANAGE_CHROME_SETTINGS_HINT,
                IDS_OMNIBOX_PEDAL_MANAGE_CHROME_SETTINGS_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_MANAGE_CHROME_SETTINGS_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_MANAGE_CHROME_SETTINGS),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_CHROME_SETTINGS_ONE_OPTIONAL_CONTROL
          {
              false,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_CHROME_SETTINGS_ONE_OPTIONAL_CONTROL,
          },
          {true, true,
           IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_CHROME_SETTINGS_ONE_REQUIRED_CHROME_BROWSER_SETTINGS},
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_CHROME_SETTINGS_ONE_REQUIRED_CHANGE_CHROME_SETTINGS
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_MANAGE_CHROME_SETTINGS_ONE_REQUIRED_CHANGE_CHROME_SETTINGS,
          },
#endif
      };
    }
  }

 protected:
  ~OmniboxPedalManageChromeSettings() override = default;
};

// =============================================================================

class OmniboxPedalViewChromeHistory : public OmniboxPedal {
 public:
  OmniboxPedalViewChromeHistory()
      : OmniboxPedal(
            OmniboxPedalId::VIEW_CHROME_HISTORY,
            LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_VIEW_CHROME_HISTORY_HINT,
                IDS_OMNIBOX_PEDAL_VIEW_CHROME_HISTORY_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_VIEW_CHROME_HISTORY_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_VIEW_CHROME_HISTORY),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_VIEW_CHROME_HISTORY_ONE_REQUIRED_REVISIT
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_VIEW_CHROME_HISTORY_ONE_REQUIRED_REVISIT,
          },
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_VIEW_CHROME_HISTORY_ONE_REQUIRED_GOOGLE_CHROME_BROWSING_HISTORY,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_VIEW_CHROME_HISTORY_ONE_REQUIRED_SEE_CHROME_HISTORY
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_VIEW_CHROME_HISTORY_ONE_REQUIRED_SEE_CHROME_HISTORY,
          },
#endif
      };
    }
  }

 protected:
  ~OmniboxPedalViewChromeHistory() override = default;
};

// =============================================================================

class OmniboxPedalPlayChromeDinoGame : public OmniboxPedal {
 public:
  OmniboxPedalPlayChromeDinoGame()
      : OmniboxPedal(
            OmniboxPedalId::PLAY_CHROME_DINO_GAME,
            LabelStrings(
                IDS_IOS_OMNIBOX_PEDAL_PLAY_CHROME_DINO_GAME_HINT,
                IDS_OMNIBOX_PEDAL_PLAY_CHROME_DINO_GAME_SUGGESTION_CONTENTS,
                IDS_ACC_OMNIBOX_PEDAL_PLAY_CHROME_DINO_GAME_SUFFIX,
                IDS_ACC_OMNIBOX_PEDAL_PLAY_CHROME_DINO_GAME),
            GURL()) {}

  std::vector<SynonymGroupSpec> SpecifySynonymGroups(
      bool locale_is_english) const override {
    if (locale_is_english) {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_PLAY_CHROME_DINO_GAME_ONE_REQUIRED_PLAY_CHROME_DINO_GAME
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_PLAY_CHROME_DINO_GAME_ONE_REQUIRED_PLAY_CHROME_DINO_GAME,
          },
#endif
      };
    } else {
      return {
#ifdef IDS_OMNIBOX_PEDAL_SYNONYMS_PLAY_CHROME_DINO_GAME_ONE_REQUIRED_CHROME_DINO
          {
              true,
              true,
              IDS_OMNIBOX_PEDAL_SYNONYMS_PLAY_CHROME_DINO_GAME_ONE_REQUIRED_CHROME_DINO,
          },
#endif
      };
    }
  }

 protected:
  ~OmniboxPedalPlayChromeDinoGame() override = default;
};

// =============================================================================

std::unordered_map<OmniboxPedalId, scoped_refptr<OmniboxPedal>>
GetPedalImplementations(bool incognito, bool testing) {
  std::unordered_map<OmniboxPedalId, scoped_refptr<OmniboxPedal>> pedals;
  __unused const auto add = [&](OmniboxPedal* pedal) {
    pedals.insert(std::make_pair(pedal->id(), base::WrapRefCounted(pedal)));
  };

  if (!incognito) {
    add(new OmniboxPedalClearBrowsingData(incognito));
  }

  add(new OmniboxPedalManagePasswords());
  add(new OmniboxPedalSetChromeAsDefaultBrowser());
  add(new OmniboxPedalUpdateCreditCard());
  add(new OmniboxPedalLaunchIncognito());
  add(new OmniboxPedalRunChromeSafetyCheck());
  add(new OmniboxPedalManageChromeSettings());
  add(new OmniboxPedalViewChromeHistory());
  add(new OmniboxPedalPlayChromeDinoGame());

  return pedals;
}
