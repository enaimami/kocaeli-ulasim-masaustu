import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

/** iOS arama kutusu: dolgu zeminli, büyüteç, temizle düğmesi; odaktayken sağda "Vazgeç". */
RowLayout {
    id: root

    property alias text: field.text
    property alias placeholder: field.placeholderText
    readonly property bool focused: field.activeFocus
    readonly property bool hasText: field.text.length > 0
    /** Vazgeç'in görünme oranı (0 gizli, 1 tam). Genişlik, konum ve saydamlık bunu izler. */
    property real cancelT: field.activeFocus || hasText ? 1 : 0
    Behavior on cancelT { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }

    signal accepted()

    function focusField() {
        field.forceActiveFocus()
        field.selectAll()
    }
    function cancel() {
        field.text = ""
        field.focus = false
    }

    // Aralık Vazgeç'in kendi sol boşluğunda: gizliyken kutunun yanında boşluk kalmaz.
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.round(36 * Theme.scale)
        radius: Theme.radiusSmall + 2
        color: Theme.fill

        // Odak çerçevesi: genişlik sabit, yalnızca saydamlık değişir (solarak gelir).
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: Theme.tint(Theme.accent, 0.5)
            opacity: field.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.quick; easing.type: Theme.easing } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.unit * 2
            anchors.rightMargin: Theme.unit * 1.5
            spacing: Theme.unit * 1.5
            Symbol { name: "search"; size: 18; color: Theme.secondaryLabel }
            QQC2.TextField {
                id: field
                Layout.fillWidth: true
                background: null
                padding: 0
                color: Theme.label
                placeholderTextColor: Theme.secondaryLabel
                selectionColor: Theme.tint(Theme.accent, 0.35)
                selectedTextColor: Theme.label
                font.family: Theme.family
                font.pixelSize: Theme.type.body.size * Theme.scale
                font.letterSpacing: Theme.type.body.tracking * Theme.type.body.size * Theme.scale
                onAccepted: root.accepted()
                Keys.onEscapePressed: root.cancel()
                Accessible.name: placeholderText
            }
            // Temizle düğmesi: yer her zaman ayrılır (metin genişliği zıplamasın); simge solar ve hafif büyür.
            Item {
                implicitWidth: Math.round(17 * Theme.scale)
                implicitHeight: clear.implicitHeight
                Symbol {
                    id: clear
                    anchors.centerIn: parent
                    name: "cancel"
                    filled: true
                    size: 17
                    color: Theme.tertiaryLabel
                    opacity: root.hasText ? 1 : 0
                    scale: root.hasText ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: Theme.quick; easing.type: Theme.easing } }
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.easing } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        enabled: root.hasText
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { field.text = ""; field.forceActiveFocus() }
                    }
                }
            }
        }
    }

    // Vazgeç: sağdan kayarak ve solarak gelir/gider; genişliği kutuyu yumuşakça daraltır/genişletir.
    Item {
        id: cancelSlot
        visible: root.cancelT > 0
        clip: true
        opacity: root.cancelT
        implicitWidth: (cancelBtn.implicitWidth + Theme.gap) * root.cancelT
        implicitHeight: cancelBtn.implicitHeight

        LinkButton {
            id: cancelBtn
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.gap + (1 - root.cancelT) * Theme.unit * 6
            text: "Vazgeç"
            style: "body"
            onClicked: root.cancel()
        }
    }
}
