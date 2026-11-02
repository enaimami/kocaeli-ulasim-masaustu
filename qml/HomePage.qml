import QtQuick
import QtQuick.Layouts
import KocaeliUlasim
import "ui"
import "Fmt.js" as Fmt
import "LiveSync.js" as Live

/**
 * Ana sayfa: büyük başlık + arama; altında Takipler · Duyurular · Favoriler · Yakındaki duraklar.
 * Arama yazılınca sayfa sonuçlara döner (hatlar istemcide, duraklar sunucuda ≥ 3 harf).
 */
PageScaffold {
    id: page

    title: "Ana sayfa"
    subtitle: now.toLocaleDateString(Qt.locale("tr_TR"), "dddd, d MMMM")

    readonly property bool live: page.visible && applicationWindow().foreground
    readonly property string query: search.text.trim()
    readonly property bool searching: query.length > 0
    property date now: new Date()

    // Favori duraklar: durak kimliği → yaklaşanlar.
    property var favArrivals: ({})
    property var nearby: []
    property bool nearbyLoading: false
    property string nearbyError
    property var nearbyAt: null
    property bool showAllNearby: false
    property var stopResults: []
    property bool stopSearching: false
    readonly property var routeHits: searching ? RouteCatalog.search(query, -2, 60) : []

    function focusSearch() {
        search.focusField()
    }

    function loadNearby(force) {
        const loc = applicationWindow().location
        // Konum 150 m'den az değiştiyse yeniden istenmez.
        if (!force && nearbyAt && nearbyAt.distanceTo(loc) < 150 && nearby.length > 0)
            return
        nearbyLoading = true
        const self = page
        Api.closestStops(loc.latitude, loc.longitude, (err, stops) => {
            if (!self.alive) return // sayfa bu arada kapandı
            self.nearbyLoading = false
            self.nearbyError = err
            if (!err) {
                self.nearby = stops
                self.nearbyAt = loc
            }
        })
    }

    /** Favori duraklar sırayla (paralel istek yok) yenilenir. */
    function pollFavorites() {
        const ids = Store.favoriteStops.map(s => s.id)
        let i = 0
        const next = () => {
            if (i >= ids.length || !page.alive || !page.live)
                return
            const id = ids[i++]
            const self = page
            Api.stopArrivals(id, (err, a) => {
                if (!self.alive) return
                if (!err) {
                    const copy = Object.assign({}, self.favArrivals)
                    copy[id] = a
                    self.favArrivals = copy
                }
                next()
            })
        }
        next()
    }

    onLiveChanged: if (live) { pollFavorites(); loadNearby(false) }
    Component.onCompleted: {
        if (live) { pollFavorites(); loadNearby(false) }
        if (Store.showAnnouncements) Api.loadAnnouncements()
    }

    Connections {
        target: applicationWindow()
        function onHasFixChanged() { if (page.live) page.loadNearby(false) }
    }
    Connections {
        target: Store
        function onFavoritesChanged() { if (page.live) page.pollFavorites() }
        function onSettingsChanged() {
            if (Store.showAnnouncements) Api.loadAnnouncements()
            // Konum haritadan seçildiyse yakındaki duraklar yenilenir (150 m'den az değişim yok sayılır).
            if (page.live) page.loadNearby(false)
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: page.live && Store.favoriteStops.length > 0
        onTriggered: page.pollFavorites()
    }

    // Tarih başlığı: sayfa görünürken her dakika (gece yarısı geçince de güncellenir).
    Timer {
        interval: 60000
        repeat: true
        running: page.live
        triggeredOnStart: true
        onTriggered: page.now = new Date()
    }

    Timer {
        id: stopSearchDebounce
        interval: 350
        onTriggered: {
            const q = page.query
            if (q.length < 3) {
                page.stopResults = []
                return
            }
            page.stopSearching = true
            const self = page
            Api.searchStops(q, (err, stops) => {
                if (!self.alive || q !== self.query) return
                self.stopSearching = false
                self.stopResults = err ? [] : stops
            })
        }
    }

    Shortcut {
        sequences: [StandardKey.Refresh]
        enabled: page.visible
        onActivated: { page.loadNearby(true); page.pollFavorites() }
    }

    barActions: [
        IconButton {
            icon: "refresh"
            tooltip: "Yenile"
            onClicked: { page.loadNearby(true); page.pollFavorites() }
        }
    ]

    headerExtra: SearchBar {
        id: search
        width: parent.width
        placeholder: "Hat ya da durak ara"
        onTextChanged: stopSearchDebounce.restart()
        onAccepted: if (page.query.length > 0) Store.addRecentSearch(page.query)
    }

    // ---------- Son aramalar ----------
    Section {
        visible: !page.searching && search.focused && Store.recentSearches.length > 0
        title: "Son aramalar"
        actionText: "Temizle"
        onActionTriggered: Store.clearRecentSearches()
        Repeater {
            model: Store.recentSearches
            delegate: ListRow {
                required property string modelData
                title: modelData
                leading: Symbol { name: "history"; size: 20; color: Theme.secondaryLabel }
                onClicked: search.text = modelData
            }
        }
    }

    // ---------- Arama sonuçları ----------
    Section {
        visible: page.searching && page.routeHits.length > 0
        title: "Hatlar"
        Repeater {
            model: page.routeHits
            delegate: ListRow {
                required property var modelData
                title: modelData.name
                subtitle: Fmt.typeName(modelData.type) + (modelData.agency ? " · " + modelData.agency : "")
                chevron: true
                leading: RouteBadge {
                    code: modelData.code
                    badgeColor: modelData.color
                    textColor: modelData.textColor
                    minWidth: Math.round(52 * Theme.scale)
                }
                trailing: IconButton {
                    readonly property bool fav: Store.favoriteRoutes.some(r => r.code === modelData.code)
                    icon: "star"
                    filled: fav
                    color: fav ? Theme.yellow : Theme.tertiaryLabel
                    size: 28
                    tooltip: fav ? "Favorilerden çıkar" : "Favorilere ekle"
                    onClicked: Store.toggleFavoriteRoute(modelData.code, modelData.name, modelData.color, modelData.textColor)
                }
                onClicked: {
                    Store.addRecentSearch(page.query)
                    applicationWindow().openRoute(modelData.code, 0)
                }
            }
        }
    }

    Section {
        visible: page.searching && page.query.length >= 3
        title: "Duraklar"
        SkeletonRow { visible: page.stopSearching && page.stopResults.length === 0; leadingBlock: false; isLast: true }
        EmptyState {
            visible: !page.stopSearching && page.stopResults.length === 0
            icon: "place"
            title: "Bu adla durak bulunamadı"
        }
        Repeater {
            model: page.stopResults
            delegate: ListRow {
                required property var modelData
                title: modelData.name
                chevron: true
                leading: IconTile { icon: "place"; tone: Theme.red; size: 28 }
                onClicked: {
                    Store.addRecentSearch(page.query)
                    applicationWindow().openStop(modelData)
                }
            }
        }
    }

    Section {
        visible: page.searching && page.routeHits.length === 0 && page.query.length < 3
        EmptyState {
            icon: "search"
            title: "Eşleşen hat yok"
            message: "Durak adıyla aramak için en az 3 harf yazın."
        }
    }

    // ---------- Takipler ----------
    Section {
        visible: !page.searching && Tracker.count > 0
        title: "Takipler"
        Repeater {
            model: Tracker.trackings
            delegate: ListRow {
                required property var modelData
                title: modelData.title
                subtitle: modelData.progress
                clickable: !!modelData.stopId
                leading: IconTile { icon: modelData.alarm ? "alarm" : "bellActive"; tone: Theme.orange; round: true; size: 32 }
                trailing: PillButton {
                    text: "Durdur"
                    compact: true
                    tint: Theme.red
                    onClicked: Tracker.stop(modelData.id)
                }
                onClicked: applicationWindow().openStop({ id: modelData.stopId, name: modelData.target })
            }
        }
    }

    // ---------- Duyurular ----------
    Section {
        visible: !page.searching && Store.showAnnouncements && Api.announcements.length > 0
        title: "Duyurular"
        Repeater {
            model: Api.announcements
            delegate: ListRow {
                id: ann
                required property var modelData
                property bool expanded: false
                title: modelData.title
                titleWeight: 600
                subtitle: modelData.description
                subtitleLines: expanded ? 1000 : 2
                leading: IconTile { icon: "campaign"; tone: Theme.orange; size: 28 }
                trailing: Symbol {
                    name: "expandMore"
                    color: Theme.tertiaryLabel
                    rotation: ann.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                }
                onClicked: expanded = !expanded
            }
        }
    }

    // ---------- Favori duraklar ----------
    Section {
        visible: !page.searching
        title: "Favori duraklar"
        EmptyState {
            visible: Store.favoriteStops.length === 0
            icon: "star"
            title: "Henüz favori durak yok"
            message: "Bir durağı açıp yıldıza basın; burada yaklaşan araçlarıyla görünür."
        }
        Repeater {
            model: Store.favoriteStops
            delegate: ListRow {
                id: fav
                required property var modelData
                required property int index
                readonly property var arrivals: page.favArrivals[modelData.id]
                title: modelData.name
                titleWeight: 600
                subtitle: arrivals && arrivals.vehicles.length === 0 ? "Şu an yaklaşan araç yok" : ""
                chevron: true
                // Yaklaşanlar kimliğe göre yerinde güncellenir (rozetler yeniden kurulmaz).
                ListModel { id: chipModel }
                function syncChips() {
                    Live.sync(chipModel, arrivals ? arrivals.vehicles.slice(0, 6) : [], Live.vehicleKey)
                }
                onArrivalsChanged: syncChips()
                Component.onCompleted: syncChips()
                extra: Item {
                    width: parent.width
                    height: !fav.arrivals ? skeleton.height : (chipFlow.visible ? chipFlow.height : 0)

                    // Yüklenirken küçük iskelet: soluk rozet blokları, yavaş nabız.
                    Row {
                        id: skeleton
                        visible: !fav.arrivals
                        spacing: Theme.gap
                        opacity: 0.6
                        SequentialAnimation on opacity {
                            running: skeleton.visible && Theme.motion
                            loops: Animation.Infinite
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.5; duration: 700; easing.type: Easing.InOutSine }
                        }
                        Repeater {
                            model: 3
                            Rectangle {
                                width: Math.round(56 * Theme.scale)
                                height: Math.round(20 * Theme.scale)
                                radius: 6
                                color: Theme.fill
                            }
                        }
                    }

                    Flow {
                        id: chipFlow
                        width: parent.width
                        spacing: Theme.gap
                        visible: !!fav.arrivals && chipModel.count > 0
                        Repeater {
                            model: chipModel
                            delegate: Row {
                                required property string json
                                readonly property var modelData: JSON.parse(json)
                                spacing: Theme.unit * 1.5
                                NumberAnimation on opacity { from: 0; to: 1; duration: Theme.standard; easing.type: Theme.easing }
                                RouteBadge {
                                    code: modelData.routeCode
                                    badgeColor: modelData.color
                                    textColor: modelData.textColor
                                }
                                SwapText {
                                    value: Fmt.shortEta(modelData)
                                    style: "subhead"
                                    weight: 600
                                    tabular: true
                                    color: modelData.stopsAway !== undefined && modelData.stopsAway <= 2 ? Theme.green : Theme.label
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
                trailing: IconButton {
                    icon: "star"
                    filled: true
                    color: Theme.yellow
                    size: 28
                    tooltip: "Favorilerden çıkar"
                    onClicked: {
                        const removed = { id: fav.modelData.id, name: fav.modelData.name }
                        const at = fav.index
                        Store.removeFavoriteStop(removed.id)
                        applicationWindow().toast("Kaldırıldı: " + removed.name, "Geri al",
                            () => Store.restoreFavoriteStop(removed, at), 8000)
                    }
                }
                onClicked: applicationWindow().openStop(modelData)
            }
        }
    }

    // ---------- Favori hatlar ----------
    Section {
        visible: !page.searching && Store.favoriteRoutes.length > 0
        title: "Favori hatlar"
        Repeater {
            model: Store.favoriteRoutes
            delegate: ListRow {
                required property var modelData
                title: modelData.name
                chevron: true
                leading: RouteBadge {
                    code: modelData.code
                    badgeColor: modelData.color
                    textColor: modelData.textColor
                    minWidth: Math.round(52 * Theme.scale)
                }
                onClicked: applicationWindow().openRoute(modelData.code, 0)
            }
        }
    }

    // ---------- Yakındaki duraklar ----------
    Section {
        visible: !page.searching
        title: "Yakındaki duraklar"
        actionText: page.nearby.length > 5 ? (page.showAllNearby ? "Daha az" : "Tümünü göster") : ""
        onActionTriggered: page.showAllNearby = !page.showAllNearby

        ListRow {
            visible: !applicationWindow().hasFix
            title: Store.homeManual ? "Seçtiğiniz konuma göre" : "Konumunuz bilinmiyor"
            subtitle: Store.homeManual ? "Haritadan değiştirebilirsiniz"
                      : Store.hasHome ? "Son bilinen konuma göre gösteriliyor" : "İzmit merkezine göre gösteriliyor"
            clickable: false
            leading: IconTile { icon: Store.homeManual ? "pinDrop" : "locationOff"; tone: Store.homeManual ? Theme.accent : Theme.orange; size: 28 }
            trailing: PillButton {
                text: Store.homeManual ? "Değiştir" : "Haritadan seç"
                compact: true
                onClicked: applicationWindow().pickLocation()
            }
        }
        Repeater {
            model: page.nearbyLoading && page.nearby.length === 0 ? 4 : 0
            delegate: SkeletonRow { required property int index; isLast: index === 3 }
        }
        ListRow {
            visible: !!page.nearbyError
            title: page.nearbyError
            clickable: false
            leading: IconTile { icon: "wifiOff"; tone: Theme.red; size: 28 }
            trailing: PillButton { text: "Yeniden dene"; compact: true; onClicked: page.loadNearby(true) }
        }
        Repeater {
            model: page.showAllNearby ? page.nearby : page.nearby.slice(0, 5)
            delegate: ListRow {
                required property var modelData
                title: modelData.name
                chevron: true
                extra: BadgeRow { width: parent.width; badges: modelData.routes; maxCount: 9 }
                trailing: Column {
                    spacing: 2
                    Txt {
                        anchors.right: parent.right
                        text: modelData.distance !== undefined ? Api.formatDistance(modelData.distance) : ""
                        style: "subhead"
                        secondary: true
                        tabular: true
                    }
                    Symbol {
                        anchors.right: parent.right
                        visible: modelData.wheelchair
                        name: "accessible"
                        size: 16
                        color: Theme.accent
                    }
                }
                onClicked: applicationWindow().openStop(modelData)
            }
        }
    }

    Item { implicitHeight: Theme.margin }
}
