package com.rehmatsg.liquid_toasts

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.dp

/**
 * SF Symbol name -> Material Symbols glyph resolver for the Android toast surface.
 *
 * The Dart API is platform-neutral and sends iOS SF Symbol names (e.g.
 * `checkmark.circle.fill`) over the wire in the toast's `icon` field. iOS renders
 * them natively; Android has no SF Symbol font, so we render the *closest*
 * Material Symbols "filled" glyph, drawn from code-defined path data (no font or
 * XML asset dependency).
 *
 * Resolution chain — mirrors iOS `IconView.validatedSymbol`
 * (liquid-toasts-swift/Sources/LiquidToasts/IconView.swift):
 *   1. explicit icon name -> its mapped vector (if we have one);
 *   2. an unmapped name    -> the toast's semantic default symbol (via
 *      [semanticDefault]);
 *   3. no semantic default (semantic `none`, or an unmapped default) -> null,
 *      and the caller collapses the leading slot.
 *
 * "Closest Material glyph" policy: every SF Symbol below is mapped to the nearest
 * Material Symbols FILLED 24px glyph. Path strings are real Material Icons filled
 * path data on a 24x24 viewport; where SF has no exact Material analog we pick the
 * closest well-known Material glyph rather than inventing coordinates. `.fill` and
 * non-fill variants of the same base name share one glyph (Material has a single
 * filled style), so they alias to the same path.
 *
 * The tint is applied by the caller at draw time; the vectors are built with a
 * black fill and cached on first resolve.
 */
object SymbolMap {

    private val cache = mutableMapOf<String, ImageVector>()

    /** Resolve an explicit SF Symbol name to a cached [ImageVector], or null if unmapped. */
    fun resolve(name: String?): ImageVector? {
        val key = name ?: return null
        paths[key] ?: return null
        return cache.getOrPut(key) { build(paths.getValue(key)) }
    }

    /**
     * The Material glyph for a toast semantic (wire names `success`/`error`/
     * `warning`/`info`/`none`). Mirrors iOS `ToastSemantic.defaultSymbol`
     * (Models.swift): success -> check-circle, error -> filled error/octagon,
     * warning -> warning triangle, info -> info circle, none -> null.
     */
    fun semanticDefault(semanticWireName: String): ImageVector? = when (semanticWireName) {
        "success" -> resolve("checkmark.circle.fill")
        "error" -> resolve("xmark.octagon.fill")
        "warning" -> resolve("exclamationmark.triangle.fill")
        "info" -> resolve("info.circle.fill")
        else -> null // "none" and anything unrecognized -> no icon
    }

    private fun build(d: String): ImageVector =
        ImageVector.Builder(
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = 24f,
            viewportHeight = 24f,
        ).addPath(
            pathData = PathParser().parsePathString(d).toNodes(),
            fill = SolidColor(Color.Black),
        ).build()

    // SF Symbol name -> Material Symbols FILLED 24px path data.
    // Base names and their `.fill` variants share the single Material filled glyph.
    private val paths: Map<String, String> = buildMap {
        // ---- Semantic defaults ------------------------------------------------
        // success: SF checkmark.circle.fill -> Material check_circle (filled)
        put(
            "checkmark.circle.fill",
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z",
        )
        // error: SF xmark.octagon.fill -> Material error (filled circle with !),
        // the canonical Material "error" glyph — the closest filled error mark.
        put(
            "xmark.octagon.fill",
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z",
        )
        // warning: SF exclamationmark.triangle.fill -> Material warning (filled)
        put(
            "exclamationmark.triangle.fill",
            "M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z",
        )
        // info: SF info.circle.fill -> Material info (filled)
        put(
            "info.circle.fill",
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z",
        )

        // ---- Symbols used by example/lib --------------------------------------
        // icloud.fill -> Material cloud (filled)
        val cloud =
            "M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96z"
        put("icloud.fill", cloud)
        put("icloud", cloud)
        // arrow.up.circle(.fill) -> Material arrow_circle_up (filled)
        val arrowUpCircle =
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4 9.59L14.59 13 13 11.41V16h-2v-4.59L9.41 13 8 11.59 12 7.59l4 4z"
        put("arrow.up.circle", arrowUpCircle)
        put("arrow.up.circle.fill", arrowUpCircle)
        // arrow.down.circle(.fill) -> Material arrow_circle_down (filled)
        val arrowDownCircle =
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-4 9.59L9.41 11 11 12.59V8h2v4.59L14.59 11 16 12.41 12 16.41 8 12.41z"
        put("arrow.down.circle", arrowDownCircle)
        put("arrow.down.circle.fill", arrowDownCircle)
        // wifi -> Material wifi (filled)
        put(
            "wifi",
            "M1 9l2 2c4.97-4.97 13.03-4.97 18 0l2-2C16.93 2.93 7.08 2.93 1 9zm8 8l3 3 3-3c-1.65-1.66-4.34-1.66-6 0zm-4-4l2 2c2.76-2.76 7.24-2.76 10 0l2-2C15.14 9.14 8.87 9.14 5 13z",
        )
        // archivebox.fill -> Material archive (filled)
        val archive =
            "M20.54 5.23l-1.39-1.68C18.88 3.21 18.47 3 18 3H6c-.47 0-.88.21-1.16.55L3.46 5.23C3.17 5.57 3 6.02 3 6.5V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6.5c0-.48-.17-.93-.46-1.27zM12 17.5L6.5 12H10v-2h4v2h3.5L12 17.5zM5.12 5l.82-1h12l.93 1H5.12z"
        put("archivebox.fill", archive)
        put("archivebox", archive)
        // link -> Material link (filled)
        put(
            "link",
            "M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z",
        )
        // calendar -> Material calendar_today / event (filled)
        val calendar =
            "M20 3h-1V1h-2v2H7V1H5v2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 18H4V8h16v13z"
        put("calendar", calendar)
        // calendar.badge.clock -> Material edit_calendar / event closest filled; reuse calendar glyph
        put("calendar.badge.clock", calendar)
        // trash(.fill) -> Material delete (filled)
        val delete =
            "M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"
        put("trash", delete)
        put("trash.fill", delete)
        // text.alignleft -> Material format_align_left (filled)
        put(
            "text.alignleft",
            "M15 15H3v2h12v-2zm0-8H3v2h12V7zM3 13h18v-2H3v2zm0 8h18v-2H3v2zM3 3v2h18V3H3z",
        )
        // square.and.pencil -> Material edit / create (filled)
        put(
            "square.and.pencil",
            "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z",
        )
        // sparkles -> Material auto_awesome (filled)
        put(
            "sparkles",
            "M19 9l1.25-2.75L23 5l-2.75-1.25L19 1l-1.25 2.75L15 5l2.75 1.25L19 9zm-7.5.5L9 4 6.5 9.5 1 12l5.5 2.5L9 20l2.5-5.5L17 12l-5.5-2.5zM19 15l-1.25 2.75L15 19l2.75 1.25L19 23l1.25-2.75L23 19l-2.75-1.25z",
        )
        // chart.bar.fill -> Material bar_chart (filled)
        val barChart = "M5 9.2h3V19H5V9.2zM10.6 5h2.8v14h-2.8V5zm5.6 8H19v6h-2.8v-6z"
        put("chart.bar.fill", barChart)
        put("chart.bar", barChart)
        // bubble.left.fill -> Material chat (filled)
        val chat =
            "M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"
        put("bubble.left.fill", chat)
        put("bubble.left", chat)

        // ---- Popular extras ---------------------------------------------------
        // bell(.fill) -> Material notifications (filled)
        val bell =
            "M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"
        put("bell.fill", bell)
        put("bell", bell)
        // star(.fill) -> Material star (filled)
        val star =
            "M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"
        put("star.fill", star)
        put("star", star)
        // heart(.fill) -> Material favorite (filled)
        val heart =
            "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
        put("heart.fill", heart)
        put("heart", heart)
        // person(.fill) -> Material person (filled)
        val person =
            "M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"
        put("person.fill", person)
        put("person", person)
        // person.circle(.fill) -> Material account_circle (filled)
        val accountCircle =
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"
        put("person.circle.fill", accountCircle)
        put("person.circle", accountCircle)
        // gear / gearshape(.fill) -> Material settings (filled)
        val settings =
            "M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"
        put("gear", settings)
        put("gearshape.fill", settings)
        put("gearshape", settings)
        // lock(.fill) -> Material lock (filled)
        put(
            "lock.fill",
            "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z",
        )
        put("lock", "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z")
        // lock.open(.fill) -> Material lock_open (filled)
        val lockOpen =
            "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6h1.9c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z"
        put("lock.open.fill", lockOpen)
        put("lock.open", lockOpen)
        // envelope(.fill) -> Material email (filled)
        val email =
            "M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"
        put("envelope.fill", email)
        put("envelope", email)
        // doc(.fill) -> Material description (filled)
        val description =
            "M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"
        put("doc.fill", description)
        put("doc", description)
        // folder(.fill) -> Material folder (filled)
        val folder =
            "M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"
        put("folder.fill", folder)
        put("folder", folder)
        // camera(.fill) -> Material photo_camera (filled)
        val camera =
            "M12 15.2c1.77 0 3.2-1.43 3.2-3.2s-1.43-3.2-3.2-3.2-3.2 1.43-3.2 3.2 1.43 3.2 3.2 3.2zM9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"
        put("camera.fill", camera)
        put("camera", camera)
        // photo -> Material image (filled)
        put(
            "photo",
            "M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z",
        )
        // mic(.fill) -> Material mic (filled)
        val mic =
            "M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5-3c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"
        put("mic.fill", mic)
        put("mic", mic)
        // play(.fill) -> Material play_arrow (filled)
        put("play.fill", "M8 5v14l11-7z")
        put("play", "M8 5v14l11-7z")
        // pause(.fill) -> Material pause (filled)
        put("pause.fill", "M6 19h4V5H6v14zm8-14v14h4V5h-4z")
        put("pause", "M6 19h4V5H6v14zm8-14v14h4V5h-4z")
        // bolt(.fill) -> Material bolt (filled)
        val bolt = "M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z"
        put("bolt.fill", bolt)
        put("bolt", bolt)
        // flame(.fill) -> Material local_fire_department (filled)
        val flame =
            "M13.5 0.67s.74 2.65.74 4.8c0 2.06-1.35 3.73-3.41 3.73-2.07 0-3.63-1.67-3.63-3.73l.03-.36C5.21 7.51 4 10.62 4 14c0 4.42 3.58 8 8 8s8-3.58 8-8C20 8.61 17.41 3.8 13.5.67zM11.71 19c-1.78 0-3.22-1.4-3.22-3.14 0-1.62 1.05-2.76 2.81-3.12 1.77-.36 3.6-1.21 4.62-2.58.39 1.29.59 2.65.59 4.04 0 2.65-2.15 4.8-4.8 4.8z"
        put("flame.fill", flame)
        put("flame", flame)
        // clock(.fill) -> Material access_time_filled / schedule (filled)
        val clock =
            "M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"
        put("clock.fill", clock)
        put("clock", clock)
        // magnifyingglass -> Material search (filled)
        put(
            "magnifyingglass",
            "M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z",
        )
        // paperplane(.fill) -> Material send (filled)
        val send = "M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"
        put("paperplane.fill", send)
        put("paperplane", send)
        // cart(.fill) -> Material shopping_cart (filled)
        val cart =
            "M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z"
        put("cart.fill", cart)
        put("cart", cart)
        // creditcard(.fill) -> Material credit_card (filled)
        val creditCard =
            "M20 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V6c0-1.11-.89-2-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z"
        put("creditcard.fill", creditCard)
        put("creditcard", creditCard)
        // hand.thumbsup(.fill) -> Material thumb_up (filled)
        val thumbUp =
            "M1 21h4V9H1v12zm22-11c0-1.1-.9-2-2-2h-6.31l.95-4.57.03-.32c0-.41-.17-.79-.44-1.06L14.17 1 7.59 7.59C7.22 7.95 7 8.45 7 9v10c0 1.1.9 2 2 2h9c.83 0 1.54-.5 1.84-1.22l3.02-7.05c.09-.23.14-.47.14-.73v-2z"
        put("hand.thumbsup.fill", thumbUp)
        put("hand.thumbsup", thumbUp)
        // checkmark -> Material check (filled/stroke as path)
        put("checkmark", "M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z")
        // xmark -> Material close (filled/stroke as path)
        put(
            "xmark",
            "M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z",
        )
        // plus.circle(.fill) -> Material add_circle (filled)
        val addCircle =
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"
        put("plus.circle.fill", addCircle)
        put("plus.circle", addCircle)
        // minus.circle(.fill) -> Material remove_circle (filled)
        val removeCircle =
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11H7v-2h10v2z"
        put("minus.circle.fill", removeCircle)
        put("minus.circle", removeCircle)
        // arrow.clockwise -> Material refresh (filled/stroke as path)
        put(
            "arrow.clockwise",
            "M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z",
        )
        // wand.and.stars -> Material auto_fix_high (filled)
        put(
            "wand.and.stars",
            "M7.5 5.6L10 7 8.6 4.5 10 2 7.5 3.4 5 2l1.4 2.5L5 7zm12 9.8L17 14l1.4 2.5L17 19l2.5-1.4L22 19l-1.4-2.5L22 14zM22 2l-2.5 1.4L17 2l1.4 2.5L17 7l2.5-1.4L22 7l-1.4-2.5zm-7.63 5.29c-.39-.39-1.02-.39-1.41 0L1.29 18.96c-.39.39-.39 1.02 0 1.41l2.34 2.34c.39.39 1.02.39 1.41 0L16.7 11.05c.39-.39.39-1.02 0-1.41l-2.33-2.35zm-1.03 5.49l-2.12-2.12 2.44-2.44 2.12 2.12-2.44 2.44z",
        )
        // moon(.fill) -> Material dark_mode (filled)
        val moon =
            "M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9c0-.46-.04-.92-.1-1.36-.98 1.37-2.58 2.26-4.4 2.26-2.98 0-5.4-2.42-5.4-5.4 0-1.81.89-3.42 2.26-4.4-.44-.06-.9-.1-1.36-.1z"
        put("moon.fill", moon)
        put("moon", moon)
        // sun.max(.fill) -> Material light_mode (filled)
        val sun =
            "M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58c-.39-.39-1.03-.39-1.41 0-.39.39-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37c-.39-.39-1.03-.39-1.41 0-.39.39-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0 .39-.39.39-1.03 0-1.41l-1.06-1.06zm1.06-10.96c.39-.39.39-1.03 0-1.41-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06zM7.05 18.36c.39-.39.39-1.03 0-1.41-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06z"
        put("sun.max.fill", sun)
        put("sun.max", sun)
        // cloud(.fill) -> Material cloud (filled) — same glyph as icloud
        put("cloud.fill", cloud)
        put("cloud", cloud)
        // globe -> Material public / language (filled)
        put(
            "globe",
            "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z",
        )
        // house(.fill) -> Material home (filled)
        val home = "M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"
        put("house.fill", home)
        put("house", home)
    }
}
