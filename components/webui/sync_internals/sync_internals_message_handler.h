// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_COMPONENTS_WEBUI_SYNC_INTERNALS_SYNC_INTERNALS_MESSAGE_HANDLER_H_
#define IOS_COMPONENTS_WEBUI_SYNC_INTERNALS_SYNC_INTERNALS_MESSAGE_HANDLER_H_

#include <memory>
#include <string>

#include "base/macros.h"
#include "base/memory/weak_ptr.h"
#include "base/values.h"
#include "components/sync/driver/sync_service_observer.h"
#include "components/sync/engine/events/protocol_event_observer.h"
#include "components/sync/js/js_controller.h"
#include "components/sync/js/js_event_handler.h"
#include "ios/web/public/webui/web_ui_ios_message_handler.h"

namespace syncer {
class SyncService;
}  // namespace syncer

// The implementation for the chrome://sync-internals page.
class SyncInternalsMessageHandler : public web::WebUIIOSMessageHandler,
                                    public syncer::JsEventHandler,
                                    public syncer::SyncServiceObserver,
                                    public syncer::ProtocolEventObserver {
 public:
  SyncInternalsMessageHandler();
  ~SyncInternalsMessageHandler() override;

  void RegisterMessages() override;

  // Sets up observers to receive events and forward them to the UI.
  void HandleRegisterForEvents(const base::ListValue* args);

  // Fires an event to send updated info back to the page.
  void HandleRequestUpdatedAboutInfo(const base::ListValue* args);

  // Fires an event to send the list of types back to the page.
  void HandleRequestListOfTypes(const base::ListValue* args);

  // Fires an event to send the initial state of the "include specifics" flag.
  void HandleRequestIncludeSpecificsInitialState(const base::ListValue* args);

  // Handler for getAllNodes message.  Needs a |request_id| argument.
  void HandleGetAllNodes(const base::ListValue* args);

  // Handler for setting internal state of if specifics should be included in
  // protocol events when sent to be displayed.
  void HandleSetIncludeSpecifics(const base::ListValue* args);

  // Handler for requestStart message.
  void HandleRequestStart(const base::ListValue* args);

  // Handler for requestStopKeepData message.
  void HandleRequestStopKeepData(const base::ListValue* args);

  // Handler for requestStopClearData message.
  void HandleRequestStopClearData(const base::ListValue* args);

  // Handler for triggerRefresh message.
  void HandleTriggerRefresh(const base::ListValue* args);

  // syncer::JsEventHandler implementation.
  void HandleJsEvent(const std::string& name,
                     const syncer::JsEventDetails& details) override;

  // Callback used in GetAllNodes.
  void OnReceivedAllNodes(int request_id,
                          std::unique_ptr<base::ListValue> nodes);

  // syncer::SyncServiceObserver implementation.
  void OnStateChanged(syncer::SyncService* sync) override;

  // ProtocolEventObserver implementation.
  void OnProtocolEvent(const syncer::ProtocolEvent& e) override;

 private:
  // Fetches updated aboutInfo and sends it to the page in the form of an
  // onAboutInfoUpdated event.
  void SendAboutInfo();

  syncer::SyncService* GetSyncService();

  void DispatchEvent(const std::string& name, const base::Value& details_value);

  base::WeakPtr<syncer::JsController> js_controller_;

  // A flag used to prevent double-registration with ProfileSyncService.
  bool is_registered_ = false;

  // Whether specifics should be included when converting protocol events to a
  // human readable format.
  bool include_specifics_ = false;

  base::WeakPtrFactory<SyncInternalsMessageHandler> weak_ptr_factory_;

  DISALLOW_COPY_AND_ASSIGN(SyncInternalsMessageHandler);
};

#endif  // IOS_COMPONENTS_WEBUI_SYNC_INTERNALS_SYNC_INTERNALS_MESSAGE_HANDLER_H_
