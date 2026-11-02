import QtQuick
import "Sym.js" as Sym

/** Material Symbols Rounded simgesi (`name`: Sym.js'deki ad). `filled` dolu biçim (seçili durum). */
Text {
    id: root

    property string name
    property real size: 18
    property bool filled: false
    property int weight: 450

    text: Sym.glyphs[name] || ""
    color: Theme.label
    font.family: "Material Symbols Rounded"
    font.pixelSize: Math.round(size * Theme.scale)
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": weight })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    Accessible.ignored: true
}
