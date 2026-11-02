import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

/**
 * iOS tarzı kalıcı pencere: arka plan karartılır, kart yumuşak gölgeyle hafifçe büyüyerek ve
 * belirerek gelir (aynı yoldan gider; yarıda kesilince bulunduğu yerden döner). Pencere içeriğini
 * ölçekleyip "geri çekmek" Overlay'in altındaki Kirigami yığınını bozacağından yapılmaz. Üstte "Vazgeç" + başlık, altta büyük ana düğme.
 * İçerik uzunsa kaydırılır. Esc kapatır.
 */
QQC2.Popup {
    id: root

    property string title
    property string primaryText
    property string primaryIcon
    property bool primaryEnabled: true
    property color primaryTint: Theme.accent
    property string cancelText: "Vazgeç"
    property real preferredWidth: 460 * Theme.scale
    default property alias content: body.data

    signal accepted()

    parent: QQC2.Overlay.overlay
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: Math.min(preferredWidth, parent ? parent.width - Theme.margin * 2 : preferredWidth)
    height: Math.min(implicitHeight, parent ? parent.height - Theme.margin * 3 : implicitHeight)
    padding: 0

    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.55 : 0.3)
        Behavior on opacity { NumberAnimation { duration: Theme.standard; easing.type: Theme.easing } }
    }

    // Belirme: hafif büyüme + saydamlık; kapanış aynı yolun tersi.
    // Başlangıç değeri verilmez: kapanırken açılış kesilirse (ve tersi) bulunduğu yerden sürer.
    opacity: 0
    scale: 0.94
    enter: Transition {
        NumberAnimation { property: "opacity"; to: 1; duration: Theme.standard; easing.type: Theme.easing }
        NumberAnimation { property: "scale"; to: 1; duration: Theme.slow; easing.type: Theme.easing }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.standard; easing.type: Theme.easing }
        NumberAnimation { property: "scale"; to: 0.94; duration: Theme.standard; easing.type: Theme.easing }
    }

    background: Item {
        // Yumuşak gölge: üst üste yarı saydam, giderek yayılan katmanlar (kart dışına taşar).
        Repeater {
            model: 5
            Rectangle {
                required property int index
                z: -1
                anchors.fill: parent
                anchors.margins: -(index + 1) * 5 * Theme.scale
                anchors.topMargin: -(index + 1) * 3 * Theme.scale
                anchors.bottomMargin: -(index + 1) * 8 * Theme.scale
                radius: Theme.radius * 1.4 + (index + 1) * 5 * Theme.scale
                color: Qt.rgba(0, 0, 0, Theme.dark ? 0.14 : 0.04)
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius * 1.4
            color: Theme.dark ? "#1C1C1E" : "#F2F2F7"
            border.width: Theme.dark ? 1 / Screen.devicePixelRatio : 0
            border.color: Qt.rgba(1, 1, 1, 0.1)
        }
    }

    contentItem: ColumnLayout {
        spacing: 0
        implicitHeight: header.implicitHeight + scroll.implicitHeight + footer.implicitHeight

        // Üst çubuk
        Item {
            id: header
            Layout.fillWidth: true
            implicitHeight: Math.round(52 * Theme.scale)
            LinkButton {
                anchors.left: parent.left
                anchors.leftMargin: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                visible: root.cancelText.length > 0
                text: root.cancelText
                style: "body"
                onClicked: root.close()
            }
            Txt {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Math.round(180 * Theme.scale))
                text: root.title
                style: "headline"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: body.implicitHeight + Theme.margin
            contentHeight: body.implicitHeight + Theme.margin
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: ScrollIndicator {}

            ColumnLayout {
                id: body
                width: scroll.width
                spacing: Theme.margin * 1.25
            }
        }

        Item {
            id: footer
            Layout.fillWidth: true
            visible: root.primaryText.length > 0
            implicitHeight: visible ? primary.implicitHeight + Theme.margin * 2 : 0
            PillButton {
                id: primary
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.margin
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: Math.round(46 * Theme.scale)
                kind: "filled"
                tint: root.primaryTint
                text: root.primaryText
                icon: root.primaryIcon
                enabled: root.primaryEnabled
                onClicked: root.accepted()
            }
        }
    }
}
