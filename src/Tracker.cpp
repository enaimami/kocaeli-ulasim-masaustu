#include "Tracker.h"

#include "KentKart.h"
#include "Notifier.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUuid>

using namespace tracking;

struct Tracker::Round {
    qint64 now = 0;
    QList<Tracking> snapshot;
    QStringList stopIds;
    QHash<QString, std::pair<bool, QVariantMap>> stops; // durak → (başarılı, yanıt)
    QList<std::pair<QString, int>> routes;
    QHash<QString, std::pair<bool, QList<Vehicle>>> routeResults; // "kod|yön" → (başarılı, araçlar)
};

static QString routeKey(const QString &code, int dir)
{
    return code + u'|' + QString::number(dir);
}

static qint64 nowMs()
{
    return QDateTime::currentMSecsSinceEpoch();
}

static QList<Vehicle> vehiclesOf(const QVariantList &list)
{
    QList<Vehicle> out;
    for (const QVariant &v : list)
        out.append(Vehicle::fromVariant(v));
    return out;
}

Tracker::Tracker(KentKart *kk, Notifier *notifier, QObject *parent)
    : QObject(parent)
    , m_kk(kk)
    , m_notifier(notifier)
    , m_file(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/trackings.json"))
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &Tracker::poll);
}

Tracker *Tracker::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance, QJSEngine::CppOwnership);
    return instance;
}

void Tracker::start()
{
    QFile f(m_file);
    if (f.open(QIODevice::ReadOnly))
        for (const QJsonValue &v : QJsonDocument::fromJson(f.readAll()).array())
            m_list.append(Tracking::fromJson(v.toObject()));
    if (!m_list.isEmpty()) {
        emit trackingsChanged();
        poll(); // süresi dolanlar ilk turda biter
    }
}

QVariantList Tracker::trackings() const
{
    QVariantList out;
    for (const Tracking &t : m_list)
        out.append(t.toVariant());
    return out;
}

static Target targetFrom(const QVariantMap &m)
{
    Target t;
    t.kind = m.value(QStringLiteral("kind")).toString() == u"place" ? Target::NearPlace : Target::AtStop;
    t.stopId = m.value(QStringLiteral("stopId")).toString();
    t.name = m.value(QStringLiteral("name")).toString();
    t.radiusM = m.value(QStringLiteral("radiusM")).toInt();
    const QVariant lat = m.value(QStringLiteral("lat")), lng = m.value(QStringLiteral("lng"));
    if (lat.isValid() && lng.isValid() && !lat.isNull() && !lng.isNull())
        t.location = QGeoCoordinate(lat.toDouble(), lng.toDouble());
    return t;
}

QString Tracker::startVehicle(const QVariantMap &vehicle, const QVariantMap &target, int warnStops, bool alarm)
{
    if (!canStart())
        return {};
    Tracking t;
    t.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    t.vehicleId = vehicle.value(QStringLiteral("vehicleId")).toString();
    t.plate = vehicle.value(QStringLiteral("plate")).toString();
    t.routeCode = vehicle.value(QStringLiteral("routeCode")).toString();
    const QVariant dir = vehicle.value(QStringLiteral("direction"));
    if (dir.isValid() && !dir.isNull())
        t.direction = dir.toInt();
    t.target = targetFrom(target);
    if (warnStops > 0 && t.target.kind == Target::AtStop)
        t.warnStops = warnStops;
    t.alert = alarm ? AlertKind::Alarm : AlertKind::Notification;
    t.createdAt = nowMs();
    t.expiresAt = t.createdAt + TrackingDurationMs;
    add(t);
    return t.id;
}

QString Tracker::waitForRoute(const QString &routeCode, const QVariantMap &stop, int warnStops, bool alarm)
{
    if (!canStart())
        return {};
    Tracking t;
    t.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    t.routeCode = routeCode;
    t.target = targetFrom(stop);
    t.target.kind = Target::AtStop;
    if (warnStops > 0)
        t.warnStops = warnStops;
    t.alert = alarm ? AlertKind::Alarm : AlertKind::Notification;
    t.createdAt = nowMs();
    t.expiresAt = t.createdAt + WaitDurationMs;
    t.waitForRoute = true;
    add(t);
    return t.id;
}

void Tracker::add(Tracking t)
{
    m_list.append(std::move(t));
    changed();
    // Yeni takip hemen ilk turu görsün; tur sürüyorsa bittiğinde yeniden planlanır.
    if (!m_polling) {
        m_timer.stop();
        poll();
    }
}

void Tracker::stop(const QString &id)
{
    if (m_list.removeIf([&](const Tracking &t) { return t.id == id; }) > 0)
        changed();
    if (m_list.isEmpty())
        m_timer.stop();
}

void Tracker::stopAll()
{
    if (m_list.isEmpty())
        return;
    m_list.clear();
    m_timer.stop();
    changed();
}

QString Tracker::trackingFor(const QString &vehicleId, const QString &plate) const
{
    Vehicle v;
    v.vehicleId = vehicleId;
    v.plate = plate;
    for (const Tracking &t : m_list)
        if (!t.waitForRoute && matches(t, v))
            return t.id;
    return {};
}

QString Tracker::waitingFor(const QString &routeCode, const QString &stopId) const
{
    for (const Tracking &t : m_list)
        if (t.waitForRoute && t.routeCode == routeCode && t.target.stopId == stopId)
            return t.id;
    return {};
}

void Tracker::changed()
{
    save();
    emit trackingsChanged();
}

void Tracker::save()
{
    QJsonArray a;
    for (const Tracking &t : m_list)
        a.append(t.toJson());
    QDir().mkpath(QFileInfo(m_file).absolutePath());
    QSaveFile f(m_file);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(a).toJson(QJsonDocument::Compact));
        f.commit();
    }
}

void Tracker::schedule()
{
    if (m_list.isEmpty())
        return;
    m_timer.start(int(nextPollDelayMs(m_list)));
}

void Tracker::poll()
{
    if (m_polling || m_list.isEmpty())
        return;
    m_polling = true;
    auto r = std::make_shared<Round>();
    r->now = nowMs();
    r->snapshot = m_list;
    for (const Tracking &t : r->snapshot)
        if (r->now < t.expiresAt && t.target.kind == Target::AtStop && !r->stopIds.contains(t.target.stopId))
            r->stopIds.append(t.target.stopId);
    fetchStops(r, 0);
}

void Tracker::fetchStops(std::shared_ptr<Round> r, qsizetype i)
{
    if (i < r->stopIds.size()) {
        const QString id = r->stopIds[i];
        m_kk->stopArrivals(id, [this, r, i, id](const QString &err, const QVariantMap &value) {
            r->stops.insert(id, {err.isEmpty(), value});
            fetchStops(r, i + 1);
        });
        return;
    }
    // İkinci aşama: konum hedefleri ve yaklaşanlarda bulunamayan, yönü bilinen takiplerin hatları.
    for (const Tracking &t : r->snapshot) {
        if (r->now >= t.expiresAt || !t.direction)
            continue;
        bool found = false;
        if (t.target.kind == Target::AtStop) {
            const auto s = r->stops.value(t.target.stopId);
            for (const Vehicle &v : vehiclesOf(s.second.value(QStringLiteral("vehicles")).toList()))
                if (t.waitForRoute ? false : matches(t, v))
                    found = true;
        }
        const std::pair<QString, int> key{t.routeCode, *t.direction};
        if (!found && !r->routes.contains(key))
            r->routes.append(key);
    }
    fetchRoutes(r, 0);
}

void Tracker::fetchRoutes(std::shared_ptr<Round> r, qsizetype i)
{
    if (i >= r->routes.size()) {
        finish(r);
        return;
    }
    const auto [code, dir] = r->routes[i];
    m_kk->routeVehicles(code, dir, [this, r, i, code, dir](const QString &err, const QVariantList &list) {
        r->routeResults.insert(routeKey(code, dir), {err.isEmpty(), vehiclesOf(list)});
        fetchRoutes(r, i + 1);
    });
}

void Tracker::finish(std::shared_ptr<Round> r)
{
    m_polling = false;
    QList<Event> events;
    bool anyChange = false;

    for (qsizetype i = 0; i < m_list.size();) {
        const Tracking &t = m_list[i];
        // Tur sırasında eklenen takip bu turu görmedi; bir sonrakini bekler.
        const bool inRound = std::any_of(r->snapshot.begin(), r->snapshot.end(), [&](const Tracking &s) { return s.id == t.id; });
        if (!inRound) {
            ++i;
            continue;
        }
        std::optional<std::pair<bool, QList<Vehicle>>> route;
        if (t.direction) {
            const QString key = routeKey(t.routeCode, *t.direction);
            if (r->routeResults.contains(key))
                route = r->routeResults.value(key);
        }

        Observation obs;
        if (t.target.kind == Target::AtStop) {
            if (!r->stops.contains(t.target.stopId)) {
                obs = Observation::unavailable(); // süresi dolmuş; step bitirir
            } else {
                const auto &[ok, arrivals] = r->stops[t.target.stopId];
                const QList<Vehicle> vehicles = vehiclesOf(arrivals.value(QStringLiteral("vehicles")).toList());
                std::optional<Vehicle> approaching;
                if (t.waitForRoute) {
                    approaching = nearestOfRoute(t, vehicles);
                } else {
                    for (const Vehicle &v : vehicles)
                        if (matches(t, v)) {
                            approaching = v;
                            break;
                        }
                }
                std::optional<QGeoCoordinate> stopLoc;
                if (arrivals.contains(QStringLiteral("lat")))
                    stopLoc = QGeoCoordinate(arrivals.value(QStringLiteral("lat")).toDouble(), arrivals.value(QStringLiteral("lng")).toDouble());
                if (!ok) {
                    obs = Observation::unavailable();
                } else if (approaching) {
                    obs.approaching = approaching;
                    obs.targetLocation = stopLoc;
                } else if (route && !route->first) {
                    obs = Observation::unavailable();
                } else {
                    if (route)
                        for (const Vehicle &v : route->second)
                            if (matches(t, v)) {
                                obs.onRoute = v;
                                break;
                            }
                    obs.targetLocation = stopLoc;
                }
            }
        } else if (route) {
            if (!route->first) {
                obs = Observation::unavailable();
            } else {
                for (const Vehicle &v : route->second)
                    if (matches(t, v)) {
                        obs.onRoute = v;
                        break;
                    }
            }
        }

        const Step s = step(t, obs, r->now);
        events.append(s.events);
        anyChange = true;
        if (s.tracking) {
            m_list[i] = *s.tracking;
            ++i;
        } else {
            m_list.removeAt(i);
        }
    }

    if (anyChange)
        changed();
    for (const Event &e : events)
        emitEvent(e);
    schedule();
}

void Tracker::emitEvent(const Event &e)
{
    if (e.important() && e.tracking.alert == AlertKind::Alarm)
        m_notifier->startAlarm(e.title(), e.text());
    else
        m_notifier->notify(e.title(), e.text(), e.important());
}
