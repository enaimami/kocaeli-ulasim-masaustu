"""Material Symbols Rounded'dan uygulamanın kullandığı simgeleri kırpar.

Çıktılar: data/fonts/symbols.ttf (FILL ve wght eksenleri korunur) ve qml/ui/Sym.js
(ad → karakter). Simge eklemek için ICONS'a ekleyip `python3 -I tools/subset_symbols.py` çalıştır.
Kaynak sistemden okunur (AUR: ttf-material-symbols-variable).
"""
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parent.parent
SRC = "/usr/share/fonts/TTF/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"

# QML adı → Material Symbols glif adı
ICONS = {
    "star": "star",
    "bell": "notifications",
    "bellActive": "notifications_active",
    "alarm": "alarm",
    "bus": "directions_bus",
    "tram": "tram",
    "boat": "directions_boat",
    "cableCar": "gondola_lift",
    "close": "close",
    "cancel": "cancel",
    "expandMore": "expand_more",
    "expandLess": "expand_less",
    "add": "add",
    "remove": "remove",
    "back": "arrow_back_ios_new",
    "chevron": "chevron_right",
    "chevronLeft": "chevron_left",
    "settings": "settings",
    "search": "search",
    "place": "place",
    "nearMe": "near_me",
    "myLocation": "my_location",
    "map": "map",
    "accessible": "accessible",
    "check": "check",
    "checkCircle": "check_circle",
    "schedule": "schedule",
    "refresh": "refresh",
    "wifiOff": "wifi_off",
    "error": "error",
    "info": "info",
    "route": "route",
    "home": "home",
    "history": "history",
    "swap": "swap_horiz",
    "campaign": "campaign",
    "stop": "stop_circle",
    "arrowForward": "arrow_forward",
    "pinDrop": "pin_drop",
    "delete": "delete",
    "timer": "timer",
    "list": "format_list_bulleted",
    "sidebar": "dock_to_right",
    "locationOff": "location_off",
    "palette": "palette",
    "database": "database",
}


def main():
    font = TTFont(SRC)
    rev = {}
    for cp, glyph in font.getBestCmap().items():
        rev.setdefault(glyph, cp)
    missing = [g for g in ICONS.values() if g not in rev]
    if missing:
        raise SystemExit(f"Fontta olmayan simgeler: {missing}")
    codepoints = {name: rev[glyph] for name, glyph in ICONS.items()}

    opts = subset.Options()
    opts.layout_features = []  # bitişik yazım gerekmiyor; kod noktasıyla çiziliyor
    opts.notdef_outline = True
    s = subset.Subsetter(opts)
    s.populate(unicodes=sorted(set(codepoints.values())))
    s.subset(font)
    font = instancer.instantiateVariableFont(font, {"GRAD": 0, "opsz": 24})
    out = ROOT / "data" / "fonts" / "symbols.ttf"
    font.save(out)

    lines = [
        ".pragma library",
        "",
        "// tools/subset_symbols.py tarafından üretildi; elle düzenleme.",
        "// Material Symbols Rounded karakterleri (data/fonts/symbols.ttf).",
        "",
        "var glyphs = {",
    ]
    for name, cp in codepoints.items():
        lines.append(f'    {name}: "\\u{cp:04x}",')
    lines.append("}")
    (ROOT / "qml" / "ui" / "Sym.js").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{out} ({out.stat().st_size} bayt), {len(codepoints)} simge")


if __name__ == "__main__":
    main()
