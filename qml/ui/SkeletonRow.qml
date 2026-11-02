import QtQuick
import QtQuick.Layouts

/** Yüklenirken yer tutucu satır: soluk bloklar ve üzerinden geçen parıltı. */
Item {
    id: root

    property bool isLast: false
    property bool leadingBlock: true

    width: parent ? parent.width : 0
    implicitHeight: Math.round(58 * Theme.scale)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        spacing: Theme.gap * 1.5
        Rectangle {
            visible: root.leadingBlock
            implicitWidth: Math.round(40 * Theme.scale)
            implicitHeight: Math.round(22 * Theme.scale)
            radius: 6
            color: Theme.fill
        }
        ColumnLayout {
            spacing: Theme.unit * 1.5
            Layout.fillWidth: true
            Rectangle { implicitHeight: 11 * Theme.scale; Layout.preferredWidth: parent.width * 0.62; radius: 5; color: Theme.fill }
            Rectangle { implicitHeight: 9 * Theme.scale; Layout.preferredWidth: parent.width * 0.38; radius: 4.5; color: Theme.fill }
        }
    }

    // Parıltı (azaltılmış harekette yok).
    Rectangle {
        id: shimmer
        visible: Theme.motion
        width: parent.width * 0.35
        height: parent.height
        opacity: Theme.dark ? 0.05 : 0.35
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
        NumberAnimation on x {
            from: -shimmer.width
            to: root.width
            duration: 1400
            loops: Animation.Infinite
            running: shimmer.visible && root.visible
        }
    }

    Rectangle {
        visible: !root.isLast
        x: Theme.margin
        width: parent.width - x
        anchors.bottom: parent.bottom
        height: 1 / Screen.devicePixelRatio
        color: Theme.separator
    }
}
