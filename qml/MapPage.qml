import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtPositioning
import org.kde.kirigami as Kirigami
import KocaeliUlasim
import "ui"
import "Fmt.js" as Fmt
import "LiveSync.js" as Live

/**
 * Harita (iOS Haritalar gibi): tam ekran harita, üstte yüzen başlık kartı, durağa tıklayınca
 * altta önizleme kartı (ad + yaklaşan araçlar, görünürken 20 sn'de bir). Görünen bölgenin
 * ortasına yakın duraklar kaydırma bittikten 800 ms sonra istenir.
 */
Kirigami.Page {
    id: page

    title: "Harita"
    padding: 0
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
    Kirigami.ColumnView.fillWidth: true
    background: Rectangle { color: Theme.background }

    readonly property bool live: page.visible && applicationWindow().foreground
    /** Ağ yanıtı geldiğinde sayfa kapanmış olabilir; geri çağrılar bunu denetler. */
    property bool alive: true
    Component.onDestruction: alive = false
    property var stops: []
    property var preview: null
    property var previewArrivals: null
    // Kartın araç satırları kimliğe göre yerinde güncellenir.
    onPreviewArrivalsChanged: Live.sync(previewModel, previewArrivals ? previewArrivals.vehicles.slice(0, 3) : [], Live.vehicleKey)
    ListModel { id: previewModel }
    property bool previewLoading: false
    property var lastQueryCenter: null

    function loadStops(center) {
        if (lastQueryCenter && lastQueryCenter.distanceTo(center) < 120)
            return
        lastQueryCenter = center
        const self = page
        Api.closestStops(center.latitude, center.longitude, (err, list) => {
            if (!self.alive) return
            if (err) {
                applicationWindow().toast(err)
                return
            }
            // Önceki duraklar korunur (kaydırırken işaretçiler kaybolmasın), en çok 300.
            const byId = {}
            for (const s of self.stops) byId[s.id] = s
            for (const s of list) byId[s.id] = s
            self.stops = Object.values(byId).slice(-300)
        })
    }

    function loadPreview() {
        if (!preview) return
        const id = preview.id
        previewLoading = true
        const self = page
        Api.stopArrivals(id, (err, a) => {
            if (!self.alive || !self.preview || self.preview.id !== id) return
            self.previewLoading = false
            self.previewArrivals = err ? null : a
        })
    }

    function closePreview() {
        preview = null
        previewArrivals = null
    }

    Component.onCompleted: {
        map.goTo(applicationWindow().location, 16)
        loadStops(applicationWindow().location)
    }

    Timer {
        interval: 20000
        repeat: true
        running: page.live && !!page.preview
        onTriggered: page.loadPreview()
    }
    Shortcut {
        sequence: "Esc"
        enabled: page.visible && !!page.preview
        onActivated: page.closePreview()
    }

    TransitMap {
        id: map
        anchors.fill: parent
        stops: page.stops
        highlightStopId: page.preview ? page.preview.id : ""
        vehicles: page.previewArrivals ? page.previewArrivals.vehicles : []
        myLocation: applicationWindow().hasFix ? applicationWindow().location : QtPositioning.coordinate()
        onViewportSettled: center => { if (page.live) page.loadStops(center) }
        onStopClicked: stop => {
            page.preview = stop
            page.previewArrivals = null
            page.loadPreview()
        }
        onLocateRequested: if (!applicationWindow().hasFix)
            map.goTo(applicationWindow().location, Math.max(map.zoomLevel, 16))
    }

    /** Yüzen cam kart: altındaki haritanın bulanık kopyası + yarı saydam zemin + ince kenar. */
    component Glass: Item {
        id: glass
        default property alias content: inner.data
        property real radius: Theme.radius * 1.25

        ShaderEffectSource {
            id: snap
            sourceItem: map
            sourceRect: Qt.rect(glass.x, glass.y, glass.width, glass.height)
            visible: false
            live: glass.visible
        }
        MultiEffect {
            anchors.fill: parent
            source: snap
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.3
            maskEnabled: true
            maskSource: shapeMask
        }
        Rectangle {
            id: shapeMask
            anchors.fill: parent
            radius: glass.radius
            visible: false
            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent
            radius: glass.radius
            color: Theme.tint(Theme.card, Theme.dark ? 0.72 : 0.78)
            border.width: 1 / Screen.devicePixelRatio
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
        }
        Item {
            id: inner
            anchors.fill: parent
        }
    }

    // ---------- Üst kart ----------
    Glass {
        id: topCard
        x: Theme.margin
        y: Theme.margin
        width: Math.min(page.width - Theme.margin * 2, topRow.implicitWidth + Theme.margin * 1.5)
        height: Math.round(48 * Theme.scale)
        radius: height / 2

        RowLayout {
            id: topRow
            anchors.fill: parent
            anchors.leftMargin: Theme.margin * 0.75
            anchors.rightMargin: Theme.unit * 1.5
            spacing: Theme.gap
            Symbol { name: "map"; filled: true; size: 20; color: Theme.accent }
            Txt { text: "Harita"; style: "headline" }
            Txt {
                text: page.stops.length > 0 ? "· " + page.stops.length + " durak" : ""
                style: "subhead"
                secondary: true
                tabular: true
            }
            Item { implicitWidth: Theme.unit }
            PillButton {
                text: "Burayı konumum yap"
                icon: "pinDrop"
                compact: true
                onClicked: {
                    const c = map.center
                    Store.setHome(c.latitude, c.longitude, true)
                    applicationWindow().toast("Konumunuz kaydedildi")
                }
            }
        }
    }

    // ---------- Önizleme kartı ----------
    Glass {
        id: card
        readonly property real targetY: page.height - height - Theme.margin
        visible: opacity > 0
        opacity: page.preview ? 1 : 0
        x: Theme.margin
        y: page.preview ? targetY : page.height
        width: Math.min(page.width - Theme.margin * 2 - Math.round(60 * Theme.scale), Math.round(420 * Theme.scale))
        height: cardBody.implicitHeight + Theme.margin * 1.5
        // Alttan yükselir, aynı yoldan iner (kesilebilir).
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.standard } }

        ColumnLayout {
            id: cardBody
            x: Theme.margin
            y: Theme.margin * 0.75
            width: parent.width - Theme.margin * 2
            spacing: Theme.gap

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap * 1.5
                IconTile { icon: "place"; tone: Theme.red; size: 34 }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Txt { text: page.preview ? page.preview.name : ""; style: "title3"; Layout.fillWidth: true }
                    Txt {
                        text: page.preview && page.preview.distance !== undefined
                              ? Api.formatDistance(page.preview.distance) + " uzaklıkta" : "Durak"
                        style: "subhead"
                        secondary: true
                    }
                }
                IconButton {
                    icon: "close"
                    circle: true
                    color: Theme.secondaryLabel
                    size: 28
                    tooltip: "Kapat"
                    onClicked: page.closePreview()
                }
            }

            BadgeRow {
                Layout.fillWidth: true
                visible: badges.length > 0
                badges: page.preview && page.preview.routes ? page.preview.routes : []
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1 / Screen.devicePixelRatio; color: Theme.separator }

            Txt {
                visible: page.previewLoading && !page.previewArrivals
                text: "Yaklaşan araçlar yükleniyor…"
                style: "subhead"
                secondary: true
            }
            Txt {
                visible: !!page.previewArrivals && page.previewArrivals.vehicles.length === 0
                text: "Şu an yaklaşan araç yok"
                style: "subhead"
                secondary: true
            }
            Repeater {
                model: previewModel
                delegate: RowLayout {
                    required property string json
                    readonly property var modelData: JSON.parse(json)
                    NumberAnimation on opacity { from: 0; to: 1; duration: Theme.standard; easing.type: Theme.easing }
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    RouteBadge { code: modelData.routeCode; badgeColor: modelData.color; textColor: modelData.textColor; minWidth: Math.round(46 * Theme.scale) }
                    Txt { text: modelData.headSign || ""; style: "subhead"; Layout.fillWidth: true }
                    SwapText {
                        value: Fmt.shortEta(modelData)
                        style: "headline"
                        tabular: true
                        color: modelData.stopsAway !== undefined && modelData.stopsAway <= 2 ? Theme.green : Theme.label
                    }
                }
            }

            PillButton {
                text: "Durağı aç"
                icon: "arrowForward"
                kind: "filled"
                Layout.fillWidth: true
                Layout.topMargin: Theme.unit
                onClicked: applicationWindow().openStop(page.preview)
            }
        }
    }
}
