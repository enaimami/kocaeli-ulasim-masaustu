import QtQuick
import "ui"

/**
 * Değeri değişince kısa çapraz solmayla güncellenen metin (dakika, durak sayısı).
 * Txt ile aynı temel özellikler; animasyon kesilebilir, hareket kapalıyken anında.
 */
Txt {
    id: root

    /** Dışarıdan verilen gerçek metin; ekrandaki `text` solma ortasında değişir. */
    property string value
    property bool ready: false

    Component.onCompleted: { text = value; ready = true }
    onValueChanged: {
        if (!ready || !Theme.motion || value === text || !visible) { text = value; return }
        swap.restart()
    }
    SequentialAnimation {
        id: swap
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: Theme.quick / 2 }
        ScriptAction { script: root.text = root.value }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.quick }
    }
}
