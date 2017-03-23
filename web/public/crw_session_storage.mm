// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/public/crw_session_storage.h"

#import "ios/web/navigation/crw_session_certificate_policy_manager.h"
#import "ios/web/public/serializable_user_data_manager.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Serialization keys used in NSCoding functions.
NSString* const kCertificatePolicyManagerKey = @"certificatePolicyManager";
NSString* const klastCommittedItemIndexKey = @"lastCommittedItemIndex";
NSString* const kItemStoragesKey = @"entries";
NSString* const kHasOpenerKey = @"openedByDOM";
NSString* const kPreviousItemIndexKey = @"previousItemIndex";
}

@interface CRWSessionStorage () {
  // Backing object for property of same name.
  std::unique_ptr<web::SerializableUserData> _userData;
}

@end

@implementation CRWSessionStorage

@synthesize hasOpener = _hasOpener;
@synthesize lastCommittedItemIndex = _lastCommittedItemIndex;
@synthesize previousItemIndex = _previousItemIndex;
@synthesize itemStorages = _itemStorages;
@synthesize sessionCertificatePolicyManager = _sessionCertificatePolicyManager;

#pragma mark - Accessors

- (web::SerializableUserData*)userData {
  return _userData.get();
}

- (void)setSerializableUserData:
    (std::unique_ptr<web::SerializableUserData>)userData {
  _userData = std::move(userData);
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(nonnull NSCoder*)decoder {
  self = [super init];
  if (self) {
    _hasOpener = [decoder decodeBoolForKey:kHasOpenerKey];
    _lastCommittedItemIndex =
        [decoder decodeIntForKey:klastCommittedItemIndexKey];
    _previousItemIndex = [decoder decodeIntForKey:kPreviousItemIndexKey];
    _itemStorages = [[NSMutableArray alloc]
        initWithArray:[decoder decodeObjectForKey:kItemStoragesKey]];
    // Prior to M34, 0 was used as "no index" instead of -1; adjust for that.
    if (!_itemStorages.count)
      _lastCommittedItemIndex = -1;
    _sessionCertificatePolicyManager =
        [decoder decodeObjectForKey:kCertificatePolicyManagerKey];
    if (!_sessionCertificatePolicyManager) {
      _sessionCertificatePolicyManager =
          [[CRWSessionCertificatePolicyManager alloc] init];
    }
    _userData = web::SerializableUserData::Create();
    _userData->Decode(decoder);
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder*)coder {
  [coder encodeBool:self.hasOpener forKey:kHasOpenerKey];
  [coder encodeInt:self.lastCommittedItemIndex
            forKey:klastCommittedItemIndexKey];
  [coder encodeInt:self.previousItemIndex forKey:kPreviousItemIndexKey];
  [coder encodeObject:self.itemStorages forKey:kItemStoragesKey];
  [coder encodeObject:self.sessionCertificatePolicyManager
               forKey:kCertificatePolicyManagerKey];
  if (_userData)
    _userData->Encode(coder);
}

@end
