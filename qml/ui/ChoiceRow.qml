import QtQuick

/** Seçim listesindeki satır: seçiliyse sağda vurgu renginde onay işareti (iOS). */
ListRow {
    id: root

    property bool selected: false

    Accessible.role: Accessible.RadioButton
    Accessible.checked: selected

    trailing: Symbol {
        name: "check"
        size: 20
        weight: 600
        color: Theme.accent
        opacity: root.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }
}
