#include "TrackingLogic.h"

#include "Text.h"

#include <QJsonValue>
#include <algorithm>
#include <climits>

namespace tracking {

namespace {

constexpr int FarStopsMargin = 5;
constexpr int FarDistanceM = 3'000;

QJsonValue opt(const std::optional<int> &v) { return v ? QJsonValue(*v) : QJsonValue(); }
QJsonValue opt(const std::optional<qint64> &v) { return v ? QJsonValue(*v) : QJsonValue(); }

std::optional<int> optInt(const QJsonValue &v)
{
    return v.isDouble() ? std::optional<int>(v.toInt()) : std::nullopt;
}

std::optional<int> optInt(const QVariant &v)
{
    bool ok = false;
    const int i = v.toInt(&ok);
    return v.isValid() && !v.isNull() && ok ? std::optional<int>(i) : std::nullopt;
}

Step missed(const Tracking &t)
{
    const int n = t.missedPolls + 1;
    if (n >= LostAfterPolls)
        return {std::nullopt, {{Event::Lost, t}}};
    Tracking next = t;
    next.missedPolls = n;
    return {next, {}};
}

Step stepAtStop(const Tracking &t, const Observation &obs, qint64 now)
{
    const std::optional<QGeoCoordinate> stopLocation = obs.targetLocation ? obs.targetLocation : t.target.location;
    const std::optional<Vehicle> &seen = obs.approaching ? obs.approaching : obs.onRoute;
    std::optional<int> distance;
    if (seen && seen->location && stopLocation)
        distance = distanceMeters(*seen->location, *stopLocation);

    if (const auto &a = obs.approaching) {
        Tracking updated = t;
        updated.missedPolls = 0;
        updated.lastStopsAway = a->stopsAway;
        updated.lastMinutesAway = a->minutesAway;
        updated.lastDistanceM = distance;
        updated.lastSeenAt = now;
        if (a->stopsAway == 0 || (distance && *distance <= ArrivalRadiusM))
            return {std::nullopt, {{Event::Arrived, updated}}};
        const bool warn = !t.warned && t.warnStops && a->stopsAway && *a->stopsAway <= *t.warnStops;
        updated.warned = t.warned || warn;
        if (warn)
            return {updated, {{Event::Warn, updated}}};
        return {updated, {}};
    }

    if (obs.onRoute) {
        // Yaklaşanlardan düştü ama hâlâ hatta: az önce durağa çok yakındıysa geçti demektir.
        const bool wasClose = t.missedPolls == 0 && t.lastStopsAway && *t.lastStopsAway <= PassWindowStops;
        Tracking updated = t;
        updated.lastSeenAt = now;
        if (wasClose)
            return {std::nullopt, {{Event::Passed, updated}}};
        if (distance && *distance <= ArrivalRadiusM) {
            updated.lastDistanceM = distance;
            return {std::nullopt, {{Event::Arrived, updated}}};
        }
        // Durak sayısı yalnızca yaklaşanlar listesinden gelir; eskisi bayatlamasın.
        updated.missedPolls = 0;
        updated.lastStopsAway.reset();
        updated.lastMinutesAway.reset();
        updated.lastDistanceM = distance;
        return {updated, {}};
    }
    return missed(t);
}

/** Hat beklemesi: araç görünmemesi olağandır. En yakın araç eşiğe girince ona kilitlenir. */
Step stepWait(const Tracking &t, const Observation &obs, qint64 now)
{
    const auto &a = obs.approaching;
    if (!a) {
        Tracking next = t;
        next.missedPolls = 0;
        next.lastStopsAway.reset();
        next.lastMinutesAway.reset();
        next.lastDistanceM.reset();
        return {next, {}};
    }
    if (t.warnStops && a->stopsAway && *a->stopsAway > *t.warnStops) {
        Tracking next = t;
        next.lastStopsAway = a->stopsAway;
        next.lastMinutesAway = a->minutesAway;
        next.lastSeenAt = now;
        return {next, {}};
    }
    Tracking locked = t;
    locked.waitForRoute = false;
    locked.vehicleId = a->vehicleId;
    locked.plate = a->plate;
    locked.expiresAt = std::max(t.expiresAt, now + TrackingDurationMs);
    return stepAtStop(locked, obs, now);
}

Step stepNearPlace(const Tracking &t, const Observation &obs, qint64 now)
{
    const std::optional<Vehicle> &seen = obs.onRoute ? obs.onRoute : obs.approaching;
    if (!seen || !seen->location || !t.target.location)
        return missed(t);
    const int distance = distanceMeters(*seen->location, *t.target.location);
    Tracking updated = t;
    updated.missedPolls = 0;
    updated.lastDistanceM = distance;
    updated.lastSeenAt = now;
    if (distance <= t.target.radiusM)
        return {std::nullopt, {{Event::Arrived, updated}}};
    return {updated, {}};
}

bool isNear(const Tracking &t)
{
    // Hat beklemesinde araç yoksa uzak sayılır: bekleme saatlerce sürebilir.
    if (t.waitForRoute && !t.lastStopsAway)
        return false;
    if (!t.lastSeenAt || t.missedPolls > 0)
        return true;
    if (t.lastStopsAway && *t.lastStopsAway <= t.warnStops.value_or(0) + FarStopsMargin)
        return true;
    return !t.lastDistanceM || *t.lastDistanceM <= FarDistanceM;
}

} // namespace

QJsonObject Tracking::toJson() const
{
    QJsonObject tg{
        {QStringLiteral("kind"), target.kind == Target::AtStop ? QStringLiteral("stop") : QStringLiteral("place")},
        {QStringLiteral("stopId"), target.stopId},
        {QStringLiteral("name"), target.name},
        {QStringLiteral("radiusM"), target.radiusM},
    };
    if (target.location) {
        tg[QStringLiteral("lat")] = target.location->latitude();
        tg[QStringLiteral("lng")] = target.location->longitude();
    }
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("vehicleId"), vehicleId},
        {QStringLiteral("plate"), plate},
        {QStringLiteral("routeCode"), routeCode},
        {QStringLiteral("direction"), opt(direction)},
        {QStringLiteral("target"), tg},
        {QStringLiteral("warnStops"), opt(warnStops)},
        {QStringLiteral("alarm"), alert == AlertKind::Alarm},
        {QStringLiteral("createdAt"), createdAt},
        {QStringLiteral("expiresAt"), expiresAt},
        {QStringLiteral("warned"), warned},
        {QStringLiteral("missedPolls"), missedPolls},
        {QStringLiteral("lastStopsAway"), opt(lastStopsAway)},
        {QStringLiteral("lastMinutesAway"), opt(lastMinutesAway)},
        {QStringLiteral("lastDistanceM"), opt(lastDistanceM)},
        {QStringLiteral("lastSeenAt"), opt(lastSeenAt)},
        {QStringLiteral("waitForRoute"), waitForRoute},
    };
}

Tracking Tracking::fromJson(const QJsonObject &o)
{
    Tracking t;
    t.id = o.value(u"id").toString();
    t.vehicleId = o.value(u"vehicleId").toString();
    t.plate = o.value(u"plate").toString();
    t.routeCode = o.value(u"routeCode").toString();
    t.direction = optInt(o.value(u"direction"));
    const QJsonObject tg = o.value(u"target").toObject();
    t.target.kind = tg.value(u"kind").toString() == u"place" ? Target::NearPlace : Target::AtStop;
    t.target.stopId = tg.value(u"stopId").toString();
    t.target.name = tg.value(u"name").toString();
    t.target.radiusM = tg.value(u"radiusM").toInt();
    if (tg.value(u"lat").isDouble() && tg.value(u"lng").isDouble())
        t.target.location = QGeoCoordinate(tg.value(u"lat").toDouble(), tg.value(u"lng").toDouble());
    t.warnStops = optInt(o.value(u"warnStops"));
    t.alert = o.value(u"alarm").toBool() ? AlertKind::Alarm : AlertKind::Notification;
    t.createdAt = o.value(u"createdAt").toInteger();
    t.expiresAt = o.value(u"expiresAt").toInteger();
    t.warned = o.value(u"warned").toBool();
    t.missedPolls = o.value(u"missedPolls").toInt();
    t.lastStopsAway = optInt(o.value(u"lastStopsAway"));
    t.lastMinutesAway = optInt(o.value(u"lastMinutesAway"));
    t.lastDistanceM = optInt(o.value(u"lastDistanceM"));
    if (o.value(u"lastSeenAt").isDouble())
        t.lastSeenAt = o.value(u"lastSeenAt").toInteger();
    t.waitForRoute = o.value(u"waitForRoute").toBool();
    return t;
}

QVariantMap Tracking::toVariant() const
{
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("vehicleId"), vehicleId},
        {QStringLiteral("plate"), plate},
        {QStringLiteral("routeCode"), routeCode},
        {QStringLiteral("stopId"), target.kind == Target::AtStop ? target.stopId : QString()},
        {QStringLiteral("title"), title(*this)},
        {QStringLiteral("target"), targetName(*this)},
        {QStringLiteral("progress"), progressText(*this)},
        {QStringLiteral("alarm"), alert == AlertKind::Alarm},
        {QStringLiteral("waitForRoute"), waitForRoute},
        {QStringLiteral("expiresAt"), expiresAt},
    };
}

Vehicle Vehicle::fromVariant(const QVariant &v)
{
    const QVariantMap m = v.toMap();
    Vehicle out;
    out.plate = m.value(QStringLiteral("plate")).toString();
    out.routeCode = m.value(QStringLiteral("routeCode")).toString();
    out.vehicleId = m.value(QStringLiteral("vehicleId")).toString();
    out.stopsAway = optInt(m.value(QStringLiteral("stopsAway")));
    out.minutesAway = optInt(m.value(QStringLiteral("minutesAway")));
    if (m.contains(QStringLiteral("lat")) && m.contains(QStringLiteral("lng")))
        out.location = QGeoCoordinate(m.value(QStringLiteral("lat")).toDouble(), m.value(QStringLiteral("lng")).toDouble());
    return out;
}

QString normalizePlate(const QString &plate)
{
    QString p = plate;
    p.remove(QChar(0x00A0));
    p.remove(u' ');
    return p.toUpper();
}

bool matches(const Tracking &t, const Vehicle &v)
{
    if (!t.vehicleId.isEmpty() && !v.vehicleId.isEmpty())
        return t.vehicleId == v.vehicleId;
    return !t.plate.trimmed().isEmpty() && normalizePlate(t.plate) == normalizePlate(v.plate);
}

int distanceMeters(const QGeoCoordinate &a, const QGeoCoordinate &b)
{
    return qRound(a.distanceTo(b));
}

std::optional<Vehicle> nearestOfRoute(const Tracking &t, const QList<Vehicle> &vehicles)
{
    std::optional<Vehicle> best;
    for (const Vehicle &v : vehicles) {
        if (v.routeCode.compare(t.routeCode, Qt::CaseInsensitive) != 0)
            continue;
        if (!best || v.stopsAway.value_or(INT_MAX) < best->stopsAway.value_or(INT_MAX))
            best = v;
    }
    return best;
}

Step step(const Tracking &t, const Observation &obs, qint64 now)
{
    if (now >= t.expiresAt)
        return {std::nullopt, {{Event::Expired, t}}};
    if (!obs.sourcesOk)
        return {t, {}};
    if (t.target.kind == Target::NearPlace)
        return stepNearPlace(t, obs, now);
    return t.waitForRoute ? stepWait(t, obs, now) : stepAtStop(t, obs, now);
}

qint64 nextPollDelayMs(const QList<Tracking> &trackings)
{
    return std::any_of(trackings.begin(), trackings.end(), isNear) ? MinPollMs : FarPollMs;
}

QString targetName(const Tracking &t)
{
    return t.target.name;
}

QString title(const Tracking &t)
{
    return QStringLiteral("%1 · %2 → %3").arg(t.routeCode, t.waitForRoute ? QStringLiteral("ilk araç") : t.plate, targetName(t));
}

QString progressText(const Tracking &t)
{
    if (t.waitForRoute) {
        if (!t.lastStopsAway)
            return QStringLiteral("henüz yaklaşan araç yok");
        QString s = QStringLiteral("en yakını %1 durak").arg(*t.lastStopsAway);
        if (t.lastMinutesAway && *t.lastMinutesAway > 0)
            s += QStringLiteral(" · ~%1 dk").arg(*t.lastMinutesAway);
        return s;
    }
    if (t.missedPolls > 0)
        return QStringLiteral("görülmedi, aranıyor…");
    QStringList parts;
    if (t.lastStopsAway)
        parts << (*t.lastStopsAway <= 0 ? QStringLiteral("durakta") : QStringLiteral("%1 durak").arg(*t.lastStopsAway));
    if (t.lastMinutesAway && *t.lastMinutesAway > 0)
        parts << QStringLiteral("~%1 dk").arg(*t.lastMinutesAway);
    if (parts.isEmpty() && t.lastDistanceM)
        parts << text::formatDistance(*t.lastDistanceM);
    return parts.isEmpty() ? QStringLiteral("aranıyor…") : parts.join(QStringLiteral(" · "));
}

QString Event::title() const
{
    const QString &r = tracking.routeCode;
    switch (kind) {
    case Warn: return QStringLiteral("%1 yaklaşıyor").arg(r);
    case Arrived:
        return tracking.target.kind == Target::NearPlace ? QStringLiteral("%1 yaklaştı").arg(r) : QStringLiteral("%1 durakta").arg(r);
    case Passed: return QStringLiteral("%1 durağı geçti").arg(r);
    case Lost: return QStringLiteral("%1 takibi bitti").arg(r);
    case Expired:
        return tracking.waitForRoute ? QStringLiteral("%1 beklemesi bitti").arg(r) : QStringLiteral("%1 takibi bitti").arg(r);
    }
    return {};
}

QString Event::text() const
{
    const Tracking &t = tracking;
    const QString who = QStringLiteral("%1 (%2)").arg(t.plate, t.routeCode);
    const QString target = targetName(t);
    switch (kind) {
    case Warn: return QStringLiteral("%1 · %2 durağına %3 kaldı").arg(who, target, progressText(t));
    case Arrived:
        if (t.target.kind == Target::NearPlace)
            return QStringLiteral("%1 · %2 çevresinde").arg(who, target)
                + (t.lastDistanceM ? QStringLiteral(" (%1)").arg(text::formatDistance(*t.lastDistanceM)) : QString());
        return QStringLiteral("%1 · %2 durağına geldi").arg(who, target);
    case Passed: return QStringLiteral("%1 · %2 durağını geçmiş görünüyor").arg(who, target);
    case Lost: return QStringLiteral("%1 artık görünmüyor").arg(who);
    case Expired:
        if (t.waitForRoute)
            return QStringLiteral("%1 saat içinde %2 durağına yaklaşan %3 olmadı").arg(WaitDurationMs / 3'600'000).arg(target, t.routeCode);
        return QStringLiteral("%1 · %2 dakikalık takip süresi doldu").arg(who).arg(TrackingDurationMs / 60'000);
    }
    return {};
}

} // namespace tracking
