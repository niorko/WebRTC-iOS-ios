// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import UIKit

// UIHostingController subclass for the overflow menu. Mostly used to set
// preferredContentSize in compact height environments.
class OverflowMenuHostingController<Content>: UIHostingController<Content> where Content: View {
  // This should be the width of the share sheet in compact height environments.
  let compactHeightSheetWidth: CGFloat = 568

  var compactHeightPreferredContentSize: CGSize {
    return CGSize(
      width: compactHeightSheetWidth, height: presentingViewController?.view.bounds.size.height ?? 0
    )
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Only set the preferredContentSize in height == compact because otherwise
    // it overrides the default size of the menu on iPad.
    preferredContentSize =
      traitCollection.verticalSizeClass == .compact ? compactHeightPreferredContentSize : .zero
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    // Only set the preferredContentSize in height == compact because otherwise
    // it overrides the default size of the menu on iPad.
    preferredContentSize =
      traitCollection.verticalSizeClass == .compact ? compactHeightPreferredContentSize : .zero
  }
}
