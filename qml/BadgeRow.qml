import QtQuick
import "ui"

/** Bir sıra hat rozeti; sığmayanlar "+N" olarak özetlenir. */
Flow {
    id: root

    /** [{code, color, textColor}] */
    property var badges: []
    property int maxCount: 10

    spacing: Math.round(4 * Theme.scale)

    Repeater {
        model: root.badges.slice(0, root.maxCount)
        RouteBadge {
            required property var modelData
            code: modelData.code
            badgeColor: modelData.color
            textColor: modelData.textColor
        }
    }

    Txt {
        visible: root.badges.length > root.maxCount
        height: Math.round(22 * Theme.scale)
        text: "+" + (root.badges.length - root.maxCount)
        style: "footnote"
        secondary: true
        leftPadding: 2
    }
}
