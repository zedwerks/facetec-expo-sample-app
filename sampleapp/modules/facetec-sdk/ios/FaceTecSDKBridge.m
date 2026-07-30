//
//  FaceTecSDKBridge.m
//
//  See FaceTecSDKBridge.h for why this exists. FaceTecSDKInstance is only
//  ever referenced here, as: a protocol-typed callback parameter, a C-style
//  cast, and the receiver of an objc_msgSend — none of which require the
//  missing OBJC_CLASS_$_FaceTecSDKInstance symbol to link.
//
#import "FaceTecSDKBridge.h"

@interface FaceTecSDKBridge () <FaceTecInitializeCallback>
@property (nonatomic, strong, nullable) id sdkInstance;
@property (nonatomic, copy, nullable) void (^pendingSuccess)(void);
@property (nonatomic, copy, nullable) void (^pendingError)(NSString *errorDescription);
@end

@implementation FaceTecSDKBridge

- (BOOL)isInitialized {
  return self.sdkInstance != nil;
}

- (void)initializeWithDeviceKeyIdentifier:(NSString *)deviceKeyIdentifier
                   sessionRequestProcessor:(id<FaceTecSessionRequestProcessor>)sessionRequestProcessor
                                 onSuccess:(void (^)(void))onSuccess
                                   onError:(void (^)(NSString *errorDescription))onError {
  self.pendingSuccess = onSuccess;
  self.pendingError = onError;

  [FaceTec.sdk initializeWithSessionRequest:deviceKeyIdentifier
                    sessionRequestProcessor:sessionRequestProcessor
                                 completion:self];
}

- (void)onFaceTecSDKInitializeSuccess:(FaceTecSDKInstance *)sdkInstance {
  self.sdkInstance = sdkInstance;

  void (^success)(void) = self.pendingSuccess;
  self.pendingSuccess = nil;
  self.pendingError = nil;

  if (success) {
    success();
  }
}

- (void)onFaceTecSDKInitializeError:(enum FaceTecInitializationError)error {
  NSString *description = [FaceTec.sdk descriptionForInitializationError:error];

  void (^failure)(NSString *) = self.pendingError;
  self.pendingSuccess = nil;
  self.pendingError = nil;

  if (failure) {
    failure(description);
  }
}

- (nullable UIViewController *)start3DLivenessWithSessionRequestProcessor:(id<FaceTecSessionRequestProcessor>)sessionRequestProcessor {
  if (!self.sdkInstance) {
    return nil;
  }

  FaceTecSDKInstance *instance = (FaceTecSDKInstance *)self.sdkInstance;
  return [instance start3DLivenessWithSessionRequestProcessor:sessionRequestProcessor];
}

@end
