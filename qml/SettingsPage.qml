import QtQuick
import QtQuick.Layouts
import KocaeliUlasim
import "ui"

PageScaffold {
    id: page

    title: "Ayarlar"

    Section {
        title: "Görünüm"
        footer: "Uygulama renkleri Plasma'nın açık/koyu renk düzenini izler."
        ListRow {
            title: "Harita teması"
            clickable: false
            leading: IconTile { icon: "palette"; tone: "#AF52DE"; size: 28 }
            trailing: SegmentedControl {
                width: Math.round(240 * Theme.scale)
                model: ["Sistem", "Açık", "Koyu"]
                currentIndex: Store.mapTheme
                onActivated: index => Store.mapTheme = index
            }
        }
        ListRow {
            title: "Duyuruları göster"
            subtitle: "Ana sayfada ve ilgili hatta. Kapalıyken duyuru isteği atılmaz."
            subtitleLines: 2
            leading: IconTile { icon: "campaign"; tone: Theme.orange; size: 28 }
            trailing: Toggle {
                checked: Store.showAnnouncements
                onToggled: checked => Store.showAnnouncements = checked
            }
            onClicked: Store.showAnnouncements = !Store.showAnnouncements
        }
    }

    Section {
        title: "Takip varsayılanları"
        footer: "Takip penceresi son seçiminizi hatırlar; buradan da değiştirebilirsiniz."
        ListRow {
            title: "Önceden haber"
            subtitle: Store.trackWarnStops === 0 ? "Yalnızca varışta" : Store.trackWarnStops + " durak kala"
            clickable: false
            leading: IconTile { icon: "bell"; tone: Theme.red; size: 28 }
            trailing: Stepper {
                showValue: false
                value: Store.trackWarnStops
                from: 0
                to: 20
                onModified: v => Store.trackWarnStops = v
            }
        }
        ListRow {
            title: "Alarm olarak uyar"
            subtitle: "Açıkken siz durdurana kadar sesli alarm; kapalıyken bildirim."
            subtitleLines: 2
            leading: IconTile { icon: "alarm"; tone: Theme.orange; size: 28 }
            trailing: Toggle {
                checked: Store.trackAlarm
                onToggled: checked => Store.trackAlarm = checked
            }
            onClicked: Store.trackAlarm = !Store.trackAlarm
        }
    }

    Section {
        title: "Konum"
        ListRow {
            title: applicationWindow().hasFix ? "Konum servisinden" : Store.homeManual ? "Haritadan seçildi" : "Konum bilinmiyor"
            subtitle: applicationWindow().hasFix ? "İsabetli konum alınıyor."
                      : Store.homeManual ? "Yakındaki duraklar bu konuma göre gösterilir."
                      : "Konum servisi isabetli konum vermiyor; " + (Store.hasHome ? "son bilinen konum" : "İzmit merkezi") + " kullanılıyor."
            subtitleLines: 2
            clickable: false
            leading: IconTile { icon: "place"; tone: Theme.accent; size: 28 }
            trailing: PillButton {
                text: "Haritadan seç"
                compact: true
                onClicked: applicationWindow().pickLocation()
            }
        }
    }

    Section {
        title: "Veri"
        ListRow {
            title: "Hat listesi"
            subtitle: RouteCatalog.loading ? "Güncelleniyor…"
                      : RouteCatalog.error ? RouteCatalog.error
                      : RouteCatalog.count + " hat · günde bir kez kendiliğinden yenilenir"
            clickable: false
            leading: IconTile { icon: "route"; tone: Theme.green; size: 28 }
            trailing: RowLayout {
                Spinner { running: RouteCatalog.loading; size: 16 }
                PillButton {
                    text: "Yenile"
                    compact: true
                    enabled: !RouteCatalog.loading
                    onClicked: RouteCatalog.refresh()
                }
            }
        }
        ListRow {
            title: "Son aramaları temizle"
            titleColor: Store.recentSearches.length > 0 ? Theme.red : Theme.tertiaryLabel
            clickable: Store.recentSearches.length > 0
            leading: IconTile { icon: "history"; tone: "#8E8E93"; size: 28 }
            onClicked: Store.clearRecentSearches()
        }
    }

    Section {
        title: "Hakkında"
        ListRow {
            title: "Kocaeli Ulaşım " + Qt.application.version
            subtitle: "Kişisel kullanım için resmî olmayan istemci. Veriler KentKart'ın herkese açık uçlarından alınır; kart, ödeme ve hesap işlemleri yoktur."
            subtitleLines: 3
            clickable: false
            leading: Image {
                source: "qrc:/qt/qml/KocaeliUlasim/data/dev.enaimami.KocaeliUlasim.svg"
                sourceSize: Qt.size(96, 96)
                width: Math.round(28 * Theme.scale)
                height: width
            }
        }
        ListRow {
            title: "Harita: © OpenStreetMap katkıcıları"
            titleColor: Theme.accent
            chevron: true
            leading: IconTile { icon: "map"; tone: "#34C759"; size: 28 }
            onClicked: Qt.openUrlExternally("https://www.openstreetmap.org/copyright")
        }
    }

    Item { implicitHeight: Theme.margin }
}
