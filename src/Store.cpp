#include "Store.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <algorithm>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>

Store::Store(QObject *parent)
    : QObject(parent)
    , m_file(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/store.json"))
{
    QFile f(m_file);
    if (f.open(QIODevice::ReadOnly))
        m_data = QJsonDocument::fromJson(f.readAll()).object();
}

Store *Store::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance, QJSEngine::CppOwnership);
    return instance;
}

void Store::save()
{
    QDir().mkpath(QFileInfo(m_file).absolutePath());
    QSaveFile f(m_file);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning("Kayıt dosyası yazılamadı: %s", qPrintable(m_file));
        return;
    }
    f.write(QJsonDocument(m_data).toJson(QJsonDocument::Indented));
    f.commit();
}

void Store::set(const QString &key, const QJsonValue &value)
{
    if (m_data.value(key) == value)
        return;
    m_data.insert(key, value);
    save();
    emit settingsChanged();
}

QJsonArray Store::array(const char *key) const
{
    return m_data.value(QLatin1String(key)).toArray();
}

QVariantList Store::favoriteStops() const { return array("favoriteStops").toVariantList(); }
QVariantList Store::favoriteRoutes() const { return array("favoriteRoutes").toVariantList(); }

QStringList Store::recentSearches() const
{
    QStringList out;
    for (const QJsonValue &v : array("recentSearches"))
        out.append(v.toString());
    return out;
}

static qsizetype indexOf(const QJsonArray &a, const char *key, const QString &value)
{
    for (qsizetype i = 0; i < a.size(); ++i)
        if (a[i].toObject().value(QLatin1String(key)).toString() == value)
            return i;
    return -1;
}

bool Store::isFavoriteStop(const QString &id) const
{
    return indexOf(array("favoriteStops"), "id", id) >= 0;
}

void Store::toggleFavoriteStop(const QString &id, const QString &name)
{
    QJsonArray a = array("favoriteStops");
    const qsizetype i = indexOf(a, "id", id);
    if (i >= 0)
        a.removeAt(i);
    else
        a.append(QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("name"), name}});
    m_data.insert(QStringLiteral("favoriteStops"), a);
    save();
    emit favoritesChanged();
}

void Store::removeFavoriteStop(const QString &id)
{
    if (isFavoriteStop(id))
        toggleFavoriteStop(id, {});
}

void Store::restoreFavoriteStop(const QVariantMap &stop, int index)
{
    const QString id = stop.value(QStringLiteral("id")).toString();
    if (id.isEmpty() || isFavoriteStop(id))
        return;
    QJsonArray a = array("favoriteStops");
    a.insert(std::clamp<qsizetype>(index, 0, a.size()), QJsonObject::fromVariantMap(stop));
    m_data.insert(QStringLiteral("favoriteStops"), a);
    save();
    emit favoritesChanged();
}

void Store::moveFavoriteStop(int from, int to)
{
    QJsonArray a = array("favoriteStops");
    if (from < 0 || from >= a.size() || to < 0 || to >= a.size() || from == to)
        return;
    const QJsonValue v = a.takeAt(from);
    a.insert(to, v);
    m_data.insert(QStringLiteral("favoriteStops"), a);
    save();
    emit favoritesChanged();
}

bool Store::isFavoriteRoute(const QString &code) const
{
    return indexOf(array("favoriteRoutes"), "code", code) >= 0;
}

void Store::toggleFavoriteRoute(const QString &code, const QString &name, const QString &color, const QString &textColor)
{
    QJsonArray a = array("favoriteRoutes");
    const qsizetype i = indexOf(a, "code", code);
    if (i >= 0)
        a.removeAt(i);
    else
        a.append(QJsonObject{{QStringLiteral("code"), code},
                             {QStringLiteral("name"), name},
                             {QStringLiteral("color"), color},
                             {QStringLiteral("textColor"), textColor}});
    m_data.insert(QStringLiteral("favoriteRoutes"), a);
    save();
    emit favoritesChanged();
}

void Store::addRecentSearch(const QString &query)
{
    const QString q = query.trimmed();
    if (q.isEmpty())
        return;
    QStringList list = recentSearches();
    list.removeIf([&](const QString &s) { return s.compare(q, Qt::CaseInsensitive) == 0; });
    list.prepend(q);
    while (list.size() > MaxRecent)
        list.removeLast();
    m_data.insert(QStringLiteral("recentSearches"), QJsonArray::fromStringList(list));
    save();
    emit recentSearchesChanged();
}

void Store::clearRecentSearches()
{
    m_data.remove(QStringLiteral("recentSearches"));
    save();
    emit recentSearchesChanged();
}

void Store::setHome(double lat, double lng, bool manual)
{
    if (!manual && homeManual())
        return;
    if (hasHome() && homeManual() == manual && qFuzzyCompare(homeLat(), lat) && qFuzzyCompare(homeLng(), lng))
        return;
    m_data.insert(QStringLiteral("homeLat"), lat);
    m_data.insert(QStringLiteral("homeLng"), lng);
    m_data.insert(QStringLiteral("homeManual"), manual);
    save();
    emit settingsChanged();
}

void Store::clearManualHome()
{
    if (!homeManual())
        return;
    m_data.insert(QStringLiteral("homeManual"), false);
    save();
    emit settingsChanged();
}
