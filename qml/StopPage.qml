import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import KocaeliUlasim
import "ui"
import "Fmt.js" as Fmt
import "LiveSync.js" as Live

/** Durak: yaklaşan canlı araçlar (20 sn'de bir, yalnızca görünürken) ve geçen hatlar. */
PageScaffold {
    id: page

    required property string stopId
    property string stopName
    property real stopLat: NaN
    property real stopLng: NaN

    property var arrivals: null
    property string error
    property bool loading: false
    property date now: new Date()

    readonly property bool live: page.visible && applicationWindow().foreground
    readonly property bool favorite: Store.favoriteStops.some(s => s.id === stopId)
    readonly property string displayName: arrivals && arrivals.stopName ? arrivals.stopName : stopName
    readonly property var stopInfo: ({
        kind: "stop",
        stopId: stopId,
        name: displayName,
        lat: arrivals && arrivals.lat !== undefined ? arrivals.lat : (isNaN(stopLat) ? null : stopLat),
        lng: arrivals && arrivals.lng !== undefined ? arrivals.lng : (isNaN(stopLng) ? null : stopLng),
    })

    /** Bu duraktan geçen hatlar: API'nin hat listesi + yaklaşan araçların hatları. */
    readonly property var passingRoutes: {
        if (!arrivals) return []
        const seen = {}
        const out = []
        for (const t of arrivals.nextTrips) {
            if (!t.routeCode || seen[t.routeCode]) continue
            seen[t.routeCode] = true
            out.push(t)
        }
        for (const v of arrivals.vehicles) {
            if (!v.routeCode || seen[v.routeCode]) continue
            seen[v.routeCode] = true
            out.push({ routeCode: v.routeCode, headSign: v.headSign, color: v.color, textColor: v.textColor, time: "" })
        }
        return out
    }

    // Yaklaşan araçlar kimliğe göre yerinde güncellenir (delegeler yeniden kurulmaz).
    onArrivalsChanged: Live.sync(vehicleModel, arrivals ? arrivals.vehicles : [], Live.vehicleKey)

    title: displayName || "Durak"
    subtitle: arrivals ? "Güncellendi " + Fmt.relative(arrivals.fetchedAt, now) : (loading ? "Yükleniyor…" : "")

    function refresh() {
        loading = true
        const self = page
        Api.stopArrivals(stopId, (err, a) => {
            if (!self.alive) return // sayfa bu arada kapandı
            self.loading = false
            self.error = err
            if (!err)
                self.arrivals = a
        })
    }

    function waitFor(route) {
        applicationWindow().setupTracking({
            mode: "wait",
            routeCode: route.routeCode,
            routeColor: route.color,
            routeTextColor: route.textColor,
            target: page.stopInfo,
            stopId: page.stopId,
        })
    }

    function trackVehicle(v) {
        applicationWindow().setupTracking({
            mode: "vehicle",
            vehicle: v,
            target: page.stopInfo,
            // Bu araç durağa N durak uzaktaysa en çok N−1 durak kala haber verilebilir.
            maxWarn: v.stopsAway !== undefined && v.stopsAway !== null ? Math.max(0, v.stopsAway - 1) : 40,
        })
    }

    onLiveChanged: if (live) refresh()
    Component.onCompleted: if (live) refresh()

    Timer {
        interval: 20000
        repeat: true
        running: page.live
        onTriggered: page.refresh()
    }
    Timer {
        interval: 15000
        repeat: true
        running: page.live
        onTriggered: page.now = new Date()
    }
    Shortcut {
        sequences: [StandardKey.Refresh]
        enabled: page.visible
        onActivated: page.refresh()
    }

    barActions: [
        Spinner { running: page.loading && !!page.arrivals; size: 16; anchors.verticalCenter: parent.verticalCenter },
        IconButton {
            icon: "refresh"
            tooltip: "Yenile"
            onClicked: page.refresh()
        }
    ]

    titleLeading: IconTile { icon: "place"; tone: Theme.red; size: 40 }

    headerExtra: Row {
        spacing: Theme.gap
        PillButton {
            text: page.favorite ? "Favoride" : "Favori"
            icon: "star"
            iconFilled: page.favorite
            tint: page.favorite ? Theme.orange : Theme.accent
            onClicked: Store.toggleFavoriteStop(page.stopId, page.displayName)
        }
        PillButton {
            text: "Haber ver"
            icon: "bell"
            enabled: page.passingRoutes.length > 0 && Tracker.canStart
            onClicked: routeSheetItem.open()
        }
    }

    /** Geliştirme kancası (KU_EVAL) için erişim. */
    readonly property alias routeSheet: routeSheetItem

    ActionSheet {
        id: routeSheetItem
        title: "Hangi hat gelince haber verilsin?"
        model: page.passingRoutes
        onChosen: item => page.waitFor(item)
    }

    Banner {
        visible: !!page.error
        kind: "error"
        text: page.error
        actionText: "Yeniden dene"
        Layout.leftMargin: Theme.margin
        Layout.rightMargin: Theme.margin
        onAction: page.refresh()
    }

    Section {
        title: "Yaklaşan araçlar"
        footer: page.arrivals && page.arrivals.vehicles.length > 0 ? "Liste 20 saniyede bir kendiliğinden yenilenir. Satıra tıklayınca hat bu yönde açılır." : ""

        Repeater {
            model: !page.arrivals && page.loading ? 3 : 0
            delegate: SkeletonRow { required property int index; isLast: index === 2 }
        }
        EmptyState {
            visible: !!page.arrivals && page.arrivals.vehicles.length === 0
            icon: "schedule"
            title: "Şu an yaklaşan araç yok"
            message: "Liste 20 saniyede bir kendiliğinden yenilenir."
        }
        ListModel { id: vehicleModel }
        Repeater {
            model: vehicleModel
            delegate: ListRow {
                id: row
                required property string json
                readonly property var modelData: JSON.parse(json)
                // Yeni gelen satır kısa solmayla girer.
                NumberAnimation on opacity { from: 0; to: 1; duration: Theme.standard; easing.type: Theme.easing }
                readonly property string trackingId: Tracker.trackings.length >= 0 ? Tracker.trackingFor(modelData.vehicleId, modelData.plate) : ""
                readonly property bool near: modelData.stopsAway !== undefined && modelData.stopsAway !== null && modelData.stopsAway <= 2
                readonly property bool hasMinutes: modelData.minutesAway !== undefined && modelData.minutesAway !== null && modelData.minutesAway > 0

                title: modelData.headSign ? modelData.headSign : modelData.routeCode
                titleWeight: 550
                subtitle: [Fmt.stopsText(modelData.stopsAway), modelData.plate].filter(x => x).join(" · ")
                leading: RouteBadge {
                    code: row.modelData.routeCode
                    badgeColor: row.modelData.color
                    textColor: row.modelData.textColor
                    minWidth: Math.round(52 * Theme.scale)
                }
                trailing: RowLayout {
                    spacing: Theme.gap * 1.5
                    Symbol {
                        visible: row.modelData.accessible
                        name: "accessible"
                        size: 18
                        color: Theme.accent
                    }
                    // Büyük varış süresi: "6 dk" ya da "durakta".
                    Column {
                        Layout.minimumWidth: Math.round(44 * Theme.scale)
                        SwapText {
                            anchors.right: parent.right
                            value: row.modelData.stopsAway === 0 ? "şimdi" : row.hasMinutes ? String(row.modelData.minutesAway) : "—"
                            style: "title2"
                            tabular: true
                            color: row.near ? Theme.green : Theme.label
                        }
                        Txt {
                            anchors.right: parent.right
                            visible: row.hasMinutes && row.modelData.stopsAway !== 0
                            text: "dk"
                            style: "caption"
                            secondary: true
                        }
                    }
                    IconButton {
                        icon: row.trackingId ? "bellActive" : "bell"
                        filled: !!row.trackingId
                        circle: !!row.trackingId
                        color: row.trackingId ? Theme.orange : Theme.accent
                        enabled: !!row.trackingId || Tracker.canStart
                        tooltip: row.trackingId ? "Takibi durdur" : "Bu araç yaklaşınca haber ver"
                        onClicked: row.trackingId ? Tracker.stop(row.trackingId) : page.trackVehicle(row.modelData)
                    }
                }
                onClicked: applicationWindow().openRoute(modelData.routeCode, modelData.direction)
            }
        }
    }

    Section {
        visible: page.passingRoutes.length > 0
        title: "Bu duraktan geçen hatlar"
        Repeater {
            model: page.passingRoutes
            delegate: ListRow {
                id: pr
                required property var modelData
                readonly property string waitingId: Tracker.trackings.length >= 0 ? Tracker.waitingFor(modelData.routeCode, page.stopId) : ""
                title: modelData.headSign || modelData.routeCode
                subtitle: modelData.time ? "Planlı sonraki sefer " + modelData.time : "Saat bilgisi yok"
                leading: RouteBadge {
                    code: pr.modelData.routeCode
                    badgeColor: pr.modelData.color
                    textColor: pr.modelData.textColor
                    minWidth: Math.round(52 * Theme.scale)
                }
                trailing: IconButton {
                    icon: pr.waitingId ? "bellActive" : "bell"
                    filled: !!pr.waitingId
                    circle: !!pr.waitingId
                    color: pr.waitingId ? Theme.orange : Theme.accent
                    enabled: !!pr.waitingId || Tracker.canStart
                    tooltip: pr.waitingId ? "Beklemeyi durdur" : "Bu hat gelince haber ver"
                    onClicked: pr.waitingId ? Tracker.stop(pr.waitingId) : page.waitFor(pr.modelData)
                }
                chevron: true
                onClicked: applicationWindow().openRoute(modelData.routeCode, 0)
            }
        }
    }

    Item { implicitHeight: Theme.margin }
}
