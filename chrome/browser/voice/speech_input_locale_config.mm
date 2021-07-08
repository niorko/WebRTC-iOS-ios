// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/voice/speech_input_locale_config.h"

#include "ios/chrome/browser/voice/speech_input_locale_config_impl.h"
#include "ios/chrome/browser/voice/speech_input_locale_match.h"
#include "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#include "ios/public/provider/chrome/browser/voice/voice_search_provider.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace voice {

// static
SpeechInputLocaleConfig* SpeechInputLocaleConfig::GetInstance() {
  static base::NoDestructor<SpeechInputLocaleConfigImpl> instance(
      ios::GetChromeBrowserProvider()
          .GetVoiceSearchProvider()
          ->GetAvailableLanguages(),
      LoadSpeechInputLocaleMatches());
  return instance.get();
}

}  // namespace voice
