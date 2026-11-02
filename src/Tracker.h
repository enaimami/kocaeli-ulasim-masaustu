#pragma once

#include "TrackingLogic.h"

#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QTimer>

class KentKart;
class Notifier;

/**
 * Varış takipleri (en çok 5). Pencere kapalıyken de (tepside) sürer. Bir tur: önce hedef
 * durakların yaklaşanları, sonra bunlarda bulunamayan araçların hatları; istekler sıralı, aynı
 * uca düşen takipler tek istekte. Tur aralığı 20 sn, hepsi uzaksa 60 sn (PLAN §0 istisnası).
 */
class Tracker : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList trackings READ trackings NOTIFY trackingsChanged)
    Q_PROPERTY(int count READ count NOTIFY trackingsChanged)
    Q_PROPERTY(bool canStart READ canStart NOTIFY trackingsChanged)
    Q_PROPERTY(int maxTrackings READ maxTrackings CONSTANT)

public:
    Tracker(KentKart *kk, Notifier *notifier, QObject *parent = nullptr);
    static Tracker *create(QQmlEngine *, QJSEngine *);
    static inline Tracker *instance = nullptr;

    /** Kayıtlı takipleri yükler ve yoklamayı sürdürür. */
    void start();

    /**
     * [vehicle]: plate, vehicleId, routeCode, direction. [target]: {kind: "stop", stopId, name,
     * lat?, lng?} ya da {kind: "place", lat, lng, radiusM, name}. [warnStops] 0 = önceden haber yok.
     * Yeni takibin kimliği; sınır doluysa boş.
     */
    Q_INVOKABLE QString startVehicle(const QVariantMap &vehicle, const QVariantMap &target, int warnStops, bool alarm);
    /** "Bu hattın ilk aracı gelince haber ver" (en çok 6 saat). */
    Q_INVOKABLE QString waitForRoute(const QString &routeCode, const QVariantMap &stop, int warnStops, bool alarm);
    Q_INVOKABLE void stop(const QString &id);
    Q_INVOKABLE void stopAll();
    /** Bu aracı izleyen takibin kimliği ya da boş. */
    Q_INVOKABLE QString trackingFor(const QString &vehicleId, const QString &plate) const;
    /** Bu durakta bu hattı bekleyen takibin kimliği ya da boş. */
    Q_INVOKABLE QString waitingFor(const QString &routeCode, const QString &stopId) const;

    QVariantList trackings() const;
    int count() const { return int(m_list.size()); }
    bool canStart() const { return m_list.size() < tracking::MaxTrackings; }
    int maxTrackings() const { return tracking::MaxTrackings; }

signals:
    void trackingsChanged();

private:
    struct Round;
    void add(tracking::Tracking t);
    void schedule();
    void poll();
    void fetchStops(std::shared_ptr<Round> r, qsizetype i);
    void fetchRoutes(std::shared_ptr<Round> r, qsizetype i);
    void finish(std::shared_ptr<Round> r);
    void emitEvent(const tracking::Event &e);
    void save();
    void changed();

    KentKart *m_kk;
    Notifier *m_notifier;
    QList<tracking::Tracking> m_list;
    QTimer m_timer;
    bool m_polling = false;
    QString m_file;
};
