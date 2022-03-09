// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

struct PopupView: View {
  enum Dimensions {
    static let matchListRowInsets = EdgeInsets(.zero)
  }

  @ObservedObject var model: PopupModel
  var body: some View {
    VStack {
      List {
        ForEach(Array(zip(model.matches.indices, model.matches)), id: \.0) {
          sectionIndex, section in

          let sectionContents =
            ForEach(Array(zip(section.matches.indices, section.matches)), id: \.0) {
              matchIndex, match in
              PopupMatchRowView(
                match: match,
                isHighlighted: IndexPath(row: matchIndex, section: sectionIndex)
                  == self.model.highlightedMatchIndexPath,

                selectionHandler: {
                  model.delegate?.autocompleteResultConsumer(
                    model, didSelectRow: UInt(matchIndex), inSection: UInt(sectionIndex))
                },
                trailingButtonHandler: {
                  model.delegate?.autocompleteResultConsumer(
                    model, didTapTrailingButtonForRow: UInt(matchIndex),
                    inSection: UInt(sectionIndex))
                }

              )
              .deleteDisabled(!match.supportsDeletion)
              .listRowInsets(Dimensions.matchListRowInsets)
            }
            .onDelete { indexSet in
              for matchIndex in indexSet {
                model.delegate?.autocompleteResultConsumer(
                  model, didSelectRowForDeletion: UInt(matchIndex), inSection: UInt(sectionIndex))
              }
            }

          // Split the suggestions into sections, but only add a header text if the header isn't empty
          if !model.matches[sectionIndex].header.isEmpty {
            Section(header: Text(model.matches[sectionIndex].header)) {
              sectionContents
            }
          } else {
            Section {
              sectionContents
            }
          }

        }
      }
    }
  }

}

struct PopupView_Previews: PreviewProvider {
  static var previews: some View {
    PopupView(
      model: PopupModel(
        matches: [PopupMatch.previews], headers: ["Suggestions"], delegate: nil))
  }
}
