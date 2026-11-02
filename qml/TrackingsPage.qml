import QtQuick
import QtQuick.Layouts
import KocaeliUlasim
import "ui"

/** Etkin varış takipleri. Pencere kapatılsa da tepside sürer. */
PageScaffold {
    id: page

    title: "Takipler"
    subtitle: Tracker.count > 0 ? Tracker.count + " / " + Tracker.maxTrackings + " etkin takip" : "Etkin takip yok"

    barActions: [
        LinkButton {
            visible: Tracker.count > 0
            text: "Tümünü durdur"
            color: Theme.red
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Tracker.stopAll()
        }
    ]

    Section {
        footer: "Takipler 20 saniyede bir (araç uzaktayken dakikada bir) güncellenir. Araç hedefe varınca, "
                + "üç tur görünmeyince ya da süre dolunca (araç takibi 1 saat, hat beklemesi 6 saat) kendiliğinden biter."

        EmptyState {
            visible: Tracker.count === 0
            icon: "bell"
            title: "Etkin takip yok"
            message: "Bir durakta araç satırındaki zil ya da hat ekranında “Takip et” ile başlatın. "
                     + "Pencereyi kapatsanız da takip tepside sürer; araç yaklaşınca masaüstü bildirimi gelir."
        }
        Repeater {
            model: Tracker.trackings
            delegate: ListRow {
                required property var modelData
                title: modelData.title
                titleWeight: 600
                subtitle: modelData.progress + "\n" + (modelData.alarm ? "Alarm" : "Bildirim") + " · "
                          + Qt.formatTime(new Date(modelData.expiresAt), "HH:mm") + "'e kadar"
                subtitleLines: 2
                clickable: !!modelData.stopId
                leading: IconTile { icon: modelData.alarm ? "alarm" : "bellActive"; tone: Theme.orange; round: true; size: 36 }
                trailing: PillButton {
                    text: "Durdur"
                    icon: "stop"
                    compact: true
                    tint: Theme.red
                    onClicked: Tracker.stop(modelData.id)
                }
                onClicked: applicationWindow().openStop({ id: modelData.stopId, name: modelData.target })
            }
        }
    }

    Item { implicitHeight: Theme.margin }
}
