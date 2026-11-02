import QtQuick
import QtQuick.Layouts

/** iOS adımlayıcı: − / + iki parçalı kapsül; ortada değer. Sınırlarda ilgili parça soluklaşır. */
RowLayout {
    id: root

    property int value: 0
    property int from: 0
    property int to: 99
    property bool showValue: true

    signal modified(int value)

    spacing: Theme.gap

    function set(v) {
        v = Math.max(from, Math.min(to, v))
        if (v === value)
            return
        value = v
        modified(v)
    }

    Keys.onUpPressed: set(value + 1)
    Keys.onDownPressed: set(value - 1)

    Txt {
        visible: root.showValue
        text: root.value
        style: "headline"
        tabular: true
        horizontalAlignment: Text.AlignRight
        Layout.minimumWidth: Math.round(22 * Theme.scale)
    }

    Rectangle {
        implicitWidth: Math.round(94 * Theme.scale)
        implicitHeight: Math.round(32 * Theme.scale)
        radius: Theme.radiusSmall
        color: Theme.fill

        Row {
            anchors.fill: parent
            Repeater {
                model: [{ sym: "remove", step: -1 }, { sym: "add", step: 1 }]
                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool can: modelData.step < 0 ? root.value > root.from : root.value < root.to
                    width: parent.width / 2
                    height: parent.height
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.step < 0 ? "Azalt" : "Artır"
                    Accessible.onPressAction: root.set(root.value + modelData.step)
                    Keys.onSpacePressed: root.set(root.value + modelData.step)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radiusSmall - 2
                        color: m.pressed ? Theme.pressed : "transparent"
                    }
                    Symbol {
                        anchors.centerIn: parent
                        name: modelData.sym
                        size: 18
                        weight: 600
                        color: Theme.label
                        opacity: can ? 1 : 0.3
                    }
                    Rectangle {
                        visible: index === 1
                        width: 1
                        height: parent.height * 0.55
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.separator
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        enabled: can
                        cursorShape: Qt.PointingHandCursor
                        // Basılı tutunca tekrarlar.
                        onPressed: { root.set(root.value + modelData.step); repeat.restart() }
                        onReleased: repeat.stop()
                        onCanceled: repeat.stop()
                    }
                    Timer {
                        id: repeat
                        interval: 380
                        repeat: true
                        onTriggered: { interval = 90; root.set(root.value + modelData.step) }
                        onRunningChanged: if (!running) interval = 380
                    }
                }
            }
        }
    }
}
