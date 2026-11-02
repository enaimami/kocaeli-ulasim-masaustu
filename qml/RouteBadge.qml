import QtQuick
import "ui"

/** Hat rozeti: API'nin hat rengi zemin, yazı rengiyle kod; iOS tarzı yuvarlatılmış dikdörtgen. */
Rectangle {
    id: root

    property string code
    property color badgeColor: "#1EA9BD"
    property color textColor: "white"
    property bool large: false
    /** Satır listelerinde rozetler aynı genişlikte hizalansın. */
    property real minWidth: 0

    implicitHeight: Math.round((large ? 34 : 22) * Theme.scale)
    implicitWidth: Math.max(minWidth, label.implicitWidth + implicitHeight * (large ? 0.7 : 0.55), implicitHeight * 1.35)
    radius: large ? Theme.radiusSmall : Math.round(6 * Theme.scale)
    color: badgeColor
    // Açık zeminde çok açık renkli rozetler kaybolmasın.
    border.width: (0.299 * badgeColor.r + 0.587 * badgeColor.g + 0.114 * badgeColor.b) > 0.8 ? 1 : 0
    border.color: Theme.separator

    Txt {
        id: label
        anchors.centerIn: parent
        text: root.code
        color: root.textColor
        style: root.large ? "title3" : "footnote"
        weight: root.large ? 750 : 700
        tabular: true
        Accessible.ignored: true
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: "Hat " + code
}
