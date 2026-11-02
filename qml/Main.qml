import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import QtPositioning
import org.kde.kirigami as Kirigami
import KocaeliUlasim
import "ui"
import "Fmt.js" as Fmt

Kirigami.ApplicationWindow {
    id: root

    title: "Kocaeli Ulaşım"
    width: Kirigami.Units.gridUnit * 64
    height: Kirigami.Units.gridUnit * 42
    minimumWidth: Kirigami.Units.gridUnit * 22
    minimumHeight: Kirigami.Units.gridUnit * 24
    visible: true

    /** Canlı veri yoklaması yalnızca pencere görünürken (PLAN §0). */
    readonly property bool foreground: visible && visibility !== Window.Minimized && visibility !== Window.Hidden

    /**
     * Bilinen konum: isabetli konum servisi verisi, yoksa haritadan seçilen / son bilinen / İzmit
     * merkezi. Masaüstünde geoclue çoğu zaman yalnızca IP'den ±25 km verir; yakın durak için işe
     * yaramaz, bu yüzden 1,5 km'den kötü isabet yok sayılır.
     */
    readonly property bool hasFix: positionSource.position.coordinate.isValid
        && positionSource.position.horizontalAccuracyValid
        && positionSource.position.horizontalAccuracy <= 1500
    readonly property var location: hasFix ? positionSource.position.coordinate
                                           : QtPositioning.coordinate(Store.homeLat, Store.homeLng)

    pageStack.defaultColumnWidth: Math.round(440 * Theme.scale)
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
    pageStack.globalToolBar.showNavigationButtons: Kirigami.ApplicationHeaderStyle.ShowBackButton
    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.DynamicColumns
    pageStack.separatorVisible: true
    pageStack.initialPage: homePage

    function openStop(stop) {
        pageStack.push(Qt.resolvedUrl("StopPage.qml"), {
            stopId: stop.id,
            stopName: stop.name || "",
            stopLat: stop.lat !== undefined ? stop.lat : NaN,
            stopLng: stop.lng !== undefined ? stop.lng : NaN,
        })
    }

    function openRoute(code, direction) {
        pageStack.push(Qt.resolvedUrl("RoutePage.qml"), {
            code: code,
            direction: direction === undefined || direction === null ? 0 : direction,
        })
    }

    /** Takip penceresini açar; ayrıntılar için TrackSetupDialog'a bakın. */
    function setupTracking(options) {
        trackDialog.configure(options)
        trackDialog.open()
    }

    /** Bölüm değiştirir: kısa solma ile (söner → değişir → belirir). Aynı bölüme basınca yalnızca alt sayfaları kapatır. */
    function showSection(name) {
        if (name === currentSection) {
            sectionSwap.stop()
            pageStack.columnView.opacity = 1
            if (pageStack.depth > 1)
                pageStack.pop(pageStack.get(0))
            return
        }
        pendingSection = name
        currentSection = name
        sectionSwap.restart()
    }
    property string pendingSection: "home"

    function swapSection(name) {
        pageStack.clear()
        switch (name) {
        case "home": pageStack.push(homePage); break
        case "map": pageStack.push(Qt.resolvedUrl("MapPage.qml")); break
        case "trackings": pageStack.push(Qt.resolvedUrl("TrackingsPage.qml")); break
        case "settings": pageStack.push(Qt.resolvedUrl("SettingsPage.qml")); break
        }
    }

    SequentialAnimation {
        id: sectionSwap
        NumberAnimation { target: root.pageStack.columnView; property: "opacity"; to: 0; duration: Math.round(Theme.quick * 0.7); easing.type: Theme.easing }
        ScriptAction { script: root.swapSection(root.pendingSection) }
        NumberAnimation { target: root.pageStack.columnView; property: "opacity"; to: 1; duration: Math.round(Theme.quick * 0.7); easing.type: Theme.easing }
    }
    property string currentSection: "home"

    // Tasarım sistemi Plasma'nın ayarlarını izler: renk düzeni, yazı boyutu, animasyon hızı.
    Binding { target: Theme; property: "dark"; value: Fmt.isDark(Kirigami.Theme.backgroundColor) }
    Binding { target: Theme; property: "scale"; value: Math.max(0.85, Math.min(1.6, Kirigami.Theme.defaultFont.pointSize / 10)) }
    Binding { target: Theme; property: "motion"; value: Kirigami.Units.longDuration > 0 }

    color: Theme.background
    /** Tasarım sistemine pencere üzerinden erişim (geliştirme kancası KU_EVAL için). */
    readonly property QtObject theme: Theme

    globalDrawer: Kirigami.OverlayDrawer {
        id: drawer
        edge: Qt.LeftEdge
        modal: !root.wideScreen
        drawerOpen: root.wideScreen
        handleVisible: !root.wideScreen
        width: Math.round(220 * Theme.scale)
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        background: Rectangle { color: Theme.sidebar }
        onWideScreenChanged: drawerOpen = root.wideScreen
        readonly property bool wideScreen: root.wideScreen

        contentItem: Sidebar {
            current: root.currentSection
            items: [
                { key: "home", title: "Ana sayfa", icon: "home" },
                { key: "map", title: "Harita", icon: "map" },
                { key: "trackings", title: "Takipler", icon: "bell", badge: Tracker.count },
                { key: "settings", title: "Ayarlar", icon: "settings" },
            ]
            onSelected: key => {
                root.showSection(key)
                if (drawer.modal)
                    drawer.close()
            }
        }
    }

    Shortcut { sequence: "Ctrl+1"; onActivated: root.showSection("home") }
    Shortcut { sequence: "Ctrl+2"; onActivated: root.showSection("map") }
    Shortcut { sequence: "Ctrl+3"; onActivated: root.showSection("trackings") }
    Shortcut { sequence: "Ctrl+,"; onActivated: root.showSection("settings") }

    Component {
        id: homePage
        HomePage {}
    }

    PositionSource {
        id: positionSource
        active: root.foreground
        updateInterval: 30000
        preferredPositioningMethods: PositionSource.AllPositioningMethods
        onPositionChanged: {
            if (root.hasFix)
                Store.setHome(position.coordinate.latitude, position.coordinate.longitude)
        }
    }

    TrackSetupDialog {
        id: trackDialog
    }

    Toast { id: toastView }

    /** iOS tarzı geçici balon: `toast("Metin")` ya da `toast("Kaldırıldı", "Geri al", () => ..., 8000)`. */
    function toast(text, actionText, action, ms) {
        toastView.show(text, actionText, action, ms)
    }

    /** Konumu haritadan seçtirir (konum servisi yoksa ya da kaba konum veriyorsa). */
    function pickLocation() {
        locationDialog.open()
        Qt.callLater(() => locationMap.goTo(root.location, 15))
    }

    Sheet {
        id: locationDialog
        title: "Konumum"
        primaryText: "Bu konumu kullan"
        primaryIcon: "pinDrop"
        preferredWidth: 600 * Theme.scale
        onAccepted: {
            const c = locationMap.center
            Store.setHome(c.latitude, c.longitude, true)
            close()
        }

        Txt {
            text: "Haritayı kaydırıp yakınlaştırarak işareti bulunduğunuz yerin üzerine getirin. Yakındaki duraklar bu konuma göre gösterilir."
            style: "subhead"
            secondary: true
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            Layout.fillWidth: true
            Layout.leftMargin: Theme.margin * 1.25
            Layout.rightMargin: Theme.margin * 1.25
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.margin
            Layout.rightMargin: Theme.margin
            Layout.preferredHeight: Math.round(380 * Theme.scale)
            radius: Theme.radius
            color: Theme.card
            clip: true
            layer.enabled: true
            TransitMap {
                id: locationMap
                anchors.fill: parent
                pickMode: true
                pickRadius: 0
                showLocateButton: false
            }
        }
    }

    // Alarm: kapatılamaz pencere, büyük turuncu simge, tek büyük "Durdur".
    Sheet {
        id: alarmSheet
        title: "Alarm"
        cancelText: ""
        primaryText: "Alarmı durdur"
        primaryIcon: "stop"
        primaryTint: Theme.red
        closePolicy: QQC2.Popup.NoAutoClose
        preferredWidth: 420 * Theme.scale
        onAccepted: Notifier.stopAlarm()

        readonly property bool active: Notifier.alarmActive
        onActiveChanged: {
            if (active) {
                open()
                root.show(); root.raise(); root.requestActivate()
            } else {
                close()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.margin
            spacing: Theme.gap * 1.5
            IconTile {
                icon: "alarm"
                tone: Theme.orange
                round: true
                size: 72
                Layout.alignment: Qt.AlignHCenter
                SequentialAnimation on scale {
                    running: alarmSheet.visible && Theme.motion
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.08; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }
            Txt {
                text: Notifier.alarmTitle
                style: "title2"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.leftMargin: Theme.margin
                Layout.rightMargin: Theme.margin
            }
            Txt {
                text: Notifier.alarmText
                style: "body"
                secondary: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                Layout.fillWidth: true
                Layout.leftMargin: Theme.margin * 1.5
                Layout.rightMargin: Theme.margin * 1.5
            }
        }
    }

    QQC2.Action {
        shortcut: StandardKey.Find
        onTriggered: {
            if (root.currentSection !== "home")
                root.showSection("home")
            pageStack.get(0).focusSearch()
        }
    }

    onClosing: close => {
        // Takip ya da alarm varsa pencere yalnızca gizlenir; uygulama tepside sürer.
        if (Tracker.count === 0 && !Notifier.alarmActive)
            Qt.quit()
    }
}
