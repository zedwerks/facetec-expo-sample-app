//
//  FaceTecSDKModule.swift
//
//  Converted from a legacy RCTEventEmitter bridge module to an Expo Module
//  (ExpoModulesCore). This mirrors the pattern already proven working in
//  this codebase by MultipazProximityModule/MultipazDeviceKeyModule — both
//  present native UI and emit events under the same RN 0.85.3 / Expo SDK 56
//  New Architecture (Fabric + bridgeless) stack without issue.
//
//  Why this changed: FaceTec's own reference React Native integration
//  predates RN's New Architecture and targets the legacy bridge only
//  (RCTEventEmitter, RCT_EXTERN_MODULE). RN 0.85 removed the legacy bridge
//  and its interop shim entirely, and Expo SDK 55+ silently ignores
//  newArchEnabled — so this app has been running fully on Fabric/TurboModules
//  regardless of the (now-defunct) `newArchEnabled: false` setting in
//  app.config.js. A precompiled legacy bridge module calling into UIKit
//  view-controller presentation (start3DLiveness's topVC.present(...)) is a
//  plausible source of the SIGSEGV seen only in TestFlight/Release builds.
//  Expo Modules are New-Architecture-native (JSI-based) regardless of legacy/
//  new bridge mode, so this sidesteps the interop layer entirely.
//

import Foundation
import FaceTecSDK
import ExpoModulesCore

// MARK: - NSObject delegate shim
//
// FaceTecSessionRequestProcessor is an Objective-C protocol (FaceTecSDK is an
// Obj-C framework under the hood), and any Swift type declaring conformance
// to an Obj-C / NSObjectProtocol-based protocol must actually inherit from
// NSObject — Swift won't let you "declare conformance" without real Obj-C
// object identity behind it.
//
// This worked previously only because the old superclass, RCTEventEmitter,
// was itself an NSObject subclass. ExpoModulesCore's `Module` base class is
// NOT an NSObject subclass, so FaceTecSDKModule can no longer conform to
// this protocol directly. This tiny NSObject shim satisfies the protocol
// requirement on FaceTecSDK's behalf and forwards every callback straight
// through to the owning Module instance, which holds all the real state and
// is the only thing that can call sendEvent(_:_:).
//
// NOTE: FaceTecInitializeCallback is deliberately NOT implemented here.
// Its onFaceTecSDKInitializeSuccess(sdkInstance:) takes a FaceTecSDKInstance,
// and FaceTecSDK 10.1.7 ships that class without default visibility — its
// OBJC_CLASS_$_FaceTecSDKInstance symbol isn't exported from the xcframework.
// Swift needs that symbol the moment the type appears anywhere as a static
// type, even just as a parameter it never touches, which would make any
// Swift conformer fail to link. FaceTecSDKBridge (Objective-C, where a
// class-typed parameter doesn't need the symbol) handles that callback
// instead — see FaceTecSDKBridge.h for the full explanation.
private class FaceTecDelegate: NSObject, FaceTecSessionRequestProcessor {
  weak var module: FaceTecSDKModule?

  init(module: FaceTecSDKModule) {
    self.module = module
  }

  func onSessionRequest(
    sessionRequestBlob: String,
    sessionRequestCallback: any FaceTecSessionRequestProcessorCallback
  ) {
    module?.handleSessionRequest(
      sessionRequestBlob: sessionRequestBlob,
      sessionRequestCallback: sessionRequestCallback
    )
  }

  func onFaceTecExit(sessionResult: any FaceTecSessionResult) {
    module?.handleFaceTecExit(sessionResult: sessionResult)
  }

  deinit {
    print("[FaceTecDelegate] deinit called")
  }
}

/**
 This object is both the Expo module and (via the FaceTecDelegate shim above)
 the request processor for the FaceTec SDK. It is the main integration point
 between the React Native layer and the FaceTec SDK.

 - The React Native layer calls initialize(), which initialises the FaceTec SDK.
 - The SDK calls onSessionRequest(), which forwards the blob to React Native via the
   "onProcessSession" event.
 - React Native relays the blob to the FaceTec server, then calls onResponseBlobReceived()
   with the server's response blob.
 - The SDK processes the result and calls onFaceTecExit(), which emits "onFaceTecExit"
   to React Native.

 IMPORTANT — onSessionRequest fires from TWO different triggers, not one:
 ─────────────────────────────────────────────────────────────────────────
 initialize() calls FaceTec.sdk.initializeWithSessionRequest(...), which performs its
 own session-request handshake (fetching/validating a Session Token) as part of SDK
 initialization — BEFORE start3DLiveness() is ever called and BEFORE any camera UI is
 shown. This handshake invokes the exact same onSessionRequest() delegate method as a
 real face-scan capture session.

 Without the isLiveSession flag below, both triggers were indistinguishable on the JS
 side, so the init-time handshake — carrying an empty externalDatabaseRefID (it's only
 set in start3DLiveness) and no real FaceScan biometric data — was being forwarded to
 the app's own /process-request backend as if it were a genuine liveness submission.
 That produced a spurious "wasProcessed=False" server log entry before the FaceTec
 camera screen ever opened.

 isLiveSession is true only between start3DLiveness() and onFaceTecExit(). The
 "isInitHandshake" flag sent to JS lets the bridge still relay the init-time handshake
 to FaceTec (required for initializeWithSessionRequest's completion callback to fire)
 without the app layer treating it as a real face-scan attempt.

 Threading rules
 ───────────────
 • processResponse()           MUST be called on the main thread (drives UIKit state).
 • sendEvent(_:_:)              Safe to call from any thread; dispatched to main below
                                 anyway to match prior behaviour.
 • abortOnCatastrophicError()  Safe from any thread.
 */
public class FaceTecSDKModule: Module {

  // Created lazily (first access happens after `self` is fully initialized,
  // e.g. inside the "initialize" AsyncFunction closure below) since it
  // captures `self`.
  private lazy var delegate: FaceTecDelegate = FaceTecDelegate(module: self)

  // Retained for the lifetime of a session request.
  // Cleared immediately after processResponse / abortOnCatastrophicError is called
  // to prevent stale callbacks from leaking across sessions.
  private var requestCallback: FaceTecSessionRequestProcessorCallback?

  // Holds the FaceTecSDKInstance behind an opaque Objective-C shim — see the
  // NOTE on FaceTecDelegate above and FaceTecSDKBridge.h for why.
  private let sdkBridge = FaceTecSDKBridge()

  private var latestExternalDatabaseRefID: String = ""

  // Cleared after use to guard against double-invocation.
  private var appInitializePromise: Promise?

  // True only between start3DLiveness() and onFaceTecExit(). Distinguishes a real,
  // user-facing capture session from the session-request handshake that
  // initializeWithSessionRequest() performs internally during initialize().
  private var isLiveSession: Bool = false

  // MARK: - Module definition

  public func definition() -> ModuleDefinition {
    Name("FaceTecSDKModule")

    Events("onProcessSession", "onFaceTecExit")

    OnCreate {
      print("[FaceTecSDKModule] Expo module loaded.")
    }

    // MARK: initialize

    AsyncFunction("initialize") { (deviceKeyIdentifier: String, promise: Promise) in
      print("[FaceTecSDKModule] initialize called with key: \(deviceKeyIdentifier)")

      guard !deviceKeyIdentifier.isEmpty else {
        promise.reject("ERR_FACETEC_INIT", "Device key was invalid or empty.")
        return
      }

      self.appInitializePromise = promise
      DispatchQueue.main.async {
        self.sdkBridge.initialize(
          withDeviceKeyIdentifier: deviceKeyIdentifier,
          sessionRequestProcessor: self.delegate,
          onSuccess: { [weak self] in
            self?.handleInitializeSuccess()
          },
          onError: { [weak self] errorDescription in
            self?.handleInitializeError(errorMessage: errorDescription)
          }
        )
      }
    }

    // MARK: getAPIUserAgentString

    AsyncFunction("getAPIUserAgentString") { (promise: Promise) in
      promise.resolve(FaceTec.sdk.getTestingAPIHeader())
    }

    // MARK: start3DLiveness

    Function("start3DLiveness") { (externalDatabaseRefId: String) in
      self.beginLivenessSession(externalDatabaseRefId: externalDatabaseRefId)
    }

    // MARK: onResponseBlobReceived (called from JS after relaying to FaceTec server)

    Function("onResponseBlobReceived") { (responseBlob: String) in
      self.deliverResponseBlob(responseBlob)
    }

    // MARK: onCatastrophicNetworkError

    Function("onCatastrophicNetworkError") {
      self.abortSessionOnCatastrophicNetworkError()
    }
  }

  // MARK: - Initialize callbacks (forwarded from FaceTecSDKBridge)

  private func handleInitializeSuccess() {
    print("[FaceTecSDKModule] SDK initialised successfully.")
    FaceTec.sdk.setCustomization(FaceTecConfig.getCustomization())

    // Guard against nil (e.g. double-callback) and clear after use.
    guard let promise = appInitializePromise else {
      print("[FaceTecSDKModule] Warning: handleInitializeSuccess fired but appInitializePromise is nil.")
      return
    }
    appInitializePromise = nil
    promise.resolve(true)
  }

  private func handleInitializeError(errorMessage: String) {
    print("[FaceTecSDKModule] Initialisation error: \(errorMessage)")

    guard let promise = appInitializePromise else {
      print("[FaceTecSDKModule] Warning: handleInitializeError fired but appInitializePromise is nil.")
      return
    }
    appInitializePromise = nil
    promise.reject("ERR_FACETEC_INIT", errorMessage)
  }

  // MARK: - Start liveness

  private func beginLivenessSession(externalDatabaseRefId: String) {
    print("[FaceTecSDKModule] Starting 3D liveness check. refId: \(externalDatabaseRefId)")
    self.latestExternalDatabaseRefID = externalDatabaseRefId

    // Marks the start of a real, user-facing capture session. Cleared in
    // handleFaceTecExit(). Any onSessionRequest() firing before this point (i.e. during
    // initialize()'s internal session-token handshake) will report
    // isInitHandshake: true to JS instead of being mistaken for a live scan.
    self.isLiveSession = true

    guard sdkBridge.isInitialized else {
      print("[FaceTecSDKModule] Error: sdkBridge is not initialized — was initialize() called?")
      self.isLiveSession = false
      return
    }

    DispatchQueue.main.async {

      print("[FaceTecSDKModule] About to call start3DLiveness")

      guard let livenessVC = self.sdkBridge.start3DLiveness(with: self.delegate) else {
        print("[FaceTecSDKModule] Error: start3DLiveness returned nil.")
        self.isLiveSession = false
        return
      }

      print("[FaceTecSDKModule] Returned from start3DLiveness")

      // keyWindow is deprecated in iOS 15 but windowScene.windows is also deprecated.
      // UIApplication.shared.connectedScenes is the recommended approach.
      guard
        let windowScene = UIApplication.shared.connectedScenes
          .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
        let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
      else {
        print("[FaceTecSDKModule] Error: could not find a key window root view controller.")
        self.isLiveSession = false
        return
      }

      // Walk to the topmost presented view controller to avoid
      // "already presenting" warnings when a modal is on screen.
      var topVC = rootVC
      while let presented = topVC.presentedViewController {
        topVC = presented
      }

      print("[FaceTecSDKModule] start3DLiveness called, presenting on \(String(describing: topVC))")

      topVC.present(livenessVC, animated: true, completion: nil)
    }
  }

  // MARK: - FaceTecSessionRequestProcessor (forwarded from FaceTecDelegate)

  fileprivate func handleSessionRequest(
    sessionRequestBlob: String,
    sessionRequestCallback: any FaceTecSessionRequestProcessorCallback
  ) {
    print("[FaceTecSDKModule] onSessionRequest — blob length: \(sessionRequestBlob.count), isLiveSession: \(isLiveSession)")
    self.requestCallback = sessionRequestCallback

    // When isLiveSession is false, this firing is the internal session-token
    // handshake performed by initializeWithSessionRequest() during initialize() —
    // not a real face scan. externalDatabaseRefID is still "" at that point since
    // it's only ever set in start3DLiveness(). Flag it explicitly rather than
    // relying on JS to infer this from an empty refID.
    let payload: [String: Any] = [
      "sessionRequestBlob": sessionRequestBlob,
      "externalDatabaseRefID": self.latestExternalDatabaseRefID,
      "xUserAgentHeader": FaceTec.sdk.getTestingAPIHeader(),
      "xTestingAPIHeader": FaceTec.sdk.getTestingAPIHeader(),  // for using FaceTec Testing Server ONLY.
      "isInitHandshake": !self.isLiveSession,
    ]

    DispatchQueue.main.async {
      self.sendEvent("onProcessSession", payload)
    }
  }

  // MARK: - Response blob (called from JS)

  private func deliverResponseBlob(_ responseBlob: String) {
    print("[FaceTecSDKModule] onResponseBlobReceived called — thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

    guard let callback = requestCallback else {
      print("[FaceTecSDKModule] requestCallback is nil — bailing")
      return
    }
    requestCallback = nil
    print("[FaceTecSDKModule] Dispatching processResponse to main thread")
    DispatchQueue.main.async {
      print("[FaceTecSDKModule] processResponse executing on main thread")
      callback.processResponse(responseBlob)
      print("[FaceTecSDKModule] processResponse returned")
    }
  }

  // MARK: - Catastrophic network error

  private func abortSessionOnCatastrophicNetworkError() {
    guard let callback = requestCallback else { return }
    requestCallback = nil
    // abortOnCatastrophicError is thread-safe per FaceTec docs.
    callback.abortOnCatastrophicError()
  }

  // MARK: - Session exit (forwarded from FaceTecDelegate)

  fileprivate func handleFaceTecExit(sessionResult: any FaceTecSessionResult) {
    let status = sessionResult.sessionStatus.rawValue
    print("[FaceTecSDKModule] onFaceTecExit — sessionStatus: \(status)")

    // Clear the live-session flag now that the real capture session (if any) has
    // fully exited. Safe to clear even if this exit corresponds to an init-time
    // handshake exit path, since isLiveSession would already be false in that case.
    self.isLiveSession = false

    let payload: [String: Any] = ["sessionStatus": status]
    DispatchQueue.main.async {
      self.sendEvent("onFaceTecExit", payload)
    }
  }

  deinit {
    print("[FaceTecSDKModule] deinit called")
  }
}
