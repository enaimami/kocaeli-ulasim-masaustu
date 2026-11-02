import QtQuick
import QtQuick.Controls as QQC2
import QtLocation
import QtPositioning
import org.kde.kirigami as Kirigami
import KocaeliUlasim
import "ui"
import "Fmt.js" as Fmt
import "LiveSync.js" as Live

/**
 * Ortak harita: OpenStreetMap karoları (QtLocation osm eklentisi), durak ve canlı araç
 * işaretçileri, güzergah çizgisi, konumum noktası. Kuzey yukarı sabit.
 *
 * İki katman: alttaki karo haritası (koyu temada gölgelendiriciyle karartılır, hareketi o alır)
 * ve üstte aynı kamerayı izleyen, yalnızca işaretçileri çizen saydam "itemsoverlay" haritası;
 * böylece karartma işaretçilerin renklerini bozmaz.
 */
Item {
    id: root

    readonly property var center: view.map.center
    readonly property real zoomLevel: view.map.zoomLevel
    /** [{id, name, lat, lng}] */
    property var stops: []
    /** [{lat, lng, bearing, routeCode, color, textColor, plate}] */
    property var vehicles: []
    /** [coordinate] */
    property var path: []
    property color pathColor: Theme.accent
    property string highlightStopId
    property var myLocation: QtPositioning.coordinate()
    /** Hedef seçimi: ortada artı ve [pickRadius] metrelik çember. */
    property bool pickMode: false
    property int pickRadius: 300
    property bool showLocateButton: true

    // Durak ve araçlar kimliğe göre yerinde güncellenir: delegeler yeniden kurulmaz,
    // araçlar yeni konuma kayar, yeni gelen kısa solmayla girer.
    ListModel { id: stopModel }
    ListModel { id: vehicleModel }
    onStopsChanged: Live.sync(stopModel, stops, Live.stopKey)
    onVehiclesChanged: Live.sync(vehicleModel, vehicles.filter(v => v.lat !== undefined), Live.vehicleKey)

    signal stopClicked(var stop)
    signal vehicleClicked(var vehicle)
    /** Kaydırma/yakınlaştırma bittikten 800 ms sonra (istek atmak için debounce). */
    signal viewportSettled(var center)
    signal locateRequested()

    readonly property bool dark: Store.mapTheme === 2
        || (Store.mapTheme === 0 && Theme.dark)

    /** Güzergahı ekrana sığdırır; harita henüz boyut almadıysa boyut alınca yapılır. */
    function fitPath() {
        fitPending = true
        tryFit()
    }
    property bool fitPending: false
    function tryFit() {
        if (!fitPending || path.length < 2 || !visible || width <= 0 || height <= 0)
            return
        fitPending = false
        stopMotion()
        // QtPositioning.path() C++'tan gelen koordinat listesini tanımıyor; sınırlar elle.
        let n = -90, s = 90, e = -180, w = 180
        for (const c of path) {
            n = Math.max(n, c.latitude); s = Math.min(s, c.latitude)
            e = Math.max(e, c.longitude); w = Math.min(w, c.longitude)
        }
        view.map.fitViewportToGeoShape(QtPositioning.rectangle(QtPositioning.coordinate(n, w), QtPositioning.coordinate(s, e)),
                                       Kirigami.Units.gridUnit * 2)
    }
    onWidthChanged: tryFit()
    onHeightChanged: tryFit()
    onVisibleChanged: tryFit()
    onPathChanged: tryFit()

    /** Açılıştaki ilk yerleştirme anında olur; sonrası (düğmeler) yumuşak kayar. */
    property bool animateMoves: false
    Timer { running: true; interval: 500; onTriggered: root.animateMoves = true }

    function stopMotion() {
        centerAnim.stop()
        zoomAnim.stop()
    }

    function setZoom(zoom) {
        zoom = Math.max(view.map.minimumZoomLevel, Math.min(zoom, view.map.maximumZoomLevel))
        zoomAnim.stop()
        if (!animateMoves || !Theme.motion) {
            view.map.zoomLevel = zoom
            return
        }
        zoomAnim.to = zoom
        zoomAnim.start()
    }

    /** Yakınlaştırma düğmeleri: animasyon sürerken hedeften devam eder (art arda basış birikir). */
    function zoomBy(delta) {
        setZoom((zoomAnim.running ? zoomAnim.to : view.map.zoomLevel) + delta)
    }

    function goTo(coordinate, zoom) {
        centerAnim.stop()
        if (!animateMoves || !Theme.motion) {
            view.map.center = coordinate
        } else {
            centerAnim.to = coordinate
            centerAnim.start()
        }
        if (zoom !== undefined)
            setZoom(zoom)
    }

    // Kesilebilir kamera animasyonları (hareket kapalıyken süre 0).
    CoordinateAnimation {
        id: centerAnim
        target: view.map
        property: "center"
        duration: Theme.slow
        easing.type: Theme.easing
    }
    NumberAnimation {
        id: zoomAnim
        target: view.map
        property: "zoomLevel"
        duration: Theme.standard
        easing.type: Theme.easing
    }
    // Kullanıcı haritaya dokunur/sürükleyince süren kamera animasyonu bırakılır.
    PointHandler {
        onActiveChanged: if (active) root.stopMotion()
    }

    Plugin {
        id: tilePlugin
        name: "osm"
        // HTTP başlığı: yalnızca ASCII.
        PluginParameter { name: "osm.useragent"; value: "KocaeliUlasimMasaustu/1.0 (personal desktop client; Qt Location)" }
        PluginParameter { name: "osm.mapping.cache.directory"; value: Api.tileCacheDir }
        PluginParameter { name: "osm.mapping.providersrepository.address"; value: Api.tileProviders }
        PluginParameter { name: "osm.mapping.highdpi_tiles"; value: false }
        PluginParameter { name: "osm.mapping.cache.disk.size"; value: 200 * 1024 * 1024 }
    }

    Plugin {
        id: overlayPlugin
        name: "itemsoverlay"
    }

    MapView {
        id: view
        anchors.fill: parent
        map.plugin: tilePlugin
        map.center: QtPositioning.coordinate(40.7654, 29.9408)
        map.zoomLevel: 15
        map.copyrightsVisible: false
        map.activeMapType: {
            const types = map.supportedMapTypes
            for (let i = 0; i < types.length; ++i)
                if (types[i].style === MapType.StreetMap)
                    return types[i]
            return types.length > 0 ? types[0] : map.activeMapType
        }
        // Eğme (tilt) ve döndürme yok: kuzey yukarı.
        map.onBearingChanged: if (map.bearing !== 0) map.bearing = 0
        map.onTiltChanged: if (map.tilt !== 0) map.tilt = 0
        map.onCenterChanged: settle.restart()
        map.onZoomLevelChanged: settle.restart()

        layer.enabled: root.dark
        layer.effect: ShaderEffect {
            fragmentShader: "qrc:/shaders/darkmap.frag.qsb"
        }
    }

    Map {
        id: overlay
        anchors.fill: parent
        plugin: overlayPlugin
        color: "transparent"
        copyrightsVisible: false
        center: view.map.center
        zoomLevel: view.map.zoomLevel
        minimumZoomLevel: view.map.minimumZoomLevel
        maximumZoomLevel: view.map.maximumZoomLevel

        MapPolyline {
            line.width: 5
            line.color: root.pathColor
            path: root.path
            opacity: 0.85
        }

        MapCircle {
            visible: root.pickMode
            center: overlay.center
            radius: root.pickRadius
            color: Theme.tint(Theme.accent, 0.15)
            border.color: Theme.accent
            border.width: 2
        }

        MapItemView {
            model: stopModel
            delegate: MapQuickItem {
                required property string json
                readonly property var modelData: JSON.parse(json)
                readonly property bool highlighted: modelData.id === root.highlightStopId
                coordinate: QtPositioning.coordinate(modelData.lat, modelData.lng)
                anchorPoint.x: dot.width / 2
                anchorPoint.y: dot.height / 2
                z: highlighted ? 2 : 1
                sourceItem: Rectangle {
                    id: dot
                    width: highlighted ? 20 : (overlay.zoomLevel >= 15 ? 14 : 10)
                    height: width
                    radius: width / 2
                    color: highlighted ? Theme.accent : "white"
                    border.color: highlighted ? "white" : root.pathColor
                    border.width: 3
                    // Seçilince büyüme ve renk değişimi yumuşak (kesilebilir).
                    Behavior on width { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                    Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }

                    HoverHandler { id: stopHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.stopClicked(modelData) }
                    QQC2.ToolTip.visible: stopHover.hovered
                    QQC2.ToolTip.text: modelData.name
                    QQC2.ToolTip.delay: 300
                }
            }
        }

        MapItemView {
            model: vehicleModel
            delegate: MapQuickItem {
                required property string json
                readonly property var modelData: JSON.parse(json)
                coordinate: QtPositioning.coordinate(modelData.lat, modelData.lng)
                // Yeni konuma ~1 sn'de kayar (ilk yerleşim animasyonsuz).
                Behavior on coordinate {
                    enabled: Theme.motion
                    CoordinateAnimation { duration: 1000; easing.type: Easing.InOutQuad }
                }
                anchorPoint.x: marker.width / 2
                anchorPoint.y: marker.height / 2
                z: 3
                sourceItem: Item {
                    id: marker
                    width: Kirigami.Units.gridUnit * 1.8
                    height: width
                    NumberAnimation on opacity { from: 0; to: 1; duration: Theme.standard; easing.type: Theme.easing }

                    // Yön oku (bearing varsa). Dönüş kısa yoldan, yumuşak.
                    Canvas {
                        anchors.fill: parent
                        visible: modelData.bearing !== undefined && modelData.bearing !== null
                        rotation: modelData.bearing || 0
                        Behavior on rotation {
                            enabled: Theme.motion
                            RotationAnimation { direction: RotationAnimation.Shortest; duration: Theme.slow; easing.type: Easing.InOutQuad }
                        }
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = bubble.color
                            ctx.beginPath()
                            ctx.moveTo(width / 2, 0)
                            ctx.lineTo(width / 2 + 6, 8)
                            ctx.lineTo(width / 2 - 6, 8)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                    Rectangle {
                        id: bubble
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: width
                        radius: width / 2
                        color: modelData.color || root.pathColor
                        border.color: "white"
                        border.width: 2
                        Symbol {
                            anchors.centerIn: parent
                            name: "bus"
                            filled: true
                            size: marker.width * 0.5 / Theme.scale
                            color: modelData.textColor || "white"
                        }
                    }
                    HoverHandler { id: vHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.vehicleClicked(modelData) }
                    QQC2.ToolTip.visible: vHover.hovered
                    QQC2.ToolTip.text: (modelData.routeCode ? modelData.routeCode + " · " : "") + modelData.plate
                        + (modelData.headSign ? "\n→ " + modelData.headSign : "")
                }
            }
        }

        MapQuickItem {
            visible: root.myLocation.isValid
            coordinate: root.myLocation
            anchorPoint.x: me.width / 2
            anchorPoint.y: me.height / 2
            z: 4
            sourceItem: Item {
                id: me
                width: 44
                height: 44

                // Yumuşak nabız atan yarı saydam hale (hareket kapalıyken sabit).
                Rectangle {
                    id: halo
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.accent
                    scale: Theme.motion ? 1 : 1.8
                    opacity: Theme.motion ? 0.35 : 0.18
                    SequentialAnimation {
                        running: Theme.motion && root.myLocation.isValid && root.visible
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) { halo.scale = Theme.motion ? 1 : 1.8; halo.opacity = Theme.motion ? 0.35 : 0.18 }
                        ParallelAnimation {
                            NumberAnimation { target: halo; property: "scale"; from: 1; to: 2.4; duration: 1800; easing.type: Easing.OutSine }
                            NumberAnimation { target: halo; property: "opacity"; from: 0.35; to: 0; duration: 1800; easing.type: Easing.OutSine }
                        }
                        PauseAnimation { duration: 400 }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.accent
                    border.color: "white"
                    border.width: 3
                }
            }
        }
    }

    // Seçim artısı.
    Symbol {
        anchors.centerIn: parent
        visible: root.pickMode
        name: "myLocation"
        size: 30
        weight: 600
        color: Theme.accent
    }

    Timer {
        id: settle
        interval: 800
        onTriggered: root.viewportSettled(view.map.center)
    }

    // Harita denetimleri: yüzen, gölgeli tek kart (iOS Haritalar gibi).
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.margin * 0.75
        width: controls.width
        height: controls.height
        radius: Theme.radiusSmall + 2
        color: Theme.cardElevated
        border.width: 1 / Screen.devicePixelRatio
        border.color: Theme.separator

        Column {
            id: controls
            IconButton {
                visible: root.showLocateButton
                icon: "nearMe"
                filled: root.myLocation.isValid
                tooltip: "Konumuma git"
                size: 36
                onClicked: {
                    if (root.myLocation.isValid)
                        root.goTo(root.myLocation, Math.max(view.map.zoomLevel, 16))
                    root.locateRequested()
                }
            }
            Rectangle { visible: root.showLocateButton; width: parent.width; height: 1 / Screen.devicePixelRatio; color: Theme.separator }
            IconButton {
                icon: "add"
                tooltip: "Yakınlaştır"
                size: 36
                onClicked: root.zoomBy(1)
            }
            Rectangle { width: parent.width; height: 1 / Screen.devicePixelRatio; color: Theme.separator }
            IconButton {
                icon: "remove"
                tooltip: "Uzaklaştır"
                size: 36
                onClicked: root.zoomBy(-1)
            }
        }
    }

    // Kaynak gösterimi (OSM karo politikası gereği zorunlu).
    QQC2.Label {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 2
        padding: 2
        leftPadding: 4
        rightPadding: 4
        text: "© <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> katkıcıları"
        textFormat: Text.RichText
        font.family: Theme.family
        font.pixelSize: Math.round(10 * Theme.scale)
        color: Theme.secondaryLabel
        linkColor: Theme.secondaryLabel
        onLinkActivated: link => Qt.openUrlExternally(link)
        background: Rectangle { color: Theme.tint(Theme.card, 0.75); radius: 4 }
        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
    }
}
