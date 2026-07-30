package com.zedwerks.facetec

import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import com.facetec.sdk.FaceTecInitializationError
import com.facetec.sdk.FaceTecSDK
import com.facetec.sdk.FaceTecSDKInstance
import com.facetec.sdk.FaceTecSessionRequestProcessor

class FaceTecSDKModule : Module(), FaceTecSessionRequestProcessor {
  private var faceTecSDKInstance: FaceTecSDKInstance? = null
  private var requestCallback: FaceTecSessionRequestProcessor.Callback? = null
  private var latestExternalDatabaseRefID = ""
  private var isLiveSession = false

  override fun definition() = ModuleDefinition {
    Name("FaceTecSDKModule")
    Events("onProcessSession", "onFaceTecExit")

    AsyncFunction("initialize") { deviceKeyIdentifier: String, promise: Promise ->
      val context = appContext.reactContext
        ?: return@AsyncFunction promise.reject("ERR_FACETEC_INIT", "React context unavailable", null)
      isLiveSession = false
      FaceTecSDK.initializeWithSessionRequest(context, deviceKeyIdentifier, this@FaceTecSDKModule,
        object : FaceTecSDK.InitializeCallback {
          override fun onSuccess(sdkInstance: FaceTecSDKInstance) {
            faceTecSDKInstance = sdkInstance
            FaceTecSDK.setCustomization(FaceTecConfig.getCustomization())
            promise.resolve(true)
          }
          override fun onError(error: FaceTecInitializationError) {
            promise.reject("ERR_FACETEC_INIT", error.toString(), null)
          }
        })
    }

    AsyncFunction("getAPIUserAgentString") { promise: Promise -> promise.resolve(FaceTecSDK.getTestingAPIHeader()) }

    Function("start3DLiveness") { externalDatabaseRefId: String ->
      isLiveSession = true
      latestExternalDatabaseRefID = externalDatabaseRefId
      val activity = appContext.currentActivity ?: return@Function
      faceTecSDKInstance?.start3DLiveness(activity, this@FaceTecSDKModule)
    }

    Function("onResponseBlobReceived") { responseBlob: String ->
      requestCallback?.processResponse(responseBlob); requestCallback = null
    }

    Function("onCatastrophicNetworkError") {
      requestCallback?.abortOnCatastrophicError(); requestCallback = null
    }

    // Replaces the MainActivity.onActivityResult injection entirely —
    // expo-modules-core forwards the host Activity's onActivityResult to
    // every module that declares this. Confirmed present in this
    // expo-modules-core version (ModuleDefinitionBuilder.kt: OnActivityResult).
    OnActivityResult { _, payload ->
      val result = FaceTecSDK.getActivitySessionResult(payload.requestCode, payload.resultCode, payload.data)
      if (result != null) {
        isLiveSession = false
        sendEvent("onFaceTecExit", mapOf(
          "sessionStatus" to result.status.ordinal,
          "sessionStatusName" to result.status.name
        ))
      }
    }
  }

  override fun onSessionRequest(blob: String, callback: FaceTecSessionRequestProcessor.Callback) {
    requestCallback = callback
    sendEvent("onProcessSession", mapOf(
      "sessionRequestBlob" to blob,
      "externalDatabaseRefID" to latestExternalDatabaseRefID,
      "xUserAgentHeader" to FaceTecSDK.getTestingAPIHeader(),
      "xTestingAPIHeader" to FaceTecSDK.getTestingAPIHeader(),
      "isInitHandshake" to !isLiveSession
    ))
  }
}