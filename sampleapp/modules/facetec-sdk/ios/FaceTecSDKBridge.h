//
//  FaceTecSDKBridge.h
//
//  FaceTecSDK 10.1.7 ships FaceTecSDKInstance (the object handed to
//  onFaceTecSDKInitializeSuccess, and the only type start3DLiveness lives on)
//  without the `__attribute__((visibility("default")))` every other public
//  class in FaceTecPublicApi.h carries. That's a packaging defect in the
//  vendored xcframework: the class is compiled hidden, so
//  OBJC_CLASS_$_FaceTecSDKInstance isn't exported from the dylib.
//
//  Swift needs that symbol the moment FaceTecSDKInstance appears as a static
//  type anywhere (a property, a parameter — even one it never touches), which
//  is unavoidable if a Swift type conforms to FaceTecInitializeCallback
//  directly. Plain Objective-C doesn't: a method parameter typed
//  FaceTecSDKInstance*, or a cast to it, compiles to a plain objc_msgSend
//  with no reference to the class symbol, as long as nothing calls
//  +class]/+alloc] or subclasses it. This shim confines every reference to
//  FaceTecSDKInstance to FaceTecSDKBridge.m so the Swift side only ever sees
//  `id`/blocks and never trips the missing symbol.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <FaceTecSDK/FaceTecSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface FaceTecSDKBridge : NSObject

@property (nonatomic, readonly) BOOL isInitialized;

- (void)initializeWithDeviceKeyIdentifier:(NSString *)deviceKeyIdentifier
                   sessionRequestProcessor:(id<FaceTecSessionRequestProcessor>)sessionRequestProcessor
                                 onSuccess:(void (^)(void))onSuccess
                                   onError:(void (^)(NSString *errorDescription))onError;

- (nullable UIViewController *)start3DLivenessWithSessionRequestProcessor:(id<FaceTecSessionRequestProcessor>)sessionRequestProcessor;

@end

NS_ASSUME_NONNULL_END
