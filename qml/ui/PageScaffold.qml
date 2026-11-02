import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/**
 * Sayfa iskeleti: üstte buzlu cam çubuk (içerik altından kayar; bulanık görünür), içerikte büyük
 * başlık. Büyük başlık kaydırılıp çubuğun altına girince çubukta küçük başlık belirir.
 * Kalan alanı dolduran içerik (harita) için `fillHeight` kullanılır; içerik sığarsa kaydırma kapanır.
 */
Kirigami.Page {
    id: page

    property string largeTitle: title
    property string subtitle
    /** Büyük başlığın solunda (hat rozeti vb.). */
    property alias titleLeading: leadingSlot.data
    /** Üst çubuğun sağındaki düğmeler. */
    property alias barActions: actionsRow.data
    /** Büyük başlığın altında, kaydırılmayan içerikte de görünen alan (arama, segment). */
    property alias headerExtra: extraSlot.data
    default property alias content: column.data
    property bool showLargeTitle: true
    /** Ağ yanıtı geldiğinde sayfa kapanmış olabilir; geri çağrılar `self.alive` ile denetler. */
    property bool alive: true
    Component.onDestruction: alive = false
    readonly property bool canGoBack: Kirigami.ColumnView.index > 0
    readonly property alias flickable: flick
    /** Büyük başlığın altında kalan görünür yükseklik (alanı dolduran içerik için). */
    readonly property real fillHeight: flick.height - barHeight - (header.visible ? header.height + column.spacing : 0) - Theme.margin * 2

    function goBack() {
        const stack = applicationWindow().pageStack
        const i = Kirigami.ColumnView.index
        if (i > 0)
            stack.pop(stack.get(i - 1))
    }

    padding: 0
    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None
    background: Rectangle { color: Theme.background }

    Shortcut {
        sequences: ["Alt+Left", "Esc"]
        enabled: page.canGoBack && page.Kirigami.ColumnView.inViewport && page.isCurrentPage
        onActivated: page.goBack()
    }

    readonly property real barHeight: Math.round(52 * Theme.scale)
    /** Büyük başlık ne kadar çubuğun altına girdi (0…1): küçük başlık bununla belirir. */
    readonly property real collapse: Math.max(0, Math.min(1, (flick.contentY - header.titleBottom + barHeight * 0.6) / (barHeight * 0.5)))

    // ---------- İçerik ----------
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + page.barHeight + Theme.margin * 2
        // İçerik sığıyorsa kaydırma yok (haritadaki sürüklemeyi kapmasın).
        interactive: contentHeight > height + 1
        boundsBehavior: Flickable.DragOverBounds
        flickDeceleration: 2600
        maximumFlickVelocity: 5200
        clip: true
        QQC2.ScrollBar.vertical: ScrollIndicator {}

        ColumnLayout {
            id: column
            y: page.barHeight
            width: flick.width
            spacing: Theme.margin * 1.5

            ColumnLayout {
                id: header
                readonly property real titleBottom: y + titleRow.y + titleRow.height
                visible: page.showLargeTitle
                spacing: Theme.unit * 2
                Layout.fillWidth: true
                Layout.maximumWidth: Theme.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: Theme.margin * 1.25
                Layout.rightMargin: Theme.margin * 1.25
                Layout.topMargin: Theme.unit

                RowLayout {
                    id: titleRow
                    spacing: Theme.gap * 1.5
                    Layout.fillWidth: true
                    Item {
                        id: leadingSlot
                        visible: children.length > 0
                        implicitWidth: childrenRect.width
                        implicitHeight: childrenRect.height
                    }
                    ColumnLayout {
                        spacing: Theme.unit * 0.5
                        Layout.fillWidth: true
                        Txt {
                            text: page.largeTitle
                            style: "largeTitle"
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            Layout.fillWidth: true
                            Accessible.role: Accessible.Heading
                            Accessible.name: text
                        }
                        Txt {
                            visible: page.subtitle.length > 0
                            text: page.subtitle
                            style: "subhead"
                            secondary: true
                            Layout.fillWidth: true
                        }
                    }
                }
                Item {
                    id: extraSlot
                    visible: children.length > 0
                    implicitHeight: childrenRect.height
                    Layout.fillWidth: true
                }
            }
        }
    }

    // ---------- Üst çubuk (buzlu cam) ----------
    Item {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        height: page.barHeight
        z: 10

        // Altındaki içeriğin bulanık kopyası; yalnızca içerik çubuğun altına girdiğinde görünür.
        ShaderEffectSource {
            id: barSource
            sourceItem: flick
            sourceRect: Qt.rect(0, 0, bar.width, bar.height)
            live: page.collapse > 0
            visible: false
            hideSource: false
        }
        MultiEffect {
            anchors.fill: parent
            source: barSource
            visible: page.collapse > 0
            opacity: page.collapse
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 2.5
            saturation: 0.5
            brightness: Theme.dark ? -0.05 : 0.03
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            opacity: 1 - page.collapse * 0.12
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1 / Screen.devicePixelRatio
            color: Theme.separator
            opacity: page.collapse
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.unit * 2
            anchors.rightMargin: Theme.unit * 2
            spacing: Theme.unit

            // "‹ Geri"
            Item {
                id: backButton
                visible: page.canGoBack
                implicitWidth: backRow.implicitWidth + Theme.unit * 2
                implicitHeight: parent.height
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Geri"
                Accessible.onPressAction: page.goBack()
                Keys.onReturnPressed: page.goBack()
                Row {
                    id: backRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.unit
                    spacing: 0
                    opacity: backMouse.pressed ? 0.4 : 1
                    Symbol { name: "chevronLeft"; size: 28; weight: 400; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: "Geri"; style: "body"; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.goBack()
                }
            }
            Item { Layout.fillWidth: true }
            Row {
                id: actionsRow
                spacing: Theme.unit
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Ortalanmış küçük başlık.
        Txt {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 2 * Math.max(backButton.width, actionsRow.width) - Theme.margin * 2)
            text: page.title
            style: "headline"
            horizontalAlignment: Text.AlignHCenter
            opacity: page.collapse
        }
    }
}
