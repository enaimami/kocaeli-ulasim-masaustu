"""Kocaeli Ulaşım penceresini AT-SPI üzerinden sürmek için küçük test yardımcısı.

Kullanım: python3 -I ui.py dump [derinlik] | click <ad> [sıra] | names <ad-parçası>
"""
import sys

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi  # noqa: E402


def app():
    desktop = Atspi.get_desktop(0)
    for i in range(desktop.get_child_count()):
        a = desktop.get_child_at_index(i)
        if a and a.get_name() in ("kocaeli-ulasim", "Kocaeli Ulaşım"):
            return a
    sys.exit("uygulama bulunamadı")


def walk(node, depth=0, maxdepth=60):
    if node is None or depth > maxdepth:
        return
    yield depth, node
    try:
        n = node.get_child_count()
    except Exception:
        return
    for i in range(n):
        try:
            yield from walk(node.get_child_at_index(i), depth + 1, maxdepth)
        except Exception:
            pass


def label(node):
    try:
        return f"{node.get_role_name()} '{node.get_name()}'"
    except Exception:
        return "?"


cmd = sys.argv[1]
if cmd == "dump":
    maxd = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    for d, n in walk(app(), maxdepth=maxd):
        name = n.get_name()
        if name:
            print("  " * d + label(n))
elif cmd == "names":
    part = sys.argv[2].lower()
    for d, n in walk(app()):
        if part in (n.get_name() or "").lower():
            print(label(n))
elif cmd == "click":
    name = sys.argv[2]
    index = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    hits = [n for _, n in walk(app()) if (n.get_name() or "") == name]
    if len(hits) <= index:
        sys.exit(f"bulunamadı: {name} ({len(hits)} eşleşme)")
    node = hits[index]
    action = node.get_action_iface() if hasattr(node, "get_action_iface") else node
    try:
        ok = Atspi.Action.do_action(node, 0)
    except Exception as e:
        sys.exit(f"eylem yok: {label(node)}: {e}")
    print("tıklandı:", label(node), ok)

if cmd == "actions":
    name = sys.argv[2]
    index = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    hits = [n for _, n in walk(app()) if (n.get_name() or "") == name]
    node = hits[index]
    for i in range(Atspi.Action.get_n_actions(node)):
        print(i, Atspi.Action.get_action_name(node, i))
if cmd == "act":
    name, index, act = sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    hits = [n for _, n in walk(app()) if (n.get_name() or "") == name]
    print(Atspi.Action.do_action(hits[index], act))
if cmd == "type":
    text = sys.argv[2]
    hits = [n for _, n in walk(app()) if n.get_role_name() == "text"]
    print(Atspi.EditableText.set_text_contents(hits[0], text))
