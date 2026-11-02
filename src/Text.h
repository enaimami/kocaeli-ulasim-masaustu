#pragma once

#include <QString>
#include <QStringList>
#include <QVariantList>

namespace text {

/** Türkçe kurallarıyla küçültür ("İZMİT" → "izmit"), aksanları düzleştirir. */
QString normalizeForSearch(const QString &text);

/** 850 → "850 m", 1234 → "1,2 km". */
QString formatDistance(double meters);

/**
 * Hat listesinin aranabilir hâli: kod ve ad bir kez düzleştirilir. Her kelime kodda ya da adda
 * geçmeli. Sıra: tam kod, kod öneki, ad kelimesi öneki, diğerleri; eşitlikte liste sırası.
 */
class RouteIndex
{
public:
    void reset(const QVariantList &routes);
    /** [type] < -1 ise tümü (−1 "diğer" türüdür). */
    QVariantList search(const QString &query, int type = -2, int limit = -1) const;
    bool isEmpty() const { return m_entries.isEmpty(); }

private:
    struct Entry {
        QVariant route;
        int type;
        QString code;
        QString haystack;
        QStringList words;
    };
    QList<Entry> m_entries;
};

} // namespace text
