import QtQuick

/** iOS etkinlik göstergesi: dönen sekiz çizgi, soluklaşan kuyruk. */
Item {
    id: root

    property bool running: true
    property real size: 20
    property color color: Theme.secondaryLabel

    implicitWidth: Math.round(size * Theme.scale)
    implicitHeight: implicitWidth
    visible: running

    Repeater {
        model: 8
        Rectangle {
            required property int index
            x: root.width / 2 - width / 2
            y: 0
            width: root.width * 0.1
            height: root.height * 0.28
            radius: width / 2
            color: root.color
            opacity: 1 - index / 9
            transform: Rotation {
                origin.x: width / 2
                origin.y: root.height / 2
                angle: -index * 45
            }
        }
    }

    // Kesikli dönüş (iOS gibi 8 adım), saniyede bir tur.
    property int step: 0
    rotation: step * 45
    Timer {
        interval: 1000 / 8
        repeat: true
        running: root.running && root.visible
        onTriggered: root.step = (root.step + 1) % 8
    }
}
