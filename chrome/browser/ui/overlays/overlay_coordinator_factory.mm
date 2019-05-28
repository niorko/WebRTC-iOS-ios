// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/overlays/overlay_coordinator_factory.h"

#include "base/logging.h"
#import "ios/chrome/browser/ui/overlays/overlay_request_coordinator.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface OverlayRequestCoordinatorFactory ()
// The Browser passed on initialization.
@property(nonatomic, readonly) Browser* browser;
// The OverlayRequestCoordinator subclasses that are supported at the modality
// associated with this coordinator factory.
@property(nonatomic, readonly)
    NSArray<Class>* supportedOverlayRequestCoordinatorClasses;
// Initializer used by |+factoryForBrowser:modality:|.
- (instancetype)initWithBrowser:(Browser*)browser
    supportedOverlayRequestCoordinatorClasses:
        (NSArray<Class>*)supportedOverlayClasses NS_DESIGNATED_INITIALIZER;
@end

@implementation OverlayRequestCoordinatorFactory

+ (instancetype)factoryForBrowser:(Browser*)browser
                         modality:(OverlayModality)modality {
  DCHECK(browser);
  NSArray<Class>* supportedCoordinatorClasses = @[];
  switch (modality) {
    case OverlayModality::kWebContentArea:
      // TODO(crbug.com/941745): Reset |supportedCoordinatorClasses| to contain
      // OverlayRequestCoordinator classes once implemented.
      break;
  }
  return [[self alloc] initWithBrowser:browser
      supportedOverlayRequestCoordinatorClasses:supportedCoordinatorClasses];
}

- (instancetype)initWithBrowser:(Browser*)browser
    supportedOverlayRequestCoordinatorClasses:
        (NSArray<Class>*)supportedOverlayClasses {
  if (self = [super init]) {
    _browser = browser;
    DCHECK(_browser);
    _supportedOverlayRequestCoordinatorClasses = supportedOverlayClasses;
    DCHECK(_supportedOverlayRequestCoordinatorClasses.count);
  }
  return self;
}

- (OverlayRequestCoordinator*)
    newCoordinatorForRequest:(OverlayRequest*)request
           dismissalDelegate:(OverlayUIDismissalDelegate*)dismissalDelegate
          baseViewController:(UIViewController*)baseViewController {
  for (Class coordinatorClass in self
           .supportedOverlayRequestCoordinatorClasses) {
    if ([coordinatorClass supportsRequest:request]) {
      return [[coordinatorClass alloc]
          initWithBaseViewController:baseViewController
                             browser:self.browser
                             request:request
                   dismissalDelegate:dismissalDelegate];
    }
  }
  NOTREACHED() << "Received unsupported request type.";
  return nil;
}

@end
