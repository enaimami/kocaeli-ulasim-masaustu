import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import ".."

/**
 * iOS eylem sayfası: altta ortada, alttan kayarak gelir. Üstte başlık + seçenek satırları (hat
 * rozeti + yön), altında ayrı "Vazgeç" kartı. Yön tuşları gezinir, Enter/Boşluk seçer, Esc kapatır.
 * Satır verisi: { routeCode, headSign, color, textColor }.
 */
QQC2.Popup {
    id: root

    property string title
    property string cancelText: "Vazgeç"
    property var model: []
    signal chosen(var item)

    parent: QQC2.Overlay.overlay
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    padding: 0
    readonly property real rest: parent ? parent.height - height - Theme.margin : 0
    x: parent ? Math.round((parent.width - width) / 2) : 0
    // Kayma payı: kapalıyken pencerenin dışında, açılırken 0'a iner (y'yi doğrudan canlandırmak
    // yükseklik sonradan değişince yanlış yerde kalıyordu).
    property real slide: parent ? parent.height : 0
    y: rest + slide
    width: Math.min(Math.round(400 * Theme.scale), parent ? parent.width - Theme.margin * 2 : 400)
    opacity: 0

    onOpened: list.forceActiveFocus()
    onAboutToShow: list.currentIndex = 0

    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.5 : 0.28)
    }

    // Giriş ve çıkış aynı yolun iki yönü; başlangıç değeri verilmediği için yarıda kesilince
    // bulunduğu yerden döner.
    enter: Transition {
        NumberAnimation { property: "opacity"; to: 1; duration: Theme.standard; easing.type: Theme.easing }
        NumberAnimation { property: "slide"; to: 0; duration: Theme.slow; easing.type: Theme.easing }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.standard; easing.type: Theme.easing }
        NumberAnimation { property: "slide"; to: root.height + Theme.margin * 2; duration: Theme.standard; easing.type: Theme.easing }
    }

    background: Item {}

    contentItem: ColumnLayout {
        spacing: Theme.gap

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: card.implicitHeight
            radius: Theme.radius * 1.3
            color: Theme.cardElevated
            clip: true

            ColumnLayout {
                id: card
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Txt {
                    visible: root.title.length > 0
                    text: root.title
                    style: "footnote"
                    secondary: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.gap * 1.5
                    Layout.bottomMargin: Theme.gap * 1.5
                    Layout.leftMargin: Theme.margin
                    Layout.rightMargin: Theme.margin
                }
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, Math.round(Theme.rowHeight * 6.5))
                    model: root.model
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 0
                    QQC2.ScrollBar.vertical: ScrollIndicator {}
                    Keys.onReturnPressed: pick(currentItem)
                    Keys.onEnterPressed: pick(currentItem)
                    Keys.onSpacePressed: pick(currentItem)
                    function pick(it) {
                        if (it) it.choose()
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: Math.round(Theme.rowHeight * 1.15)
                        readonly property bool current: ListView.isCurrentItem && list.activeFocus
                        function choose() {
                            root.close()
                            root.chosen(modelData)
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: mouse.pressed ? Theme.pressed : (mouse.containsMouse || row.current) ? Theme.hover : "transparent"
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1 / Screen.devicePixelRatio
                            color: Theme.separator
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.margin
                            anchors.rightMargin: Theme.margin
                            spacing: Theme.gap * 1.5
                            RouteBadge {
                                code: row.modelData.routeCode
                                badgeColor: row.modelData.color
                                textColor: row.modelData.textColor
                                minWidth: Math.round(52 * Theme.scale)
                            }
                            Txt {
                                text: row.modelData.headSign || "Tüm yönler"
                                style: "body"
                                color: Theme.accent
                                Layout.fillWidth: true
                            }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = row.index
                            onClicked: row.choose()
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: row.modelData.routeCode + (row.modelData.headSign ? ", " + row.modelData.headSign : "")
                        Accessible.onPressAction: row.choose()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.round(Theme.rowHeight * 1.15)
            radius: Theme.radius * 1.3
            color: cancelMouse.pressed ? Theme.fillStrong : Theme.cardElevated
            Txt {
                anchors.centerIn: parent
                text: root.cancelText
                style: "body"
                weight: 600
                color: Theme.accent
            }
            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
            }
            Accessible.role: Accessible.Button
            Accessible.name: root.cancelText
            Accessible.onPressAction: root.close()
        }
    }
}
