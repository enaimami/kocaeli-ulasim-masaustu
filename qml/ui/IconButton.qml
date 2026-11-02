import QtQuick
import QtQuick.Controls as QQC2

/** Yuvarlak simge düğmesi (üst çubuk, harita denetimleri). `circle`: dolgu zeminli daire. */
Item {
    id: root

    property string icon
    property bool filled: false
    property bool circle: false
    property color color: Theme.accent
    property string tooltip
    property real size: 32

    signal clicked()

    implicitWidth: Math.round(size * Theme.scale)
    implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0.35
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    // Dolu olunca (zil → turuncu dolu daire, yıldız → sarı dolu) simge kısa bir "pop" yapar.
    onFilledChanged: if (filled && Theme.motion) pop.restart()
    SequentialAnimation {
        id: pop
        NumberAnimation { target: glyph; property: "scale"; to: 1.25; duration: Theme.quick; easing.type: Theme.easing }
        NumberAnimation { target: glyph; property: "scale"; to: 1; duration: Theme.quick; easing.type: Theme.easing }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.circle ? Theme.cardElevated : (mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.hover : "transparent")
        // Daire zemini ve renk değişimi birlikte solarak geçer; basılıyken anında (dokunuşa tepki).
        Behavior on color { enabled: !mouse.pressed; ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.tint(Theme.accent, 0.6)
        scale: mouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: mouse.pressed ? Theme.quick : Theme.standard; easing.type: Theme.easing } }

        Symbol {
            id: glyph
            anchors.centerIn: parent
            name: root.icon
            filled: root.filled
            size: root.size * 0.6
            weight: 500
            color: root.color
            Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    QQC2.ToolTip.text: tooltip
    QQC2.ToolTip.visible: tooltip.length > 0 && mouse.containsMouse
    QQC2.ToolTip.delay: 600
}
