#pragma once

#include "Text.h"

#include <QHash>
#include <QObject>
#include <QQmlEngine>

class KentKart;

/**
 * Tüm hatlar (Kocaeli ~420): `route/list?keyword=` bir kez çekilir, diske yazılır ve 24 saat
 * kullanılır; arama istemci tarafında. Yenileme başarısızsa eski kopya kalır.
 */
class RouteCatalog : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY loadingChanged)
    Q_PROPERTY(int count READ count NOTIFY changed)

public:
    static constexpr qint64 MaxAgeMs = 24 * 3600 * 1000LL;

    RouteCatalog(KentKart *kk, QObject *parent = nullptr);
    static RouteCatalog *create(QQmlEngine *, QJSEngine *);
    static inline RouteCatalog *instance = nullptr;

    /** Önbelleği okur; yoksa ya da eskiyse ağdan yeniler. */
    void start();
    Q_INVOKABLE void refresh();

    /** [type]: -2 tümü, 3 otobüs, 0 tramvay, 4 vapur, 7 teleferik. [limit] < 0 sınırsız. */
    Q_INVOKABLE QVariantList search(const QString &query, int type = -2, int limit = -1) const;
    /** Koda göre hat (renkler için); bilinmiyorsa boş harita. */
    Q_INVOKABLE QVariantMap route(const QString &code) const;

    bool ready() const { return !m_routes.isEmpty(); }
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    int count() const { return m_routes.size(); }

signals:
    void changed();
    void loadingChanged();

private:
    void setRoutes(const QJsonArray &raw);
    QString cacheFile() const;

    KentKart *m_kk;
    QVariantList m_routes;
    QHash<QString, QVariantMap> m_byCode;
    text::RouteIndex m_index;
    bool m_loading = false;
    QString m_error;
};
