// Copyright 2014 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file adheres to closure-compiler conventions in order to enable
// compilation with ADVANCED_OPTIMIZATIONS. See http://goo.gl/FwOgy

// Script to set windowId.
(function() {
// CRWJSWindowIDManager replaces $(WINDOW_ID) with appropriate string upon
// injection.
__gCrWeb['windowId'] = '$(WINDOW_ID)';

const event = new Event('__gCrWebWindowIdInjected');
window.dispatchEvent(event);

}());
