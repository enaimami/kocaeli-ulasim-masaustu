import QtQuick

/** Yazı ölçeğinden bir stil kullanan metin. `style`: largeTitle, title1…3, headline, body, callout, subhead, footnote, caption. */
Text {
    id: root

    property string style: "body"
    property bool secondary: false
    property bool tertiary: false
    /** Rakamlar eşit genişlikte (saatler, mesafeler hizalı dursun). */
    property bool tabular: false
    property int weight: -1

    readonly property var spec: Theme.type[style] || Theme.type.body
    readonly property real px: Math.round(spec.size * Theme.scale * 10) / 10

    color: tertiary ? Theme.tertiaryLabel : secondary ? Theme.secondaryLabel : Theme.label
    font.family: Theme.family
    font.pixelSize: px
    font.weight: weight > 0 ? weight : spec.weight
    font.letterSpacing: spec.tracking * px
    // Inter'in optik boyut ekseni: büyük başlıkta "Display" kesimine yaklaşır.
    font.variableAxes: ({ "opsz": Math.max(14, Math.min(32, spec.size)) })
    font.features: tabular ? { "tnum": 1 } : ({})
    lineHeight: style === "largeTitle" || style.startsWith("title") ? 1.08 : 1.15
    elide: Text.ElideRight
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
