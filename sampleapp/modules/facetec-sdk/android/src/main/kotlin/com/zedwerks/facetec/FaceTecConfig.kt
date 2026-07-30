package com.zedwerks.facetec

import android.graphics.Color
import android.graphics.Typeface
import com.facetec.sdk.FaceTecCustomization
// R is this module's own generated class (com.zedwerks.facetec.R) —
// no import needed. A library module can't import the app module's R class
// (dependencies only flow app → library), so logo.png must live in this
// module's own res/drawable/, not the app's.

/**
 * FaceTecConfig.kt
 *
 * Android equivalent of FaceTecConfig.swift.
 *
 * KEY DIFFERENCES FROM iOS:
 *  - Colors are ARGB `Int` (Color.parseColor), not UIColor.
 *  - `backgroundColors` on Android customization classes is a SINGLE Int,
 *    not an array of two colors. Since the iOS config uses [bg, bg] /
 *    [primary, primary] (identical start/end — i.e. solid colors, not true
 *    gradients), this maps 1:1 to a single solid color on Android.
 *  - Fonts are android.graphics.Typeface, not UIFont. Typeface.DEFAULT_BOLD /
 *    Typeface.DEFAULT used as equivalents for boldSystemFont / systemFont.
 *  - Images are drawable resource Ints (R.drawable.xxx), not UIImage(named:).
 *    Placeholder R.drawable references below — update to your actual
 *    drawable resource names (case-sensitive, must exist in res/drawable).
 *  - FaceTecOvalCustomization on Android does not expose progressColor1/2 —
 *    only `strokeColor`. The iOS config sets strokeColor, progressColor1,
 *    and progressColor2 all to `primary`, so on Android setting just
 *    `strokeColor = primary` is the equivalent (no progress-specific color
 *    split is available in this SDK version).
 *  - FaceTecCancelButtonCustomization has no `.location` enum property;
 *    instead it exposes setLocation(...)/getLocation() and
 *    setCustomLocation(Rect)/getCustomLocation(). The exact setLocation
 *    signature/enum wasn't available from the Javadoc summary — check
 *    FaceTecCancelButtonCustomization.html for the parameter type if the
 *    call below doesn't compile, and adjust accordingly. Left as a TODO.
 */
object FaceTecConfig {

    @JvmStatic
    fun getCustomization(): FaceTecCustomization {
        val customization = FaceTecCustomization()

        val primary = Color.parseColor("#006F4C")
        val white   = Color.WHITE
        val bg      = Color.parseColor("#f2f2f7")
        val highlight = Color.parseColor("#555555")
        val disabled   = Color.parseColor("#999999")
        val trackGray  = Color.parseColor("#cccccc")

        // ── Frame ─────────────────────────────────────────────────────────────
        customization.frameCustomization.cornerRadius    = 10
        customization.frameCustomization.backgroundColor = bg
        customization.frameCustomization.borderColor     = primary

        // ── Oval ──────────────────────────────────────────────────────────────
        // NOTE: Android has no progressColor1/progressColor2 — strokeColor
        // covers both the iOS strokeColor and progressColor1/2 use cases.
        customization.ovalCustomization.strokeColor = primary

        // ── Feedback bar ──────────────────────────────────────────────────────
        // iOS used a CAGradientLayer with [primary, primary] — i.e. solid.
        // Android backgroundColors is a single Int.
        customization.feedbackCustomization.backgroundColors = primary
        customization.feedbackCustomization.textColor        = white

        // ── Guidance (instructions screens) ────────────────────────────────────
        customization.guidanceCustomization.backgroundColors = bg
        customization.guidanceCustomization.foregroundColor  = primary
        customization.guidanceCustomization.headerFont       = Typeface.DEFAULT_BOLD
        customization.guidanceCustomization.subtextFont      = Typeface.DEFAULT

        customization.guidanceCustomization.buttonBackgroundNormalColor    = primary
        customization.guidanceCustomization.buttonBackgroundHighlightColor = highlight
        customization.guidanceCustomization.buttonBackgroundDisabledColor  = disabled
        customization.guidanceCustomization.buttonTextNormalColor          = white
        customization.guidanceCustomization.buttonTextHighlightColor       = white
        customization.guidanceCustomization.buttonTextDisabledColor        = white

        customization.guidanceCustomization.retryScreenImageBorderColor = primary
        customization.guidanceCustomization.retryScreenOvalStrokeColor  = primary

        // ── Result screen ───────────────────────────────────────────────────────
        customization.resultScreenCustomization.backgroundColors               = bg
        customization.resultScreenCustomization.foregroundColor                = primary
        customization.resultScreenCustomization.activityIndicatorColor         = primary
        customization.resultScreenCustomization.resultAnimationBackgroundColor = primary
        customization.resultScreenCustomization.resultAnimationForegroundColor = white
        customization.resultScreenCustomization.uploadProgressFillColor        = primary
        customization.resultScreenCustomization.uploadProgressTrackColor       = trackGray

        // ── Cancel button ─────────────────────────────────────────────────────
        // TODO: customImage expects a drawable resource Int, not a UIImage.
        // Replace R.drawable.facetec_cancel with your actual drawable resource
        // (e.g. copy the FaceTec_cancel asset into res/drawable/ first).
        // customization.cancelButtonCustomization.customImage = R.drawable.facetec_cancel

        customization.cancelButtonCustomization.setLocation(
            com.facetec.sdk.FaceTecCancelButtonCustomization.ButtonLocation.TOP_LEFT
        )

        // ── Overlay ──────────────────────────────────────────────────────────
        customization.overlayCustomization.backgroundColor = white
        customization.overlayCustomization.brandingImage = R.drawable.alberta
        customization.overlayCustomization.showBrandingImage = true

        // ── ID Scan ──────────────────────────────────────────────────────────
        customization.idScanCustomization.selectionScreenBackgroundColors = bg
        customization.idScanCustomization.selectionScreenForegroundColor  = primary
        customization.idScanCustomization.reviewScreenBackgroundColors    = bg
        customization.idScanCustomization.reviewScreenForegroundColor     = white
        customization.idScanCustomization.reviewScreenTextBackgroundColor = primary
        customization.idScanCustomization.captureScreenBackgroundColor    = bg
        customization.idScanCustomization.captureScreenForegroundColor    = white
        customization.idScanCustomization.captureScreenTextBackgroundColor = primary
        customization.idScanCustomization.captureFrameStrokeColor          = primary

        customization.idScanCustomization.buttonBackgroundNormalColor    = primary
        customization.idScanCustomization.buttonBackgroundHighlightColor = highlight
        customization.idScanCustomization.buttonBackgroundDisabledColor  = disabled
        customization.idScanCustomization.buttonTextNormalColor          = white
        customization.idScanCustomization.buttonTextHighlightColor       = white
        customization.idScanCustomization.buttonTextDisabledColor        = white

        return customization
    }
}