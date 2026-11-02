pragma Singleton

import QtQuick

/**
 * Tasarım sistemi: iOS/macOS sistem renkleri, Inter yazı ölçeği (boyuta göre harf aralığı),
 * aralıklar, köşe yarıçapları ve hareket süreleri. `dark`, `scale` ve `motion` Main.qml'de
 * Plasma'nın ayarlarına bağlanır (renk düzeni, yazı boyutu, animasyon hızı).
 */
QtObject {
    id: theme

    property bool dark: false
    /** Plasma yazı boyutu ayarına göre çarpan (10 pt = 1). */
    property real scale: 1
    /** Plasma'da "animasyonlar anında" seçiliyse false: geçişler kısalır, sıçrama olmaz. */
    property bool motion: true

    // ---------- Renkler ----------
    readonly property color accent: dark ? "#0A84FF" : "#007AFF"
    readonly property color green: dark ? "#30D158" : "#34C759"
    readonly property color red: dark ? "#FF453A" : "#FF3B30"
    readonly property color orange: dark ? "#FF9F0A" : "#FF9500"
    readonly property color yellow: dark ? "#FFD60A" : "#FFCC00"

    /** Gruplu arka plan (sayfa zemini) ve üstündeki kartlar. */
    readonly property color background: dark ? "#000000" : "#F2F2F7"
    readonly property color card: dark ? "#1C1C1E" : "#FFFFFF"
    readonly property color cardElevated: dark ? "#2C2C2E" : "#FFFFFF"
    readonly property color sidebar: dark ? "#161618" : "#EBEBF0"

    readonly property color label: dark ? "#FFFFFF" : "#000000"
    readonly property color secondaryLabel: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.62) : Qt.rgba(60/255, 60/255, 67/255, 0.62)
    readonly property color tertiaryLabel: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.32) : Qt.rgba(60/255, 60/255, 67/255, 0.32)
    readonly property color separator: dark ? Qt.rgba(84/255, 84/255, 88/255, 0.65) : Qt.rgba(60/255, 60/255, 67/255, 0.2)
    /** Dolgu: arama kutusu, segment zemini, ikincil düğme. */
    readonly property color fill: dark ? Qt.rgba(118/255, 118/255, 128/255, 0.24) : Qt.rgba(118/255, 118/255, 128/255, 0.12)
    readonly property color fillStrong: dark ? Qt.rgba(118/255, 118/255, 128/255, 0.36) : Qt.rgba(118/255, 118/255, 128/255, 0.2)
    /** Satıra basılınca / üzerine gelinince. */
    readonly property color pressed: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(0, 0, 0, 0.03)
    readonly property color shadow: dark ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.12)

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ---------- Yazı ----------
    readonly property string family: "Inter Variable"

    /**
     * Yazı ölçeği (piksel, ağırlık, harf aralığı em). Büyük yazı negatif aralık ister,
     * küçük yazı hafif pozitif (Apple: "tracking is size-specific").
     */
    readonly property var type: ({
        largeTitle: { size: 30, weight: 700, tracking: -0.022 },
        title1:     { size: 24, weight: 700, tracking: -0.019 },
        title2:     { size: 20, weight: 650, tracking: -0.017 },
        title3:     { size: 17, weight: 600, tracking: -0.014 },
        headline:   { size: 14.5, weight: 600, tracking: -0.009 },
        body:       { size: 14.5, weight: 420, tracking: -0.009 },
        callout:    { size: 13.5, weight: 420, tracking: -0.006 },
        subhead:    { size: 13, weight: 420, tracking: -0.004 },
        footnote:   { size: 12, weight: 450, tracking: 0 },
        caption:    { size: 11, weight: 500, tracking: 0.006 },
    })

    // ---------- Ölçüler ----------
    readonly property real unit: 4 * scale
    readonly property real gap: 8 * scale
    readonly property real margin: 16 * scale
    readonly property real rowHeight: 44 * scale
    readonly property real radius: 12 * scale
    readonly property real radiusSmall: 8 * scale
    readonly property real contentMaxWidth: 620 * scale

    // ---------- Hareket ----------
    // Kritik sönümlü yay benzeri: hızlı başlar, aşmadan yerine oturur. Etkileşimlerde süreler
    // kısa tutulur; animasyon başladığı yerden (o anki değerden) sürer, kesilebilir.
    readonly property int quick: motion ? 140 : 0
    readonly property int standard: motion ? 280 : 0
    readonly property int slow: motion ? 420 : 0
    readonly property int easing: Easing.OutQuint
}
