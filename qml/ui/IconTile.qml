import QtQuick

/** iOS Ayarlar'daki gibi renkli, yuvarlatılmış kare içinde beyaz simge. */
Rectangle {
    id: root

    property string icon
    property color tone: Theme.accent
    property real size: 30
    property bool round: false

    implicitWidth: Math.round(size * Theme.scale)
    implicitHeight: implicitWidth
    radius: round ? width / 2 : Math.round(width * 0.24)
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(root.tone, 1.12) }
        GradientStop { position: 1; color: root.tone }
    }

    Symbol {
        anchors.centerIn: parent
        name: root.icon
        filled: true
        size: root.size * 0.62
        weight: 500
        color: "white"
    }
}
