//---------------------------------------------------------------------------
// modules/facetec-sdk/src/FaceTec.ts
//
// Thin wrapper around the FaceTec native SDK.
//---------------------------------------------------------------------------

import {
  PermissionsAndroid,
  Platform,
  Alert,
} from "react-native";
import { requireNativeModule } from "expo-modules-core";
import type { EventSubscription } from "expo-modules-core";
import * as Crypto from "expo-crypto";

export interface LivenessResult {
  success: boolean;
  livenessProven: boolean;
  externalDatabaseRefId?: string;
}

// ── Native module interface ────────────────────────────────────────────────
// Mirrors FaceTecSDKModule.swift (an Expo Module, see modules/facetec-sdk).
// Converted from the legacy RCTEventEmitter/NativeModules bridge pattern —
// see FaceTecSDKModule.swift for why (RN 0.85 removed the legacy bridge
// interop shim entirely; Expo Modules are JSI-native and work under Fabric
// regardless).
export interface FaceTecConfig {
  deviceKeyIdentifier: string;
  serverBaseUrl: string;
  allowCancelledForDev?: boolean;
}

interface FaceTecOnProcessSessionEvent {
  sessionRequestBlob: string;
  externalDatabaseRefID: string;
  xUserAgentHeader: string;
  xTestingAPIHeader: string;
  isInitHandshake: boolean;
}

interface FaceTecOnFaceTecExitEvent {
  sessionStatus?: number;
  sessionStatusName?: string;
}

type FaceTecSDKModuleEvents = {
  onProcessSession: (event: FaceTecOnProcessSessionEvent) => void;
  onFaceTecExit: (event: FaceTecOnFaceTecExitEvent) => void;
};

interface FaceTecSDKModuleInterface {
  /** Resolves once the native SDK has initialized; rejects with an Error on failure. */
  initialize(deviceKeyIdentifier: string): Promise<boolean>;
  getAPIUserAgentString(): Promise<string>;
  start3DLiveness(externalDatabaseRefId: string): void;
  onResponseBlobReceived(responseBlob: string): void;
  onCatastrophicNetworkError(): void;
  addListener<K extends keyof FaceTecSDKModuleEvents>(
    eventName: K,
    listener: FaceTecSDKModuleEvents[K],
  ): EventSubscription;
  removeAllListeners(eventName: keyof FaceTecSDKModuleEvents): void;
}

// FaceTecSDKModule accessed lazily — requireNativeModule throws if called
// before the native module registry is ready, so never call it at import time.
let _module: FaceTecSDKModuleInterface | null = null;
const getFaceTecModule = (): FaceTecSDKModuleInterface => {
  if (!_module) {
    try {
      _module = requireNativeModule<FaceTecSDKModuleInterface>("FaceTecSDKModule");
    } catch (err) {
      throw new Error(
        "[FaceTec] FaceTecSDKModule native module is not registered. " +
          "Ensure the FaceTec config plugins ran and the app was rebuilt. " +
          `Underlying error: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }
  return _module;
};

export class FaceTec {
  constructor(private readonly config: FaceTecConfig) {}
  private sessionListener: EventSubscription | null = null;

  private resetState(): void {
    this.externalDatabaseRefId = "";
    this.serverResult = null;
  }

  // The externalDatabaseRefId used in the process-request call that enrolled the
  // FaceMap on FaceTec's servers. The backend uses this for match-3d-2d —
  // the faceScanBlob itself is never forwarded to the backend.
  private externalDatabaseRefId: string = "";

  // Populated by relayToFaceTecServer — carries the FaceTec server's liveness
  // outcome so the resolved LivenessResult includes pass/fail flags.
  private serverResult: {
    success: boolean;
    livenessProven: boolean;
  } | null = null;

  // ── Public API ────────────────────────────────────────────────────────────

  // Cached init promise — all concurrent initialize() calls share the same
  // in-flight promise rather than triggering multiple SDK init calls.
  // Cleared to null on failure so the caller can retry.
  private initPromise: Promise<void> | null = null;

  initialize(): Promise<void> {
    if (this.initPromise) {
      console.log(
        "[FaceTec] Already initializing or initialized — returning cached promise.",
      );
      return this.initPromise;
    }

    this.resetState();

    console.log("[FaceTec] Initializing...");

    // The session listener MUST be registered before calling initialize().
    this.registerSessionListener();

    console.log(
      "[FaceTec] Calling FaceTecSDKModule.initialize with device key identifier:",
      this.getDeviceKeyIdentifier(),
    );

    // Native initialize() is an Expo Module AsyncFunction — it resolves once
    // FaceTec.sdk.initializeWithSessionRequest's completion callback fires
    // successfully, and rejects (with the FaceTec error message as the JS
    // Error's message) on failure.
    this.initPromise = getFaceTecModule()
      .initialize(this.getDeviceKeyIdentifier())
      .then(() => {
        console.log("[FaceTec] SDK initialized successfully.");
      })
      .catch((err: unknown) => {
        const message = err instanceof Error ? err.message : String(err);
        console.error("[FaceTec] Initialization failed:", message);
        this.initPromise = null; // allow retry
        throw new Error(`FaceTec initialization failed: ${message}`);
      });

    return this.initPromise;
  }

startLivenessCheck(): Promise<LivenessResult> {
  const pendingInit = this.initPromise;
  if (!pendingInit) {
    return Promise.reject(
      new Error("[FaceTec] Not initialized — call initialize() first."),
    );
  }

  return pendingInit.then(() => this._startLivenessCheck());
}

private _startLivenessCheck(): Promise<LivenessResult> {    // Clear state from any previous session.
    this.resetState();
    this.externalDatabaseRefId = Crypto.randomUUID(); // Generate a new refId for each session to ensure uniqueness in backend match-3d-2d

    console.log("[FaceTec] Starting liveness detection...");

    return new Promise((resolve, reject) => {
      const exitListener = getFaceTecModule().addListener(
        "onFaceTecExit",
        (result: FaceTecOnFaceTecExitEvent) => {
          exitListener.remove();
          console.log(
            "[FaceTec] onFaceTecExit — sessionStatus:",
            result.sessionStatus,
          );
          console.log(
            "[FaceTec] onFaceTecExit — sessionStatusName:",
            result.sessionStatusName,
          );
          console.log("[FaceTec] serverResult:", this.serverResult);

          // sessionStatus 0 = sessionCompleted — the SDK's authoritative signal
          // that the session finished normally (not cancelled or errored).
          // Android and iOS can report different numeric values, so also accept
          // explicit success status names and a successful server outcome.
          const sessionCancelledByUser =
            result.sessionStatusName === "USER_CANCELLED_FACE_SCAN" ||
            result.sessionStatusName === "USER_CANCELLED";
          const allowCancelledForDev =
            __DEV__ && this.config.allowCancelledForDev === true;
          const sessionCompletedByStatus =
            result.sessionStatus === 0 ||
            result.sessionStatusName === "SESSION_COMPLETED_SUCCESSFULLY";
          const sessionCompletedByServer =
            !sessionCancelledByUser &&
            this.serverResult?.success === true &&
            this.serverResult?.livenessProven === true;
          const sessionCompleted =
            (!sessionCancelledByUser &&
              (sessionCompletedByStatus || sessionCompletedByServer)) ||
            (allowCancelledForDev &&
              sessionCancelledByUser &&
              sessionCompletedByServer);

          if (
            allowCancelledForDev &&
            sessionCancelledByUser &&
            sessionCompletedByServer
          ) {
            console.warn(
              "[FaceTec] DEV BYPASS (guarded by __DEV__): proceeding after cancelled FaceTec session because config.allowCancelledForDev=true",
            );
          }

          if (sessionCompleted) {
            resolve({
              // externalDatabaseRefId is what the backend needs for match-3d-2d.
              // faceScanBlob is one-time-use and already consumed by process-request.
              externalDatabaseRefId: this.externalDatabaseRefId,
              success: this.serverResult?.success ?? false,
              livenessProven: this.serverResult?.livenessProven ?? false,
            });
          } else {
            // User cancelled or session errored — not a hard failure.
            reject(
              new Error(
                `Liveness session did not complete. FaceTec status: ${result.sessionStatus ?? "unknown"}`,
              ),
            );
          }
        },
      );
      this.checkCameraPermission().then((granted) => {
        if (!granted) {
          exitListener.remove();
          reject(
            new Error(
              "Camera permission denied. Liveness check cannot start without camera access.",
            ),
          );
          return;
        }
        if (granted) {
          console.log("[FaceTec] Camera permission granted. Starting SDK...");
          getFaceTecModule().start3DLiveness(this.externalDatabaseRefId);
        }
      });
    });
  }

  dispose(): void {
    if (this.sessionListener) {
      this.sessionListener.remove();
      this.sessionListener = null;
      console.log("[FaceTec] Disposed — session listener removed.");
    }
  }

  // Check Android Camera permissions.
  private async checkCameraPermission(): Promise<boolean> {
    if (Platform.OS === 'android') {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.CAMERA,
        {
          title: 'Camera Permission',
          message: 'This app needs access to your camera to verify liveness.',
          buttonPositive: 'OK',
        },
      );
      if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
        Alert.alert('Camera Permission Required', 'Liveness check cannot start without camera access.');
        return false;
      }
    }
    return true;  // default for iOS and other platforms
  }

      // ── Private ───────────────────────────────────────────────────────────────

  // Persistent listener for "onProcessSession".
  // Fires during initialization AND every subsequent liveness session.
  // Captures the 3D face scan blob, relays to FaceTec server for liveness
  // validation, then returns the responseBlob to the native SDK.
  private registerSessionListener(): void {
    if (this.sessionListener) {
      console.log("[FaceTec] Session listener already registered — skipping.");
      return; // Already registered — don't double-up.
    }

    console.log("[FaceTec] Registering onProcessSession listener.");

    this.sessionListener = getFaceTecModule().addListener(
      "onProcessSession",
      async (payload: FaceTecOnProcessSessionEvent) => {
        console.log(
          "[FaceTec] onProcessSession — isInitHandshake:",
          payload.isInitHandshake,
          "blob length:",
          payload.sessionRequestBlob?.length,
        );

        if (!payload.isInitHandshake) {
          // Real capture session — track state as before.
          if (payload.externalDatabaseRefID !== this.externalDatabaseRefId) {
            console.warn(
              "[FaceTec] onProcessSession — externalDatabaseRefID mismatch.",
            );
          }
        }

        try {
          const responseBlob = await this.relayToFaceTecServer(
            payload.sessionRequestBlob,
            payload.isInitHandshake ? "" : this.externalDatabaseRefId, // only when we are doing liveness processing.
            payload.xUserAgentHeader,
            payload.xTestingAPIHeader
          );
          console.log("[FaceTec] Passing responseBlob back to SDK.");
          getFaceTecModule().onResponseBlobReceived(responseBlob);
        } catch (err) {
          // Only call abortOnCatastrophicError on hard network failures.
          // Never use this to exit the FaceTec UI for custom logic.
          console.error("[FaceTec] Catastrophic network error:", err);
          getFaceTecModule().onCatastrophicNetworkError();
        }
      },
    );
  }

  // Relays to the FaceTec server for liveness validation.
  // Returns the responseBlob the native SDK needs to drive its result animation.
  // Populates lastServerResult with the liveness pass/fail outcome.
  private async relayToFaceTecServer(
    sessionRequestBlob: string,
    externalDatabaseRefID: string,
    xUserAgentHeader: string,
    xTestingAPIHeader: string
  ): Promise<string> {
    const body: Record<string, string> = { requestBlob: sessionRequestBlob };
    if (externalDatabaseRefID) {
      body.externalDatabaseRefID = externalDatabaseRefID;
    }

    const response = await fetch(this.getRequestEndpoint(), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-User-Agent": xUserAgentHeader,
        "X-Device-Key": this.getDeviceKeyIdentifier(),
        "X-Transaction-Id": externalDatabaseRefID ?? "",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorBody = await response.text().catch(() => "");
      throw new Error(
        `FaceTec server HTTP ${response.status}: ${errorBody || response.statusText}`,
      );
    }

    const json = await response.json();
    console.log(
      "[FaceTec] FaceTec server response:",
      JSON.stringify(json),
    );

    console.info(
      "[FaceTec] Capturing FaceTec server result for liveness outcome...",
    );
    console.debug("  success:", json.success || false);
    console.debug("  livenessProven:", json.result?.livenessProven);
    console.debug("  error:", json.error);
    console.debug("  errorMessage:", json.errorMessage);
    console.debug("  didError present:", !!json.didError);

    // FaceTec v4 API uses { error, success, livenessProven, scanResultBlob } at the
    // top level. NOT { didError } or nested { result: { livenessProven } }.
    // Throw here so the error surfaces clearly rather than silently returning
    // an empty blob that confuses the SDK animation.
    if (json.didError === true) {
      throw new Error(
        `FaceTec server rejected request: ${json.errorMessage ?? JSON.stringify(json)}`,
      );
    }

    // Capture liveness outcome for use when resolving LivenessResult.
    // FaceTec v10 dev server success is true when liveness is proven, false when liveness fails, and didError is never true.
    this.serverResult = {
      success: json.didError === false,
      livenessProven: json.didError === false,
    };

    // responseBlob drives the SDK's result animation only — it is NOT the
    // faceScanBlob forwarded to the backend. That is sessionRequestBlob.
    const blob: string | undefined = json.scanResultBlob ?? json.responseBlob;
    if (!blob) {
      throw new Error(
        `FaceTec server response missing responseBlob. Got: ${JSON.stringify(json)}`,
      );
    }

    return blob;
  }

  private getRequestEndpoint(): string {
    console.log("[FaceTec] Using FaceTec server base URL:", this.config.serverBaseUrl);
    return `${this.config.serverBaseUrl}/process-request`;
  }

  private getDeviceKeyIdentifier(): string {
    console.log("[FaceTec] Using device key identifier:", this.config.deviceKeyIdentifier);
    return this.config.deviceKeyIdentifier;
  }
}

// ── Singleton accessors ─────────────────────────────────────────────────────
// FaceTec is configured once at app startup (configureFaceTec) rather than
// constructed eagerly at import time — the config (server URL, device key)
// isn't known until then. getFaceTecScanner() throws if called first.
let _instance: FaceTec | null = null;

export function configureFaceTec(config: FaceTecConfig): void {
  _instance = new FaceTec(config);
}

export function getFaceTecInstance(): FaceTec {
  if (!_instance) {
    throw new Error(
      "[FaceTec] getFaceTecInstance() called before configureFaceTec(). " +
        "Call configureFaceTec(config) once at app startup.",
    );
  }
  return _instance;
}
