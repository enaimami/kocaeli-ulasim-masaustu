import QtQuick
import QtQuick.Layouts

/** Boş/hata durumu: büyük soluk simge, başlık, açıklama ve isteğe bağlı eylem. */
ColumnLayout {
    id: root

    property string icon
    property string title
    property string message
    property string actionText
    property bool isLast: false

    signal action()

    spacing: Theme.unit * 2
    width: parent ? parent.width : implicitWidth

    Item { implicitHeight: Theme.margin }
    Symbol {
        visible: root.icon.length > 0
        name: root.icon
        size: 40
        weight: 300
        color: Theme.tertiaryLabel
        Layout.alignment: Qt.AlignHCenter
    }
    Txt {
        text: root.title
        style: "headline"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.leftMargin: Theme.margin
        Layout.rightMargin: Theme.margin
    }
    Txt {
        visible: root.message.length > 0
        text: root.message
        style: "subhead"
        secondary: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
        Layout.leftMargin: Theme.margin * 2
        Layout.rightMargin: Theme.margin * 2
    }
    PillButton {
        visible: root.actionText.length > 0
        text: root.actionText
        compact: true
        Layout.alignment: Qt.AlignHCenter
        onClicked: root.action()
    }
    Item { implicitHeight: Theme.margin }
}
