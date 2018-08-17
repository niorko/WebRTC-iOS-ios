// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTOFILL_MANUAL_FILL_CREDENTIAL_PASSWORD_FORM_H_
#define IOS_CHROME_BROWSER_UI_AUTOFILL_MANUAL_FILL_CREDENTIAL_PASSWORD_FORM_H_

#import "ios/chrome/browser/ui/autofill/manual_fill/credential.h"

namespace autofill {
struct PasswordForm;
}

@interface ManualFillCredential (PasswordForm)

// Convenience initializer from a PasswordForm.
- (instancetype)initWithPasswordForm:
    (const autofill::PasswordForm&)passwordForm;

@end

#endif  // IOS_CHROME_BROWSER_UI_AUTOFILL_MANUAL_FILL_CREDENTIAL_PASSWORD_FORM_H_
