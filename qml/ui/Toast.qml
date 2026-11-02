import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

/**
 * iOS tarzı geçici balon: pencerenin altında ortada bir kapsül, isteğe bağlı eylem ("Geri al").
 * Alttan yükselip belirerek gelir, süre dolunca aynı yoldan gider; fare üstündeyken süre durur.
 * Yeni mesaj gelirse mevcut balon yerinde güncellenir. Tek giriş: `show()`.
 */
QQC2.Popup {
    id: root

    property string text
    property string actionText
    property var action: null
    /** Kalan süre (ms); fare üstündeyken azalmaz. */
    property int remaining: 0

    function show(message, label, callback, ms) {
        text = message
        actionText = label || ""
        action = callback || null
        remaining = ms > 0 ? ms : 3500
        if (!visible || !opened)
            open()
    }

    parent: QQC2.Overlay.overlay
    modal: false
    focus: false
    closePolicy: QQC2.Popup.NoAutoClose
    padding: 0
    readonly property real rest: parent ? parent.height - height - Math.round(28 * Theme.scale) : 0
    x: parent ? Math.round((parent.width - width) / 2) : 0
    property real slide: Math.round(18 * Theme.scale)
    y: rest + slide
    width: Math.min(implicitWidth, parent ? parent.width - Theme.margin * 2 : implicitWidth)

    Timer {
        interval: 100
        repeat: true
        running: root.opened && !hover.hovered
        onTriggered: {
            root.remaining -= interval
            if (root.remaining <= 0)
                root.close()
        }
    }

    opacity: 0
    enter: Transition {
        NumberAnimation { property: "opacity"; to: 1; duration: Theme.standard; easing.type: Theme.easing }
        NumberAnimation { property: "slide"; to: 0; duration: Theme.slow; easing.type: Theme.easing }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.standard; easing.type: Theme.easing }
        NumberAnimation { property: "slide"; to: Math.round(12 * Theme.scale); duration: Theme.standard; easing.type: Theme.easing }
    }

    background: Rectangle {
        radius: height / 2
        color: Theme.cardElevated
        border.width: 1 / Screen.devicePixelRatio
        border.color: Theme.separator
        // Yumuşak gölge: üst üste yarı saydam, giderek büyüyen kapsüller.
        Repeater {
            model: 3
            Rectangle {
                required property int index
                z: -1
                anchors.fill: parent
                anchors.margins: -(index + 1) * 3 * Theme.scale
                anchors.topMargin: -(index + 1) * 2 * Theme.scale
                anchors.bottomMargin: -(index + 1) * 5 * Theme.scale
                radius: height / 2
                color: Qt.rgba(0, 0, 0, Theme.dark ? 0.16 : 0.035)
            }
        }
    }

    contentItem: RowLayout {
        spacing: Theme.gap * 1.5
        HoverHandler { id: hover }

        Txt {
            text: root.text
            style: "subhead"
            Layout.leftMargin: Theme.margin * 1.25
            Layout.rightMargin: root.actionText ? 0 : Theme.margin * 1.25
            Layout.topMargin: Theme.gap * 1.4
            Layout.bottomMargin: Theme.gap * 1.4
            Layout.maximumWidth: Math.round(420 * Theme.scale)
            Accessible.role: Accessible.AlertMessage
            Accessible.name: text
        }
        LinkButton {
            visible: root.actionText.length > 0
            text: root.actionText
            style: "subhead"
            Layout.rightMargin: Theme.margin
            onClicked: {
                const a = root.action
                root.close()
                if (a) a()
            }
        }
    }
}
