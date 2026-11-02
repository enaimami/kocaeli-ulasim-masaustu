import QtQuick
import QtQuick.Layouts

/** Bilgi/uyarı/hata bandı: renkli simge, metin, isteğe bağlı eylem. Yuvarlak, renk tonlu zemin. */
Rectangle {
    id: root

    property string kind: "info" // info, warning, error
    property string text
    property string actionText
    property int maxLines: 4

    signal action()

    readonly property color tone: kind === "error" ? Theme.red : kind === "warning" ? Theme.orange : Theme.accent

    Layout.fillWidth: true
    Layout.maximumWidth: Theme.contentMaxWidth
    Layout.alignment: Qt.AlignHCenter
    implicitHeight: row.implicitHeight + Theme.unit * 5
    radius: Theme.radius
    color: Theme.tint(tone, Theme.dark ? 0.18 : 0.1)

    // Görünür olunca (visible false→true) kısa solma + 6 px yukarı kayma. transform kullanılır:
    // düzen (Layout) konumları değişmez.
    opacity: 1
    transform: Translate { id: enterShift; y: 0 }

    onVisibleChanged: {
        enterAnim.stop()
        if (!visible || !Theme.motion) {
            opacity = 1
            enterShift.y = 0
            return
        }
        opacity = 0
        enterShift.y = 6 * Theme.scale
        enterAnim.start()
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.standard; easing.type: Theme.easing }
        NumberAnimation { target: enterShift; property: "y"; to: 0; duration: Theme.standard; easing.type: Theme.easing }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        spacing: Theme.gap * 1.5
        Symbol {
            name: root.kind === "error" ? "wifiOff" : root.kind === "warning" ? "error" : "info"
            filled: true
            size: 20
            color: root.tone
            // Tek satır: ortada; çok satır: ilk satırla hizalı.
            Layout.alignment: body.lineCount > 1 ? Qt.AlignTop : Qt.AlignVCenter
            Layout.topMargin: body.lineCount > 1 ? 1 : 0
        }
        Txt {
            id: body
            text: root.text
            style: "subhead"
            wrapMode: Text.Wrap
            maximumLineCount: root.maxLines
            Layout.fillWidth: true
        }
        LinkButton {
            visible: root.actionText.length > 0
            text: root.actionText
            style: "subhead"
            font.weight: 600
            onClicked: root.action()
        }
    }
}
