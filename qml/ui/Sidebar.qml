import QtQuick
import QtQuick.Layouts

/**
 * macOS tarzı kenar çubuğu: uygulama adı, bölümler (seçili olan vurgu renginde dolu kapsül,
 * dolu simge), altta etkin takip özeti. Klavye: Ctrl+1…4.
 */
Rectangle {
    id: root

    property string current: "home"
    property var items: []   // [{key, title, icon, badge}]

    signal selected(string key)

    color: Theme.sidebar

    // Seçili satırın (Repeater öğesinin) kendisi; vurgu dikdörtgeni onun y'sini izler.
    property var highlightEntry: null
    // İlk yerleşimde vurgu baştan kayıp gelmesin diye kaymayı ilk kareden sonra açarız.
    property bool rowsReady: false
    Component.onCompleted: Qt.callLater(function () { root.rowsReady = true })

    // Seçili satırın tek vurgu dikdörtgeni: sekme değişince yeni satıra yumuşakça kayar.
    Rectangle {
        id: highlight
        visible: root.highlightEntry !== null
        x: column.x + (root.highlightEntry ? root.highlightEntry.x : 0)
        width: root.highlightEntry ? root.highlightEntry.width : 0
        height: root.highlightEntry ? root.highlightEntry.height : 0
        y: column.y + (root.highlightEntry ? root.highlightEntry.y : 0)
        radius: Theme.radiusSmall
        color: Theme.accent
        Behavior on y {
            enabled: root.rowsReady
            NumberAnimation { duration: Theme.standard; easing.type: Theme.easing }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Theme.unit * 3
        spacing: Theme.unit

        RowLayout {
            spacing: Theme.gap * 1.25
            Layout.bottomMargin: Theme.margin
            Layout.leftMargin: Theme.unit
            Image {
                source: "qrc:/qt/qml/KocaeliUlasim/data/dev.enaimami.KocaeliUlasim.svg"
                sourceSize: Qt.size(96, 96)
                Layout.preferredWidth: Math.round(30 * Theme.scale)
                Layout.preferredHeight: Layout.preferredWidth
            }
            ColumnLayout {
                spacing: 0
                Txt { text: "Kocaeli"; style: "headline" }
                Txt { text: "Ulaşım"; style: "footnote"; secondary: true }
            }
        }

        Repeater {
            model: root.items
            delegate: Item {
                id: entry
                required property var modelData
                readonly property bool active: modelData.key === root.current
                Layout.fillWidth: true
                implicitHeight: Math.round(34 * Theme.scale)
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.title
                Accessible.checked: active
                Accessible.onPressAction: root.selected(modelData.key)
                Keys.onReturnPressed: root.selected(modelData.key)

                onActiveChanged: if (active) root.highlightEntry = entry
                Component.onCompleted: if (active) root.highlightEntry = entry

                // Yalnızca üzerine gelme ve basma tonu; seçili satırın zemini ortak vurgu dikdörtgeninde.
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: entry.active ? "transparent"
                         : mouse.pressed ? Theme.pressed
                         : (mouse.containsMouse || entry.activeFocus) ? Theme.hover : "transparent"
                    Behavior on color { enabled: !mouse.pressed; ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.unit * 2.5
                    anchors.rightMargin: Theme.unit * 2.5
                    spacing: Theme.gap * 1.25
                    Symbol {
                        name: entry.modelData.icon
                        filled: entry.active
                        size: 19
                        color: entry.active ? "white" : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                    }
                    Txt {
                        text: entry.modelData.title
                        style: "callout"
                        weight: entry.active ? 600 : 500
                        color: entry.active ? "white" : Theme.label
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                    }
                    Rectangle {
                        id: badge
                        readonly property int count: entry.modelData.badge || 0
                        visible: count > 0
                        // Rozet belirince ya da sayı değişince: kısa ölçek + solma.
                        onVisibleChanged: if (visible && Theme.motion) appear.restart()
                        onCountChanged: if (visible && Theme.motion) appear.restart()
                        ParallelAnimation {
                            id: appear
                            NumberAnimation { target: badge; property: "scale"; from: 0.8; to: 1; duration: Theme.standard; easing.type: Theme.easing }
                            NumberAnimation { target: badge; property: "opacity"; from: 0.4; to: 1; duration: Theme.quick; easing.type: Theme.easing }
                        }
                        implicitWidth: Math.max(implicitHeight, badgeText.implicitWidth + 10)
                        implicitHeight: Math.round(18 * Theme.scale)
                        radius: height / 2
                        color: entry.active ? Qt.rgba(1, 1, 1, 0.3) : Theme.fillStrong
                        Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
                        Txt {
                            id: badgeText
                            anchors.centerIn: parent
                            text: badge.count > 0 ? badge.count : ""
                            style: "caption"
                            weight: 650
                            color: entry.active ? "white" : Theme.secondaryLabel
                        }
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(entry.modelData.key)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // Sağ kenarda ince ayraç.
    Rectangle {
        anchors.right: parent.right
        width: 1 / Screen.devicePixelRatio
        height: parent.height
        color: Theme.separator
    }
}
