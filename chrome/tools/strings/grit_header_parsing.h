// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_TOOLS_STRINGS_GRIT_HEADER_PARSING_H_
#define IOS_CHROME_TOOLS_STRINGS_GRIT_HEADER_PARSING_H_

#include <map>
#include <string>
#include <vector>

#include "base/files/file_path.h"
#include "third_party/abseil-cpp/absl/types/optional.h"

// Type representing a mapping of resources identifier to their value
// as defined in the header generated by grit.
using ResourceMap = std::map<std::string, int, std::less<>>;

// Loads mapping of resources identifiers from headers generated by
// grit at paths specified in `headers`.
absl::optional<ResourceMap> LoadResourcesFromGritHeaders(
    const std::vector<base::FilePath>& headers);

#endif  // IOS_CHROME_TOOLS_STRINGS_GRIT_HEADER_PARSING_H_
