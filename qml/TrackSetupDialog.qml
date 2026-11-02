import QtQuick
import QtQuick.Layouts
import QtPositioning
import KocaeliUlasim
import "ui"

/**
 * Takip penceresi. Kipler:
 *  - "vehicle": bir aracı izle. Hedef ya verilen durak (`target`) ya da hat ekranından gelen
 *    ilerideki duraklardan biri (`routeStops`) / haritada seçilen bir nokta.
 *  - "wait": bu hattın ilk aracı duraka yaklaşınca haber ver.
 * Son seçim (kaç durak kala, alarm mı) hatırlanır.
 */
Sheet {
    id: dialog

    property string mode: "vehicle"
    property var vehicle: null
    property var target: null
    property var routeStops: []
    property var routePath: []
    property color routeColor: Theme.accent
    property string routeCode
    property int maxWarn: 40
    property bool placeMode: false
    property int stopIndex: 0
    property bool showAllStops: false
    property int radius: 300

    property int warnStops: 2
    property bool alarm: false

    readonly property var chosenStop: routeStops.length > 0 ? routeStops[stopIndex] : null
    /** Hedef durak, aracın kaç durak ilerisinde: en çok bir eksiği kadar önceden haber verilebilir. */
    readonly property int effectiveMaxWarn: routeStops.length > 0 ? stopIndex : maxWarn
    readonly property int shownWarn: Math.min(warnStops, effectiveMaxWarn)

    function configure(o) {
        mode = o.mode || "vehicle"
        vehicle = o.vehicle || null
        target = o.target || null
        routeStops = o.routeStops || []
        routePath = o.routePath || []
        routeColor = o.routeColor || Theme.accent
        routeCode = o.routeCode || (vehicle ? vehicle.routeCode : "")
        maxWarn = o.maxWarn !== undefined ? o.maxWarn : 40
        placeMode = false
        showAllStops = false
        warnStops = Store.trackWarnStops
        alarm = Store.trackAlarm
        stopIndex = Math.min(2, Math.max(0, routeStops.length - 1))
        radius = 300
        if (mode === "wait" && o.stopId) {
            // Durağın hattın başından sırası: daha fazla durak kala haber verilemez.
            maxWarn = 40
            Api.stopsBefore(routeCode, o.stopId, index => { if (index >= 0) dialog.maxWarn = index })
        }
        if (routeStops.length > 0 && vehicle && vehicle.lat !== undefined)
            Qt.callLater(() => pickMap.goTo(QtPositioning.coordinate(vehicle.lat, vehicle.lng), 14))
    }

    function start() {
        const warn = placeMode ? 0 : shownWarn
        Store.trackWarnStops = warnStops
        Store.trackAlarm = alarm
        let id = ""
        if (mode === "wait") {
            id = Tracker.waitForRoute(routeCode, target, warn, alarm)
        } else if (placeMode) {
            const c = pickMap.center
            id = Tracker.startVehicle(vehicle, {
                kind: "place", lat: c.latitude, lng: c.longitude, radiusM: radius, name: "seçilen konum",
            }, 0, alarm)
        } else {
            const s = routeStops.length > 0 ? chosenStop : target
            id = Tracker.startVehicle(vehicle, {
                kind: "stop", stopId: s.stopId || s.id, name: s.name,
                lat: s.lat !== undefined ? s.lat : null, lng: s.lng !== undefined ? s.lng : null,
            }, warn, alarm)
        }
        applicationWindow().toast(id ? "Takip başladı" : "En çok " + Tracker.maxTrackings + " takip olabilir")
        close()
    }

    title: mode === "wait" ? routeCode + " gelince" : "Takip"
    primaryText: "Takibi başlat"
    primaryIcon: "bellActive"
    primaryEnabled: Tracker.canStart && (mode === "wait" || !!vehicle)
    preferredWidth: (routeStops.length > 0 && placeMode ? 560 : 460) * Theme.scale
    onAccepted: start()

    // Özet: kim, nereye.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.margin * 1.25
        Layout.rightMargin: Theme.margin * 1.25
        Layout.topMargin: Theme.unit
        spacing: Theme.gap * 1.5
        RouteBadge {
            code: dialog.routeCode
            badgeColor: dialog.vehicle && dialog.vehicle.color ? dialog.vehicle.color : dialog.routeColor
            textColor: dialog.vehicle && dialog.vehicle.textColor ? dialog.vehicle.textColor : "white"
            large: true
        }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Txt {
                text: dialog.mode === "wait" ? "İlk yaklaşan araç" : (dialog.vehicle ? dialog.vehicle.plate : "")
                style: "title3"
                Layout.fillWidth: true
            }
            Txt {
                text: dialog.mode === "wait"
                      ? (dialog.target ? dialog.target.name : "") + " durağına yaklaşınca · en çok 6 saat"
                      : dialog.routeStops.length > 0 ? "Hedefi seçin"
                      : (dialog.target ? dialog.target.name + " durağına gelince" : "")
                style: "subhead"
                secondary: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                Layout.fillWidth: true
            }
        }
    }

    // Hat ekranından: hedef seçimi.
    Section {
        elevated: true
        visible: dialog.routeStops.length > 0
        title: "Nereye yaklaşınca?"

        Item {
            property bool isLast: false
            width: parent.width
            implicitHeight: targetKind.implicitHeight + Theme.margin * 1.25
            SegmentedControl {
                id: targetKind
                x: Theme.margin
                y: Theme.margin * 0.6
                width: parent.width - Theme.margin * 2
                model: ["Bir durağa", "Haritada bir yere"]
                currentIndex: dialog.placeMode ? 1 : 0
                onActivated: index => dialog.placeMode = index === 1
            }
        }
        Repeater {
            model: dialog.placeMode ? [] : dialog.routeStops.slice(0, dialog.showAllStops ? dialog.routeStops.length : 6)
            delegate: ChoiceRow {
                required property var modelData
                required property int index
                title: modelData.name
                subtitle: (index + 1) + " durak sonra" + (modelData.offsetMin ? "" : "")
                selected: index === dialog.stopIndex
                onClicked: dialog.stopIndex = index
            }
        }
        ListRow {
            visible: !dialog.placeMode && !dialog.showAllStops && dialog.routeStops.length > 6
            title: "Tüm duraklar (" + dialog.routeStops.length + ")"
            titleColor: Theme.accent
            onClicked: dialog.showAllStops = true
        }
        Item {
            property bool isLast: true
            visible: dialog.placeMode
            width: parent.width
            implicitHeight: Math.round(260 * Theme.scale)
            TransitMap {
                id: pickMap
                anchors.fill: parent
                pickMode: true
                pickRadius: dialog.radius
                path: dialog.routePath
                pathColor: dialog.routeColor
                showLocateButton: false
            }
        }
    }

    Section {
        elevated: true
        visible: dialog.placeMode
        title: "Yarıçap"
        footer: "Haritayı kaydırarak çemberi hedefin üzerine getirin; araç çembere girince haber verilir."
        Item {
            property bool isLast: true
            width: parent.width
            implicitHeight: radiusChips.implicitHeight + Theme.margin * 1.25
            Chips {
                id: radiusChips
                x: Theme.margin
                y: Theme.margin * 0.6
                width: parent.width - Theme.margin * 2
                options: [200, 300, 500, 800, 1200].map(m => ({ value: m, text: m < 1000 ? m + " m" : (m / 1000).toLocaleString(Qt.locale("tr_TR"), "f", 1) + " km" }))
                value: dialog.radius
                onPicked: v => dialog.radius = v
            }
        }
    }

    // Önceden haber.
    Section {
        elevated: true
        visible: !dialog.placeMode
        title: "Kaç durak kala haber verilsin?"
        footer: dialog.effectiveMaxWarn === 0 ? "Araç hedefe çok yakın; yalnızca varışta haber verilir."
                                              : "Varışta her zaman haber verilir."
        Item {
            property bool isLast: dialog.effectiveMaxWarn <= 5
            width: parent.width
            implicitHeight: warnChips.implicitHeight + Theme.margin * 1.25
            Chips {
                id: warnChips
                x: Theme.margin
                y: Theme.margin * 0.6
                width: parent.width - Theme.margin * 2
                options: [0, 1, 2, 3, 5].filter(n => n <= dialog.effectiveMaxWarn)
                    .map(n => ({ value: n, text: n === 0 ? "Kapalı" : String(n) }))
                value: dialog.shownWarn
                onPicked: v => dialog.warnStops = v
            }
        }
        ListRow {
            visible: dialog.effectiveMaxWarn > 5
            title: "Başka"
            // Değer bir çipe eşitse (0, 1, 2, 3, 5) tekrar yazılmaz.
            subtitle: [0, 1, 2, 3, 5].indexOf(dialog.shownWarn) >= 0 ? "Diğer bir sayı seçin"
                      : dialog.shownWarn + " durak kala"
            clickable: false
            trailing: Stepper {
                showValue: false
                value: dialog.shownWarn
                from: 0
                to: Math.max(0, dialog.effectiveMaxWarn)
                onModified: v => dialog.warnStops = v
            }
        }
    }

    // Uyarı türü.
    Section {
        elevated: true
        title: "Nasıl uyarılsın?"
        ChoiceRow {
            title: "Bildirim"
            subtitle: "Masaüstü bildirimi"
            leading: IconTile { icon: "bell"; tone: Theme.accent; size: 28 }
            selected: !dialog.alarm
            onClicked: dialog.alarm = false
        }
        ChoiceRow {
            title: "Alarm"
            subtitle: "Siz durdurana kadar sesli"
            leading: IconTile { icon: "alarm"; tone: Theme.orange; size: 28 }
            selected: dialog.alarm
            onClicked: dialog.alarm = true
        }
    }

    Banner {
        visible: !Tracker.canStart
        kind: "warning"
        text: "En çok " + Tracker.maxTrackings + " takip aynı anda sürebilir. Önce birini durdurun."
        Layout.leftMargin: Theme.margin
        Layout.rightMargin: Theme.margin
    }
}
