import QtQuick

/** iOS bölümlü denetim: seçili parçanın beyaz "başparmağı" yeni seçime kayar (kesilebilir). */
Rectangle {
    id: root

    property var model: []
    property int currentIndex: 0

    signal activated(int index)

    implicitHeight: Math.round(32 * Theme.scale)
    implicitWidth: model.length * Math.round(96 * Theme.scale)
    radius: Theme.radiusSmall + 1
    color: Theme.fill

    readonly property real segment: (width - 4) / Math.max(1, model.length)

    // Konum yalnızca seçim değişince animasyonla gider; genişlik değişince x anında yeniden hesaplanır
    // (böylece pencere boyutlanırken başparmak geride kalmaz).
    property real thumbPos: currentIndex
    Behavior on thumbPos { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }

    Rectangle {
        id: thumb
        y: 2
        x: 2 + root.thumbPos * root.segment
        width: root.segment
        height: root.height - 4
        radius: Theme.radiusSmall - 1
        color: Theme.dark ? "#636366" : "#FFFFFF"

        // Hafif gölge: başparmak zeminden ayrışsın.
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.bottomMargin: -1
            radius: parent.radius
            color: Theme.shadow
            opacity: Theme.dark ? 0 : 0.5
        }
    }

    Row {
        x: 2
        y: 2
        height: root.height - 4
        Repeater {
            model: root.model
            delegate: Item {
                required property var modelData
                required property int index
                width: root.segment
                height: parent.height
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData
                Accessible.checked: index === root.currentIndex
                Accessible.onPressAction: root.select(index)
                Keys.onReturnPressed: root.select(index)
                Keys.onSpacePressed: root.select(index)
                Keys.onLeftPressed: root.select(Math.max(0, root.currentIndex - 1))
                Keys.onRightPressed: root.select(Math.min(root.model.length - 1, root.currentIndex + 1))

                Txt {
                    anchors.centerIn: parent
                    text: modelData
                    style: "footnote"
                    weight: index === root.currentIndex ? 600 : 500
                    opacity: segMouse.pressed && index !== root.currentIndex ? 0.5 : 1
                }
                // Seçili olmayan parçalar arasında ince ayraç.
                Rectangle {
                    visible: index > 0 && index !== root.currentIndex && index - 1 !== root.currentIndex
                    width: 1
                    height: parent.height * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.separator
                }
                MouseArea {
                    id: segMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.select(index)
                }
            }
        }
    }

    function select(i) {
        if (i === currentIndex)
            return
        currentIndex = i
        activated(i)
    }
}
