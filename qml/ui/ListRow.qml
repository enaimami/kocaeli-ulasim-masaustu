import QtQuick
import QtQuick.Layouts

/**
 * Gruplu karttaki satır. Basıldığı an (bırakmayı beklemeden) vurgulanır, üzerine gelince hafif
 * tonlanır; tıklama bırakınca işlenir. Solda isteğe bağlı öğe, ortada başlık + alt satır,
 * sağda isteğe bağlı öğe ve ok. Klavye: Tab ile odaklanır, Enter/Boşluk ile açılır.
 */
Item {
    id: root

    property string title
    property string subtitle
    property int subtitleLines: 1
    property bool chevron: false
    property bool clickable: true
    property bool isLast: false
    property alias leading: leadingSlot.data
    property alias trailing: trailingSlot.data
    /** Başlık ile alt satır arasına özel içerik (rozet dizisi vb.). */
    property alias extra: extraSlot.data
    property string titleStyle: "body"
    property int titleWeight: -1
    property color titleColor: Theme.label
    /** Satır içeriğinin sol girintisi (ayraç da buradan başlar). */
    readonly property real textInset: leadingSlot.children.length > 0 ? leadingSlot.x + leadingSlot.width + Theme.gap * 1.5 : Theme.margin

    signal clicked()

    implicitHeight: Math.max(Theme.rowHeight, layout.implicitHeight + Theme.unit * 5)
    width: parent ? parent.width : implicitWidth
    activeFocusOnTab: clickable
    Accessible.role: clickable ? Accessible.Button : Accessible.StaticText
    Accessible.name: title + (subtitle ? ", " + subtitle : "")
    Accessible.onPressAction: if (clickable) root.clicked()
    Keys.onReturnPressed: if (clickable) root.clicked()
    Keys.onSpacePressed: if (clickable) root.clicked()

    Rectangle {
        anchors.fill: parent
        color: mouse.pressed ? Theme.pressed : (mouse.containsMouse || root.activeFocus) ? Theme.hover : "transparent"
        // Basışta anında, bırakınca yumuşak.
        Behavior on color { enabled: !mouse.pressed; ColorAnimation { duration: Theme.standard; easing.type: Theme.easing } }
    }

    // Klavye odağı: satır içinde ince vurgu çerçevesi. Fare tıklaması odak vermediği için tıklamada çıkmaz.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.unit * 0.5
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: 2
        border.color: Theme.tint(Theme.accent, 0.7)
        opacity: root.activeFocus ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick; easing.type: Theme.easing } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin * 0.75
        spacing: Theme.gap * 1.5

        Item {
            id: leadingSlot
            visible: children.length > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: Theme.unit * 0.75
            Layout.fillWidth: true
            Layout.topMargin: Theme.unit * 2.5
            Layout.bottomMargin: Theme.unit * 2.5
            Txt {
                text: root.title
                style: root.titleStyle
                weight: root.titleWeight
                color: root.titleColor
                visible: text.length > 0
                Layout.fillWidth: true
            }
            Item {
                id: extraSlot
                visible: children.length > 0
                implicitHeight: childrenRect.height
                Layout.fillWidth: true
            }
            Txt {
                text: root.subtitle
                style: "subhead"
                secondary: true
                visible: text.length > 0
                maximumLineCount: root.subtitleLines
                wrapMode: root.subtitleLines > 1 ? Text.Wrap : Text.NoWrap
                Layout.fillWidth: true
            }
        }

        Item {
            id: trailingSlot
            visible: children.length > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }

        Symbol {
            visible: root.chevron
            name: "chevron"
            size: 13
            color: Theme.tertiaryLabel
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Rectangle {
        visible: !root.isLast
        x: root.textInset
        width: parent.width - x
        anchors.bottom: parent.bottom
        height: 1 / Screen.devicePixelRatio
        color: Theme.separator
    }
}
