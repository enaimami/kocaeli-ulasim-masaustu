import QtQuick
import QtQuick.Layouts
import QtPositioning
import KocaeliUlasim
import "ui"
import "Fmt.js" as Fmt

/** Hat: yön, duraklar (canlı araçlarla), saatler ve harita. */
PageScaffold {
    id: page

    required property string code
    property int direction: 0

    property var detail: null
    property string error
    property bool loading: false
    property date now: new Date()
    property int tab: 0
    /** Yön değişti, yeni veri bekleniyor: eski içerik soluk ve dokunulmaz kalır. */
    property bool switching: false
    property int slideDir: 1
    /** Segment değişince içeriğin belirme ilerlemesi (0…1) ve kayma yönü. */
    property real tabIn: 1
    property real contentOpacity: (switching ? 0.4 : 1) * tabIn
    readonly property real tabSlide: slideDir * (1 - tabIn) * Math.round(14 * Theme.scale)
    Behavior on contentOpacity { enabled: !tabAnimation.running; NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }

    readonly property bool live: page.visible && applicationWindow().foreground
    readonly property var info: RouteCatalog.ready ? RouteCatalog.route(code) : ({})
    readonly property color routeColor: info.color || Theme.accent
    readonly property color routeTextColor: info.textColor || "white"
    readonly property bool favorite: Store.favoriteRoutes.some(r => r.code === code)
    readonly property var vehicles: detail ? detail.vehicles : []
    readonly property var announcements: Store.showAnnouncements ? Api.announcementsFor(code) : []

    title: code + (detail && detail.headSign ? " → " + detail.headSign : "")
    largeTitle: detail ? detail.headSign : (info.name || code)
    subtitle: detail ? (info.name || "") : (loading ? "Yükleniyor…" : "")

    function load() {
        loading = true
        const dir = direction
        const self = page
        Api.routeDetail(code, dir, (err, d) => {
            if (!self.alive || dir !== self.direction) return // sayfa kapandı ya da yön değişti
            const wasSwitching = self.switching
            self.loading = false
            self.switching = false
            self.error = err
            self.detail = err ? null : (d && d.code ? d : null)
            if (self.detail) {
                self.fitMap()
                if (wasSwitching) self.scrollTo(0) // yeni yönde liste başa yumuşakça döner
                if (self.tab === 1) nowTimer.restart()
            }
        })
    }

    function refreshVehicles() {
        if (!detail || detail.offline || switching) return
        const dir = direction
        const self = page
        Api.routeVehicles(code, dir, (err, list) => {
            if (!self.alive || err || dir !== self.direction || !self.detail) return
            const copy = Object.assign({}, self.detail)
            copy.vehicles = list
            self.detail = copy
        })
    }

    function fitMap() {
        map.fitPath()
    }

    /** Kaydırmayı yumuşakça [y] konumuna götürür. */
    function scrollTo(y) {
        scrollAnim.stop()
        scrollAnim.from = flickable.contentY
        scrollAnim.to = Math.max(0, Math.min(y, flickable.contentHeight - flickable.height))
        scrollAnim.restart()
    }

    NumberAnimation {
        id: scrollAnim
        target: page.flickable
        property: "contentY"
        duration: Theme.slow
        easing.type: Theme.easing
    }

    NumberAnimation {
        id: tabAnimation
        target: page
        property: "tabIn"
        from: 0
        to: 1
        duration: Theme.standard
        easing.type: Theme.easing
    }
    onTabChanged: {
        tabAnimation.restart()
        if (tab === 1) nowTimer.restart()
    }
    Timer { id: nowTimer; interval: 60; onTriggered: schedule.scrollToNow() }

    function flip() {
        direction = direction === 0 ? 1 : 0
    }

    function trackVehicleAt(vehicle, stopIndex) {
        applicationWindow().setupTracking({
            mode: "vehicle",
            vehicle: vehicle,
            routeStops: detail.stops.slice(stopIndex + 1),
            routePath: detail.path,
            routeColor: page.routeColor,
        })
    }

    Component.onCompleted: {
        load()
        if (Store.showAnnouncements) Api.loadAnnouncements()
    }
    onDirectionChanged: { switching = !!detail; load() }

    Timer {
        interval: 20000
        repeat: true
        running: page.live && !!page.detail
        onTriggered: { page.refreshVehicles(); page.now = new Date() }
    }
    onLiveChanged: if (live && detail) refreshVehicles()

    Shortcut {
        sequences: [StandardKey.Refresh]
        enabled: page.visible
        onActivated: page.load()
    }

    titleLeading: RouteBadge {
        code: page.code
        badgeColor: page.routeColor
        textColor: page.routeTextColor
        large: true
    }

    barActions: [
        IconButton {
            icon: "swap"
            tooltip: "Yönü değiştir"
            onClicked: page.flip()
        },
        IconButton {
            icon: "star"
            filled: page.favorite
            color: page.favorite ? Theme.orange : Theme.accent
            tooltip: page.favorite ? "Favorilerden çıkar" : "Favorilere ekle"
            onClicked: Store.toggleFavoriteRoute(page.code, page.info.name || (page.detail ? page.detail.headSign : ""),
                                                 String(page.routeColor), String(page.routeTextColor))
        },
        IconButton {
            icon: "refresh"
            tooltip: "Yenile"
            onClicked: page.load()
        }
    ]

    headerExtra: ColumnLayout {
        width: parent.width
        spacing: Theme.gap * 1.5

        Banner {
            visible: !!page.detail && page.detail.offline === true
            kind: "warning"
            text: page.detail && page.detail.offline
                  ? "Çevrimdışı · son güncelleme " + Qt.formatDateTime(page.detail.savedAt, "d.MM HH:mm") + ". Canlı araçlar gösterilemiyor."
                  : ""
            actionText: "Yeniden dene"
            onAction: page.load()
        }
        Banner {
            visible: !!page.detail && !!page.detail.note
            text: page.detail && page.detail.note ? "Hat notu: " + page.detail.note : ""
        }
        Repeater {
            model: page.announcements
            delegate: Banner {
                required property var modelData
                kind: "warning"
                text: modelData.title + " — " + modelData.description
            }
        }
        // Tek yön değiştirme satırı (üst çubuktaki simge de aynı işi yapar).
        RowLayout {
            visible: !!page.detail && !!page.detail.headSign
            Layout.fillWidth: true
            spacing: Theme.gap
            Txt {
                text: page.detail && page.detail.headSign ? "→ " + page.detail.headSign + " yönü" : ""
                style: "subhead"
                secondary: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            LinkButton {
                text: "Değiştir"
                style: "subhead"
                Accessible.name: "Yönü değiştir"
                onClicked: page.flip()
            }
        }
        SegmentedControl {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(380 * Theme.scale)
            model: ["Duraklar", "Saatler", "Harita"]
            currentIndex: page.tab
            onActivated: index => { page.slideDir = index > page.tab ? 1 : -1; page.tab = index }
        }
    }

    // ---------- Yükleniyor / hata ----------
    Section {
        visible: !page.detail
        Repeater {
            model: page.loading ? 6 : 0
            delegate: SkeletonRow { required property int index; isLast: index === 5; leadingBlock: false }
        }
        EmptyState {
            visible: !page.loading
            icon: page.error ? "wifiOff" : "route"
            title: page.error ? page.error : "Bu yönde sefer bilgisi yok"
            actionText: page.error ? "Yeniden dene" : "Diğer yöne bak"
            onAction: page.error ? page.load() : page.flip()
        }
    }

    // ---------- Duraklar ----------
    Section {
        visible: !!page.detail && page.tab === 0
        title: page.detail ? page.detail.stops.length + " durak" : ""
        opacity: page.contentOpacity
        enabled: !page.switching
        transform: Translate { x: page.tabSlide }

        Repeater {
            model: page.detail ? page.detail.stops : []
            delegate: StopRow {}
        }
    }

    // ---------- Saatler ----------
    Section {
        id: times
        visible: !!page.detail && page.tab === 1
        title: "Yaklaşan kalkışlar"
        opacity: page.contentOpacity
        enabled: !page.switching
        transform: Translate { x: page.tabSlide }
        footer: "Hat başından kalkış saatleri. Soluk olanlar son üç saatte kalkmış seferler."

        /** Yaklaşan kalkış [d]'den bu yana geçen dakika (24 saatlik çember; gelecekse negatif). */
        function minutesAgo(d) {
            if (d.minute === undefined || d.minute === null) return null
            const now = page.now.getHours() * 60 + page.now.getMinutes()
            const diff = ((now - d.minute) % 1440 + 1440) % 1440
            return diff > 720 ? diff - 1440 : diff
        }

        Item {
            property bool isLast: true
            width: parent.width
            implicitHeight: chips.implicitHeight + Theme.margin * 1.5
            Flow {
                id: chips
                x: Theme.margin
                y: Theme.margin * 0.75
                width: parent.width - Theme.margin * 2
                spacing: Theme.gap
                Repeater {
                    model: (page.detail ? page.detail.upcoming : []).filter(d => {
                        const ago = times.minutesAgo(d)
                        return ago === null || ago <= 180
                    })
                    delegate: Rectangle {
                        required property var modelData
                        readonly property var ago: times.minutesAgo(modelData)
                        readonly property bool soon: ago !== null && ago <= 0 && ago > -30
                        implicitWidth: chipText.implicitWidth + Theme.margin * 1.25
                        implicitHeight: Math.round(30 * Theme.scale)
                        radius: height / 2
                        opacity: ago !== null && ago > 0 ? 0.4 : 1
                        color: soon ? page.routeColor : Theme.fill
                        Txt {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.time + (modelData.nextDay ? "⁺¹" : "")
                            style: "callout"
                            weight: soon ? 650 : 500
                            tabular: true
                            color: soon ? page.routeTextColor : Theme.label
                        }
                    }
                }
                Txt {
                    visible: !page.detail || page.detail.upcoming.length === 0
                    text: "Yaklaşan kalkış yok"
                    secondary: true
                }
            }
        }
    }

    Section {
        id: schedule
        visible: !!page.detail && page.tab === 1
        title: "Tam tarife"
        opacity: page.contentOpacity
        enabled: !page.switching
        transform: Translate { x: page.tabSlide }

        readonly property var schedules: page.detail ? page.detail.schedules : []
        readonly property int todayIndex: {
            const wd = Fmt.serviceWeekday(page.now)
            for (let i = 0; i < schedules.length; ++i)
                if (schedules[i].days.indexOf(wd) >= 0) return i
            return 0
        }
        property int chosen: -1
        readonly property int shownIndex: chosen >= 0 && chosen < schedules.length ? chosen : todayIndex
        readonly property bool shownIsToday: shownIndex === todayIndex
        readonly property int nowMinute: { page.now; return Api.serviceMinuteNow() }
        readonly property var hourGroups: {
            const s = schedules[shownIndex]
            if (!s) return []
            const groups = []
            let current = null
            for (const d of s.departures) {
                const h = d.minute !== undefined && d.minute !== null ? Math.floor(d.minute / 60) : -1
                if (!current || current.hour !== h) {
                    current = { hour: h, label: h >= 0 ? String(h % 24).padStart(2, "0") : "?", items: [] }
                    groups.push(current)
                }
                current.items.push(d)
            }
            return groups
        }

        /** Şu anki saatin (yoksa sonraki ilk saatin) grup sırası; yalnızca bugünün tarifesinde. */
        readonly property int currentGroup: {
            if (!shownIsToday) return -1
            const h = Math.floor(nowMinute / 60)
            for (let i = 0; i < hourGroups.length; ++i)
                if (hourGroups[i].hour >= h) return i
            return -1
        }

        /** Tam tarifede şu anki saatin satırına yumuşakça kaydırır. */
        function scrollToNow() {
            if (!visible || currentGroup < 0) return
            const item = hourRep.itemAt(currentGroup)
            if (!item) return
            const y = item.mapToItem(page.flickable.contentItem, 0, 0).y
            page.scrollTo(y - page.barHeight - Math.round(110 * Theme.scale))
        }

        Item {
            property bool isLast: false
            visible: schedule.schedules.length > 1
            width: parent.width
            implicitHeight: dayPicker.implicitHeight + Theme.margin * 1.5
            SegmentedControl {
                id: dayPicker
                x: Theme.margin
                y: Theme.margin * 0.75
                width: parent.width - Theme.margin * 2
                model: schedule.schedules.map((s, i) => Fmt.dayMaskName(s.days) + (i === schedule.todayIndex ? " · bugün" : ""))
                currentIndex: schedule.shownIndex
                onActivated: index => schedule.chosen = index
            }
        }
        EmptyState {
            visible: schedule.schedules.length === 0
            icon: "schedule"
            title: "Tarife bilgisi yok"
        }
        Repeater {
            id: hourRep
            model: schedule.hourGroups
            delegate: Item {
                id: hourRow
                required property var modelData
                required property int index
                readonly property bool current: index === schedule.currentGroup
                property bool isLast: false
                width: parent.width
                implicitHeight: Math.max(Math.round(40 * Theme.scale), minutes.implicitHeight + Theme.margin)
                // Şu anki saat: hat renginde ince zemin + sol işaret.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.tint(page.routeColor, Theme.dark ? 0.2 : 0.1)
                    opacity: hourRow.current ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                    Rectangle {
                        width: Math.round(3 * Theme.scale)
                        height: parent.height
                        color: page.routeColor
                    }
                }
                Txt {
                    id: hourLabel
                    x: Theme.margin
                    width: Math.round(34 * Theme.scale)
                    height: Math.round(40 * Theme.scale)
                    text: hourRow.modelData.label
                    style: "headline"
                    tabular: true
                    color: page.routeColor
                    Accessible.name: hourRow.current ? text + ", şu anki saat" : text
                }
                Flow {
                    id: minutes
                    x: hourLabel.x + hourLabel.width + Theme.gap
                    y: (Math.round(40 * Theme.scale) - Math.round(20 * Theme.scale)) / 2
                    width: parent.width - x - Theme.margin
                    spacing: Theme.margin
                    Repeater {
                        model: hourRow.modelData.items
                        delegate: Txt {
                            required property var modelData
                            readonly property bool departed: schedule.shownIsToday && modelData.minute !== undefined
                                                             && modelData.minute !== null && modelData.minute < schedule.nowMinute
                            text: modelData.time.slice(3) + (modelData.nextDay ? "⁺¹" : "")
                            style: "body"
                            tabular: true
                            height: Math.round(20 * Theme.scale)
                            opacity: departed ? 0.35 : 1
                        }
                    }
                }
                Rectangle {
                    visible: !hourRow.isLast
                    x: Theme.margin
                    width: parent.width - x
                    anchors.bottom: parent.bottom
                    height: 1 / Screen.devicePixelRatio
                    color: Theme.separator
                }
            }
        }
    }

    // ---------- Harita ----------
    Rectangle {
        visible: !!page.detail && page.tab === 2
        Layout.fillWidth: true
        Layout.leftMargin: Theme.margin
        Layout.rightMargin: Theme.margin
        Layout.preferredHeight: Math.max(Math.round(320 * Theme.scale), page.fillHeight)
        opacity: page.contentOpacity
        enabled: !page.switching
        transform: Translate { x: page.tabSlide }
        radius: Theme.radius
        color: Theme.card
        clip: true
        layer.enabled: true

        TransitMap {
            id: map
            anchors.fill: parent
            path: page.detail ? page.detail.path : []
            pathColor: page.routeColor
            stops: page.detail ? page.detail.stops.filter(s => s.lat !== undefined) : []
            vehicles: page.vehicles.map(v => Object.assign({ color: String(page.routeColor), textColor: String(page.routeTextColor) }, v))
            myLocation: applicationWindow().hasFix ? applicationWindow().location : QtPositioning.coordinate()
            onStopClicked: stop => applicationWindow().openStop(stop)
        }
    }

    Item { implicitHeight: Theme.margin }

    /** Zaman çizelgesindeki durak: hat renginde çizgi + nokta; duraktaki araçlar altında. */
    component StopRow: Item {
        id: stopRow
        required property var modelData
        required property int index
        property bool isLast: false
        readonly property var here: page.vehicles.filter(v => v.stopId === modelData.id)
        readonly property bool first: index === 0
        readonly property bool terminal: index === 0 || index === (page.detail ? page.detail.stops.length - 1 : 0)
        readonly property real lineX: Theme.margin + Math.round(10 * Theme.scale)
        /** Durak noktasının merkezi: durak adının satırıyla hizalı. */
        readonly property real dotY: Theme.unit * 2 + Math.round(10 * Theme.scale)

        width: parent ? parent.width : 0
        implicitHeight: body.implicitHeight + Theme.unit * 4

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: modelData.name + (here.length > 0 ? ", araçlar: " + here.map(v => v.plate).join(", ") : "")
        Accessible.onPressAction: applicationWindow().openStop(modelData)
        Keys.onReturnPressed: applicationWindow().openStop(modelData)
        Keys.onSpacePressed: applicationWindow().openStop(modelData)

        Rectangle {
            anchors.fill: parent
            color: stopMouse.pressed ? Theme.pressed : (stopMouse.containsMouse || stopRow.activeFocus) ? Theme.hover : "transparent"
            // Basışta anında, bırakınca yumuşak.
            Behavior on color { enabled: !stopMouse.pressed; ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
        }
        MouseArea {
            id: stopMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: applicationWindow().openStop(stopRow.modelData)
        }
        // Klavye odağı görünür olsun.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            radius: Theme.radiusSmall
            border.width: stopRow.activeFocus ? 2 : 0
            border.color: Theme.accent
            opacity: stopRow.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        }

        // Çizgi
        Rectangle {
            x: stopRow.lineX - width / 2
            width: Math.round(6 * Theme.scale)
            y: stopRow.first ? stopRow.dotY : 0
            height: (stopRow.isLast ? stopRow.dotY : stopRow.height) - y
            color: page.routeColor
        }
        // Nokta (duraklarda içi boş, uçlarda büyük)
        Rectangle {
            x: stopRow.lineX - width / 2
            y: Theme.unit * 2 + (Math.round(20 * Theme.scale) - height) / 2
            width: Math.round((stopRow.terminal ? 16 : 11) * Theme.scale)
            height: width
            radius: width / 2
            color: stopRow.terminal ? page.routeColor : Theme.card
            border.color: stopRow.terminal ? Theme.card : page.routeColor
            border.width: Math.round(3 * Theme.scale)
        }

        ColumnLayout {
            id: body
            x: stopRow.lineX + Math.round(20 * Theme.scale)
            y: Theme.unit * 2
            width: parent.width - x - Theme.margin
            spacing: Theme.unit * 1.5

            RowLayout {
                Layout.fillWidth: true
                Txt {
                    text: stopRow.modelData.name
                    style: stopRow.terminal ? "headline" : "body"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(20 * Theme.scale)
                }
                Txt {
                    visible: Number(stopRow.modelData.offsetMin) > 0 && stopRow.index > 0
                    text: "+" + stopRow.modelData.offsetMin + " dk"
                    style: "footnote"
                    secondary: true
                    tabular: true
                }
            }

            Repeater {
                model: stopRow.here
                delegate: Rectangle {
                    id: vchip
                    required property var modelData
                    readonly property string trackingId: Tracker.trackings.length >= 0 ? Tracker.trackingFor(modelData.vehicleId, modelData.plate) : ""
                    Layout.fillWidth: true
                    implicitHeight: vrow.implicitHeight + Theme.unit * 3
                    radius: Theme.radiusSmall + 2
                    color: Theme.tint(page.routeColor, Theme.dark ? 0.22 : 0.12)

                    RowLayout {
                        id: vrow
                        anchors.fill: parent
                        anchors.leftMargin: Theme.unit * 2
                        anchors.rightMargin: Theme.unit * 2
                        spacing: Theme.gap
                        IconTile { icon: "bus"; tone: page.routeColor; round: true; size: 26 }
                        Txt {
                            text: vchip.modelData.plate + (vchip.modelData.minutesAway ? " · ~" + vchip.modelData.minutesAway + " dk" : "")
                            style: "subhead"
                            weight: 550
                            tabular: true
                            Layout.fillWidth: true
                        }
                        PillButton {
                            text: vchip.trackingId ? "Takipte" : "Takip et"
                            icon: vchip.trackingId ? "bellActive" : "bell"
                            iconFilled: !!vchip.trackingId
                            kind: vchip.trackingId ? "filled" : "tinted"
                            tint: vchip.trackingId ? Theme.orange : Theme.accent
                            compact: true
                            enabled: !!vchip.trackingId || (Tracker.canStart && !page.detail.offline && !stopRow.isLast)
                            onClicked: vchip.trackingId ? Tracker.stop(vchip.trackingId) : page.trackVehicleAt(vchip.modelData, stopRow.index)
                        }
                    }
                }
            }
        }
    }
}
