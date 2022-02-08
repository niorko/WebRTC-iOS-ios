// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

@objcMembers class PopupModel: NSObject, ObservableObject {
  @Published var matches: [PopupMatch]
  var buttonHandler: () -> Void

  init(matches: [PopupMatch], buttonHandler: @escaping () -> Void) {
    self.matches = matches
    self.buttonHandler = buttonHandler
  }
}
