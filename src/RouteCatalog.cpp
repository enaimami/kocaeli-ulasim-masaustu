#include "RouteCatalog.h"

#include "KentKart.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>

RouteCatalog::RouteCatalog(KentKart *kk, QObject *parent)
    : QObject(parent)
    , m_kk(kk)
{
}

RouteCatalog *RouteCatalog::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance, QJSEngine::CppOwnership);
    return instance;
}

QString RouteCatalog::cacheFile() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/routes.json");
}

void RouteCatalog::start()
{
    QFile f(cacheFile());
    qint64 savedAt = 0;
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
        savedAt = o.value(u"savedAt").toInteger();
        setRoutes(o.value(u"routes").toArray());
    }
    if (m_routes.isEmpty() || QDateTime::currentMSecsSinceEpoch() - savedAt > MaxAgeMs)
        refresh();
}

void RouteCatalog::refresh()
{
    if (m_loading)
        return;
    m_loading = true;
    m_error.clear();
    emit loadingChanged();
    m_kk->allRoutes([this](const QString &err, const QJsonArray &raw) {
        m_loading = false;
        if (!err.isEmpty() || raw.isEmpty()) {
            m_error = err.isEmpty() ? QStringLiteral("Hat listesi boş geldi.") : err;
            emit loadingChanged();
            return;
        }
        QDir().mkpath(QFileInfo(cacheFile()).absolutePath());
        QSaveFile f(cacheFile());
        if (f.open(QIODevice::WriteOnly)) {
            f.write(QJsonDocument(QJsonObject{{QStringLiteral("savedAt"), QDateTime::currentMSecsSinceEpoch()},
                                              {QStringLiteral("routes"), raw}})
                        .toJson(QJsonDocument::Compact));
            f.commit();
        }
        setRoutes(raw);
        emit loadingChanged();
    });
}

void RouteCatalog::setRoutes(const QJsonArray &raw)
{
    m_routes.clear();
    m_byCode.clear();
    for (const QJsonValue &v : raw) {
        const QVariantMap r = kk::route(v.toObject());
        if (r.value(QStringLiteral("code")).toString().isEmpty())
            continue;
        m_routes.append(r);
        m_byCode.insert(r.value(QStringLiteral("code")).toString().toUpper(), r);
    }
    m_index.reset(m_routes);
    emit changed();
}

QVariantList RouteCatalog::search(const QString &query, int type, int limit) const
{
    return m_index.search(query, type, limit);
}

QVariantMap RouteCatalog::route(const QString &code) const
{
    return m_byCode.value(code.trimmed().toUpper());
}
