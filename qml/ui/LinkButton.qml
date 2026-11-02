import QtQuick

/** Vurgu renginde metin düğmesi ("Tümünü göster", "Vazgeç"). */
Txt {
    id: root

    signal clicked()

    style: "callout"
    color: Theme.accent
    opacity: !enabled ? 0.4 : mouse.pressed ? 0.45 : 1
    activeFocusOnTab: true
    font.underline: activeFocus

    Behavior on opacity { enabled: !mouse.pressed; NumberAnimation { duration: Theme.standard } }

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -Theme.unit * 1.5
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
