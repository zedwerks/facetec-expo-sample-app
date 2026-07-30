import UIKit
import FaceTecSDK

class FaceTecConfig {

    public static func getCustomization() -> FaceTecCustomization {
        let customization = FaceTecCustomization()
        let primary = UIColor(hexString: "#006F4C")
        let white   = UIColor.white
        let bg      = UIColor(hexString: "#f2f2f7")

        // ── Frame ─────────────────────────────────────────────────────────────
        customization.frameCustomization.cornerRadius       = 10
        customization.frameCustomization.backgroundColor    = bg
        customization.frameCustomization.borderColor        = primary

        // ── Oval ──────────────────────────────────────────────────────────────
        customization.ovalCustomization.strokeColor         = primary
        customization.ovalCustomization.progressColor1      = primary
        customization.ovalCustomization.progressColor2      = primary

        // ── Feedback bar ──────────────────────────────────────────────────────
        let gradient = CAGradientLayer()
        gradient.colors    = [primary.cgColor, primary.cgColor]
        gradient.locations = [0, 1]
        customization.feedbackCustomization.backgroundColor = gradient
        customization.feedbackCustomization.textColor       = white

        // ── Guidance (instructions screens) ───────────────────────────────────
        customization.guidanceCustomization.backgroundColors                = [bg, bg]
        customization.guidanceCustomization.foregroundColor                 = primary
        customization.guidanceCustomization.headerFont                      = UIFont.boldSystemFont(ofSize: 20)
        customization.guidanceCustomization.subtextFont                     = UIFont.systemFont(ofSize: 14)
        customization.guidanceCustomization.buttonBackgroundNormalColor     = primary
        customization.guidanceCustomization.buttonBackgroundHighlightColor  = UIColor(hexString: "#555555")
        customization.guidanceCustomization.buttonBackgroundDisabledColor   = UIColor(hexString: "#999999")
        customization.guidanceCustomization.buttonTextNormalColor           = white
        customization.guidanceCustomization.buttonTextHighlightColor        = white
        customization.guidanceCustomization.buttonTextDisabledColor         = white
        customization.guidanceCustomization.retryScreenImageBorderColor     = primary
        customization.guidanceCustomization.retryScreenOvalStrokeColor      = primary

        // ── Result screen ─────────────────────────────────────────────────────
        customization.resultScreenCustomization.backgroundColors                  = [bg, bg]
        customization.resultScreenCustomization.foregroundColor                   = primary
        customization.resultScreenCustomization.activityIndicatorColor            = primary
        customization.resultScreenCustomization.resultAnimationBackgroundColor    = primary
        customization.resultScreenCustomization.resultAnimationForegroundColor    = white
        customization.resultScreenCustomization.uploadProgressFillColor           = primary
        customization.resultScreenCustomization.uploadProgressTrackColor          = UIColor(hexString: "#cccccc")

        // ── Cancel button ─────────────────────────────────────────────────────
        customization.cancelButtonCustomization.customImage = UIImage(named: "FaceTec_cancel")
        customization.cancelButtonCustomization.location    = .topLeft

        // ── Overlay ───────────────────────────────────────────────────────────
        customization.overlayCustomization.backgroundColor  = white
        customization.overlayCustomization.brandingImage    = UIImage(named: "Alberta")
        customization.overlayCustomization.showBrandingImage = true

        // ── ID Scan ───────────────────────────────────────────────────────────
        customization.idScanCustomization.selectionScreenBackgroundColors   = [bg, bg]
        customization.idScanCustomization.selectionScreenForegroundColor    = primary
        customization.idScanCustomization.reviewScreenBackgroundColors      = [bg, bg]
        customization.idScanCustomization.reviewScreenForegroundColor       = white
        customization.idScanCustomization.reviewScreenTextBackgroundColor   = primary
        customization.idScanCustomization.captureScreenBackgroundColor      = bg
        customization.idScanCustomization.captureScreenForegroundColor      = white
        customization.idScanCustomization.captureScreenTextBackgroundColor  = primary
        customization.idScanCustomization.captureFrameStrokeColor           = primary
        customization.idScanCustomization.buttonBackgroundNormalColor       = primary
        customization.idScanCustomization.buttonBackgroundHighlightColor    = UIColor(hexString: "#555555")
        customization.idScanCustomization.buttonBackgroundDisabledColor     = UIColor(hexString: "#999999")
        customization.idScanCustomization.buttonTextNormalColor             = white
        customization.idScanCustomization.buttonTextHighlightColor          = white
        customization.idScanCustomization.buttonTextDisabledColor           = white

        return customization
    }
}