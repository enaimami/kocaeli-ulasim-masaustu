import QtQuick
import QtQuick.Controls as QQC2

/** macOS tarzı kaydırma çubuğu: zeminsiz ince kapsül; kaydırırken ya da üzerine gelince belirir, sonra söner. */
QQC2.ScrollBar {
    id: root

    policy: QQC2.ScrollBar.AsNeeded
    padding: 2
    minimumSize: 0.08

    background: null
    contentItem: Rectangle {
        implicitWidth: root.hovered || root.pressed ? 8 : 6
        radius: width / 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, root.pressed ? 0.55 : 0.4) : Qt.rgba(0, 0, 0, root.pressed ? 0.5 : 0.35)
        opacity: root.active || root.hovered ? 1 : 0
        visible: root.size < 1
        Behavior on opacity { NumberAnimation { duration: root.active ? Theme.quick : Theme.slow * 2 } }
        Behavior on implicitWidth { NumberAnimation { duration: Theme.quick } }
    }
}
