import QtQuick

/** iOS anahtarı: yeşil zemin, kayan beyaz topuz; basılı tutunca topuz uzar. */
Item {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.round(46 * Theme.scale)
    implicitHeight: Math.round(28 * Theme.scale)
    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: flip()
    Accessible.onPressAction: flip()
    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()

    function flip() {
        checked = !checked
        toggled(checked)
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.green : Theme.fillStrong
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.tint(Theme.accent, 0.6)
        Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }

        Rectangle {
            id: knob
            readonly property real d: parent.height - 4
            // Basılıyken topuz uzar. Uzama her zaman sağ kenarı (açıkken) ya da sol kenarı (kapalıyken)
            // sabit tutar: konum, uzamaya bağlı hesaplanır; ikisi ayrı ayrı animasyonlu, çakışmazlar.
            property real stretch: mouse.pressed ? d * 0.18 : 0
            Behavior on stretch { NumberAnimation { duration: Theme.quick; easing.type: Theme.easing } }
            // 0 = kapalı (sol), 1 = açık (sağ). Konum ve renk aynı süre ve eğriyle gider.
            property real pos: root.checked ? 1 : 0
            Behavior on pos { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }

            width: d + stretch
            height: d
            radius: d / 2
            y: 2
            x: 2 + pos * (parent.width - 4 - width)
            color: "white"
            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.topMargin: 1.5
                anchors.bottomMargin: -1.5
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.18)
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.flip()
    }
}
