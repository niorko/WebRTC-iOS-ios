// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_MAIN_BROWSER_H_
#define IOS_CHROME_BROWSER_MAIN_BROWSER_H_

#include <memory>

#include "base/supports_user_data.h"

class BrowserObserver;
class ChromeBrowserState;
@class CommandDispatcher;
class WebStateList;

// Browser is the model for a window containing multiple tabs. Instances
// are owned by a BrowserList to allow multiple windows for a single user
// session.
//
// See src/docs/ios/objects.md for more information.
class Browser : public base::SupportsUserData {
 public:
  // Creates a new Browser attached to `browser_state`.
  static std::unique_ptr<Browser> Create(ChromeBrowserState* browser_state);

  Browser(const Browser&) = delete;
  Browser& operator=(const Browser&) = delete;

  ~Browser() override {}

  // Accessor for the owning ChromeBrowserState.
  virtual ChromeBrowserState* GetBrowserState() = 0;

  // Accessor for the WebStateList.
  virtual WebStateList* GetWebStateList() = 0;

  // Accessor for the CommandDispatcher.
  virtual CommandDispatcher* GetCommandDispatcher() = 0;

  // Adds and removes observers.
  virtual void AddObserver(BrowserObserver* observer) = 0;
  virtual void RemoveObserver(BrowserObserver* observer) = 0;

 protected:
  Browser() {}
};

#endif  // IOS_CHROME_BROWSER_MAIN_BROWSER_H_
