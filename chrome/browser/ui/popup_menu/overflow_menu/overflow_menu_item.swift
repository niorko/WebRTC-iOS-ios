// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

/// Represents an item in the overflow menu.
@objcMembers public class OverflowMenuItem: NSObject, ObservableObject {
  /// The user-visible name of the item.
  public let name: String

  /// The name of the image used to load the image for SwiftUI.
  public let imageName: String

  /// The SwiftUI `Image` for the action icon.
  public var image: Image {
    return Image(imageName)
  }

  /// Closure to execute when item is selected.
  public var handler: () -> Void

  /// Whether thte action is dsabled by enterprise policy.
  @Published public var enterpriseDisabled: Bool

  public init(
    name: String, imageName: String, enterpriseDisabled: Bool, handler: @escaping () -> Void
  ) {
    self.name = name
    self.imageName = imageName
    self.enterpriseDisabled = enterpriseDisabled
    self.handler = handler
  }
}

// MARK: - Identifiable

extension OverflowMenuItem: Identifiable {
  public var id: String {
    return name
  }
}
