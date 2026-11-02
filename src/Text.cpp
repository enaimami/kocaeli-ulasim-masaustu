#include "Text.h"

#include <QLocale>
#include <QRegularExpression>
#include <QVariantMap>
#include <algorithm>

namespace text {

QString normalizeForSearch(const QString &text)
{
    static const QLocale turkish(QLocale::Turkish, QLocale::Turkey);
    QString lower = turkish.toLower(text);
    for (QChar &c : lower) {
        switch (c.unicode()) {
        case 0x0131: c = u'i'; break; // ı
        case 0x00E7: c = u'c'; break; // ç
        case 0x011F: c = u'g'; break; // ğ
        case 0x00F6: c = u'o'; break; // ö
        case 0x015F: c = u's'; break; // ş
        case 0x00FC: c = u'u'; break; // ü
        default: break;
        }
    }
    // Türkçe küçültme "İ"yi "i̇" (i + birleşik nokta) yapabilir; nokta atılır.
    lower.remove(QChar(0x0307));
    return lower.trimmed();
}

QString formatDistance(double meters)
{
    if (meters < 1000)
        return QStringLiteral("%1 m").arg(qRound(meters));
    return QLocale(QLocale::Turkish).toString(meters / 1000.0, 'f', 1) + QStringLiteral(" km");
}

void RouteIndex::reset(const QVariantList &routes)
{
    static const QRegularExpression nonWord(QStringLiteral("[^\\p{L}\\p{N}]+"));
    m_entries.clear();
    m_entries.reserve(routes.size());
    for (const QVariant &r : routes) {
        const QVariantMap m = r.toMap();
        const QString code = normalizeForSearch(m.value(QStringLiteral("code")).toString());
        const QString name = normalizeForSearch(m.value(QStringLiteral("name")).toString());
        m_entries.append({r, m.value(QStringLiteral("type")).toInt(), code, code + u' ' + name,
                          name.split(nonWord, Qt::SkipEmptyParts)});
    }
}

QVariantList RouteIndex::search(const QString &query, int type, int limit) const
{
    static const QRegularExpression ws(QStringLiteral("\\s+"));
    const QString q = normalizeForSearch(query);
    const QStringList tokens = q.split(ws, Qt::SkipEmptyParts);
    QList<std::pair<int, const Entry *>> hits;
    for (const Entry &e : m_entries) {
        if (type >= -1 && e.type != type)
            continue;
        if (!std::all_of(tokens.begin(), tokens.end(), [&](const QString &t) { return e.haystack.contains(t); }))
            continue;
        int rank = 3;
        if (q.isEmpty() || e.code == q)
            rank = 0;
        else if (e.code.startsWith(q))
            rank = 1;
        else if (std::any_of(e.words.begin(), e.words.end(), [&](const QString &w) { return w.startsWith(tokens.first()); }))
            rank = 2;
        hits.append({rank, &e});
    }
    std::stable_sort(hits.begin(), hits.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
    QVariantList out;
    for (const auto &h : hits) {
        if (limit >= 0 && out.size() >= limit)
            break;
        out.append(h.second->route);
    }
    return out;
}

} // namespace text
