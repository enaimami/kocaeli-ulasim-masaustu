import QtQuick

/** Kapsül seçenekler: seçili olan vurgu renginde dolu, diğerleri dolgu zeminli. */
Flow {
    id: root

    /** [{ value, text }] */
    property var options: []
    property var value

    signal picked(var value)

    spacing: Theme.gap

    Repeater {
        model: root.options
        delegate: PillButton {
            required property var modelData
            text: modelData.text
            compact: true
            kind: modelData.value === root.value ? "filled" : "plain"
            checked: modelData.value === root.value
            onClicked: root.picked(modelData.value)
        }
    }
}
