// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_VARIATIONS_IOS_CHROME_FIRST_RUN_VARIATIONS_SEED_MANAGER_H_
#define IOS_CHROME_BROWSER_VARIATIONS_IOS_CHROME_FIRST_RUN_VARIATIONS_SEED_MANAGER_H_

#import <Foundation/Foundation.h>

@class IOSChromeSeedResponse;

// Protocol for variations seed fetcher that reacts to variations seed fetch
// stages.
@protocol IOSChromeFirstRunVariationsSeedManagerDelegate

// Informs the delegate that the initial seed fetch has successfully completed
// or failed.
- (void)didFetchSeedSuccess:(BOOL)succeeded;

@end

// Fetches the variations seed before the actual first run of Chrome.
//
// Note: the caller is responsible for making sure that a seed fetcher object is
// only be initiated on first run.
@interface IOSChromeFirstRunVariationsSeedManager : NSObject

// Delegate object that observes the status of seed fetching.
@property(nonatomic, weak) id<IOSChromeFirstRunVariationsSeedManagerDelegate>
    delegate;

// The fetched seed response.
@property(nonatomic, readonly) IOSChromeSeedResponse* seed;

// Starts fetching the initial seed from the variations server.
- (void)startSeedFetch;

// Resets the seed response; called by the variations service after the seed is
// imported into Chrome Prefs.
- (void)clearSeed;

@end

#endif  // IOS_CHROME_BROWSER_VARIATIONS_IOS_CHROME_FIRST_RUN_VARIATIONS_SEED_MANAGER_H_