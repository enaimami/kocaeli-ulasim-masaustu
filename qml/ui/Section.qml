import QtQuick
import QtQuick.Layouts

/**
 * iOS "inset grouped" bölüm: üstte küçük başlık (sağında isteğe bağlı eylem), altında yuvarlak
 * köşeli kart. Karttaki satırlar (ListRow) arasına girintili ayraç kendiliğinden çizilir;
 * son görünür satırın ayracı gizlenir.
 */
ColumnLayout {
    id: root

    property string title
    /** Başlığın sağındaki bağlantı ("Tümünü göster"). */
    property string actionText
    property string footer
    /** Pencere (Sheet) içinde: zeminden ayrışsın diye bir ton açık kart. */
    property bool elevated: false
    default property alias content: card.data
    property alias cardItem: cardBox

    signal actionTriggered()

    spacing: Theme.unit * 1.5

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
    Layout.fillWidth: true
    Layout.maximumWidth: Theme.contentMaxWidth
    Layout.alignment: Qt.AlignHCenter
    Layout.leftMargin: Theme.margin
    Layout.rightMargin: Theme.margin

    RowLayout {
        visible: root.title.length > 0 || root.actionText.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: Theme.margin
        Layout.rightMargin: Theme.margin
        Txt {
            text: root.title
            style: "title3"
            Layout.fillWidth: true
        }
        LinkButton {
            visible: root.actionText.length > 0
            text: root.actionText
            onClicked: root.actionTriggered()
        }
    }

    Rectangle {
        id: cardBox
        Layout.fillWidth: true
        implicitHeight: card.implicitHeight
        radius: Theme.radius
        color: root.elevated ? Theme.cardElevated : Theme.card
        clip: true

        Column {
            id: card
            width: parent.width
            onPositioningComplete: root.markLast()
        }
    }

    Txt {
        visible: root.footer.length > 0
        text: root.footer
        style: "footnote"
        secondary: true
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
        Layout.leftMargin: Theme.margin
        Layout.rightMargin: Theme.margin
    }

    function markLast() {
        let last = null
        for (let i = 0; i < card.children.length; ++i) {
            const c = card.children[i]
            if (c.visible && c.height > 0 && c.isLast !== undefined) {
                c.isLast = false
                last = c
            }
        }
        if (last)
            last.isLast = true
    }
}
