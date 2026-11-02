import QtQuick
import QtQuick.Layouts

/**
 * Kapsül düğme. `kind`: "filled" (vurgu zeminli, beyaz yazı), "tinted" (vurgunun soluk zemini),
 * "plain" (yalnızca dolgu). Basıldığı an hafifçe küçülür ve kararır; bırakınca yerine yumuşakça döner.
 */
Item {
    id: root

    property string text
    property string icon
    property bool iconFilled: false
    property string kind: "tinted"
    property color tint: Theme.accent
    property bool compact: false
    property bool checked: false

    signal clicked()

    readonly property color fg: kind === "filled" ? "white" : (kind === "plain" ? Theme.label : tint)
    readonly property color bg: kind === "filled" ? tint : (kind === "plain" ? Theme.fill : Theme.tint(tint, Theme.dark ? 0.2 : 0.12))

    implicitHeight: Math.round((compact ? 28 : 34) * Theme.scale)
    // Yazı uzayınca (ör. "Takip et" → "Takipte") genişlik yumuşakça değişir.
    implicitWidth: text.length > 0 ? row.implicitWidth + implicitHeight * 0.9 : implicitHeight
    Behavior on implicitWidth { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.checked: checked
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    // Durum açılınca (Favori → Favoride, Takip et → Takipte) simge kısa bir "pop" yapar.
    onCheckedChanged: if (checked && Theme.motion) pop.restart()
    onIconFilledChanged: if (iconFilled && Theme.motion) pop.restart()
    SequentialAnimation {
        id: pop
        NumberAnimation { target: glyph; property: "scale"; to: 1.25; duration: Theme.quick; easing.type: Theme.easing }
        NumberAnimation { target: glyph; property: "scale"; to: 1; duration: Theme.quick; easing.type: Theme.easing }
    }

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: height / 2
        color: root.bg
        Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.tint(Theme.accent, 0.6)
        scale: mouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: mouse.pressed ? Theme.quick : Theme.standard; easing.type: Theme.easing } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: mouse.pressed ? Qt.rgba(0, 0, 0, 0.15) : mouse.containsMouse ? Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.12) : "transparent"
            Behavior on color { enabled: !mouse.pressed; ColorAnimation { duration: Theme.standard } }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Theme.unit * 1.25
            Symbol {
                id: glyph
                visible: root.icon.length > 0
                name: root.icon
                filled: root.iconFilled
                size: root.compact ? 15 : 17
                weight: 500
                color: root.fg
                Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
            }
            Txt {
                visible: root.text.length > 0
                text: root.text
                style: root.compact ? "footnote" : "callout"
                weight: 600
                color: root.fg
                Behavior on color { ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
