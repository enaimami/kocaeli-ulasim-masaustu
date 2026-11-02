#pragma once

#include <QJSValue>
#include <QObject>
#include <QQmlEngine>

class KentKart;

/**
 * QML'in KentKart'a kapısı. Her çağrı `cb(error, value)` biçiminde geri döner; `error` boş
 * dizgeyse başarıdır. Duyurular süreç başına bir kez indirilir (Ayarlar'da açıksa).
 */
class Api : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList announcements READ announcements NOTIFY announcementsChanged)
    /** Harita karo sağlayıcılarının (QtLocation osm eklentisi) yerel deposu; main kurar. */
    Q_PROPERTY(QString tileProviders READ tileProvidersUrl CONSTANT)
    /** Karo önbelleği uygulamanın kendi önbellek dizininde (Qt'nin paylaşılan dizini yerine). */
    Q_PROPERTY(QString tileCacheDir READ tileCacheDir CONSTANT)

public:
    Api(KentKart *kk, QObject *parent = nullptr);
    static Api *create(QQmlEngine *, QJSEngine *engine);
    static inline Api *instance = nullptr;
    static inline QString tileProviders;
    QString tileProvidersUrl() const { return tileProviders; }
    QString tileCacheDir() const;

    Q_INVOKABLE void closestStops(double lat, double lng, const QJSValue &cb);
    Q_INVOKABLE void stopArrivals(const QString &stopId, const QJSValue &cb);
    Q_INVOKABLE void searchStops(const QString &keyword, const QJSValue &cb);
    Q_INVOKABLE void routeDetail(const QString &code, int direction, const QJSValue &cb);
    Q_INVOKABLE void routeVehicles(const QString &code, int direction, const QJSValue &cb);
    /** cb(index) — durağın hattın başından sırası; bilinmiyorsa -1. */
    Q_INVOKABLE void stopsBefore(const QString &code, const QString &stopId, const QJSValue &cb);
    /** Geçerli duyuruları (bir kez) indirir; hata önbelleğe alınmaz, en erken 60 sn sonra yeniden denenir. */
    Q_INVOKABLE void loadAnnouncements();
    /** Hat koduyla ilgili geçerli duyurular (başlık ya da açıklamada kod geçiyorsa). */
    Q_INVOKABLE QVariantList announcementsFor(const QString &routeCode) const;
    /** Servis günü dakikası (tarifede "geçti" hesabı için; 04:00'ten önce önceki gün). */
    Q_INVOKABLE int serviceMinuteNow() const;
    Q_INVOKABLE QString formatDistance(double meters) const;

    QVariantList announcements() const { return m_announcements; }

signals:
    void announcementsChanged();

private:
    void reply(QJSValue cb, const QString &error, const QVariant &value);

    KentKart *m_kk;
    QJSEngine *m_engine = nullptr;
    QVariantList m_announcements;
    bool m_announcementsLoaded = false;
    bool m_announcementsLoading = false;
    qint64 m_announcementsFailedAt = 0;
};
