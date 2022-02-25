// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_PUBLIC_WEBUI_WEB_UI_IOS_H_
#define IOS_WEB_PUBLIC_WEBUI_WEB_UI_IOS_H_

#include <memory>
#include <string>
#include <vector>

#include "base/callback.h"
#include "base/values.h"

class GURL;

namespace web {

class WebState;
class WebUIIOSController;
class WebUIIOSMessageHandler;

// A WebUIIOS sets up the datasources and message handlers for a given
// HTML-based UI.
class WebUIIOS {
 public:
  // Returns JavaScript code that, when executed, calls the function specified
  // by |function_name| with the arguments specified in |arg_list|.
  static std::u16string GetJavascriptCall(
      const std::string& function_name,
      const std::vector<const base::Value*>& arg_list);

  virtual ~WebUIIOS() {}

  virtual web::WebState* GetWebState() const = 0;

  virtual WebUIIOSController* GetController() const = 0;
  virtual void SetController(
      std::unique_ptr<WebUIIOSController> controller) = 0;

  // Takes ownership of |handler|, which will be destroyed when the WebUIIOS is.
  virtual void AddMessageHandler(
      std::unique_ptr<WebUIIOSMessageHandler> handler) = 0;

  // TODO(crbug.com/1300095): new version of DeprecatedMessageCallback2 that
  // takes base::Value::List as a parameter needs to be introduced. Afterwards
  // existing callers of RegisterDeprecatedMessageCallback() should be migrated
  // to the new RegisterMessageCallback() (not the one below) version.
  //
  // Used by WebUIIOSMessageHandlers. If the given message is already
  // registered, the call has no effect.
  using DeprecatedMessageCallback2 =
      base::RepeatingCallback<void(base::Value::ConstListView)>;
  virtual void RegisterMessageCallback(const std::string& message,
                                       DeprecatedMessageCallback2 callback) = 0;

  // TODO(crbug.com/1300095): new version of DeprecatedMessageCallback that
  // takes base::Value::List as a parameter needs to be introduced. Afterwards
  // existing callers of RegisterDeprecatedMessageCallback() should be migrated
  // to the new RegisterMessageCallback() (not the one above) version if
  // possible.
  //
  // Used by WebUIIOSMessageHandlers. If the given message is already
  // registered, the call has no effect.
  using DeprecatedMessageCallback =
      base::RepeatingCallback<void(const base::ListValue*)>;
  virtual void RegisterDeprecatedMessageCallback(
      const std::string& message,
      const DeprecatedMessageCallback& callback) = 0;

  // This is only needed if an embedder overrides handling of a WebUIIOSMessage
  // and then later wants to undo that, or to route it to a different WebUIIOS
  // object.
  virtual void ProcessWebUIIOSMessage(const GURL& source_url,
                                      const std::string& message,
                                      const base::Value& args) = 0;

  // Call a Javascript function.  This is asynchronous; there's no way to get
  // the result of the call, and should be thought of more like sending a
  // message to the page.  All function names in WebUI must consist of only
  // ASCII characters.
  virtual void CallJavascriptFunction(
      const std::string& function_name,
      const std::vector<const base::Value*>& args) = 0;

  // Helper method for responding to Javascript requests initiated with
  // cr.sendWithPromise() (defined in cr.js) for the case where the returned
  // promise should be resolved (request succeeded).
  virtual void ResolveJavascriptCallback(const base::Value& callback_id,
                                         const base::Value& response) = 0;

  // Helper method for responding to Javascript requests initiated with
  // cr.sendWithPromise() (defined in cr.js), for the case where the returned
  // promise should be rejected (request failed).
  virtual void RejectJavascriptCallback(const base::Value& callback_id,
                                        const base::Value& response) = 0;

  // Helper method for notifying Javascript listeners added with
  // cr.addWebUIListener() (defined in cr.js).
  virtual void FireWebUIListener(
      const std::string& event_name,
      const std::vector<const base::Value*>& args) = 0;
};

}  // namespace web

#endif  // IOS_WEB_PUBLIC_WEBUI_WEB_UI_IOS_H_
