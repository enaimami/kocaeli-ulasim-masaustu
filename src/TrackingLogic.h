#pragma once

// Varış takibi (PLAN Faz 8, §0 istisnası): takip modeli, bir yoklama turunun
// değerlendirilmesi ve tur aralığı. Qt Quick'siz saf mantık; testli.

#include <QGeoCoordinate>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QVariantMap>
#include <optional>

namespace tracking {

inline constexpr int MaxTrackings = 5;
inline constexpr qint64 TrackingDurationMs = 60 * 60'000LL;
inline constexpr qint64 WaitDurationMs = 6 * 60 * 60'000LL;
inline constexpr qint64 MinPollMs = 20'000;
inline constexpr qint64 FarPollMs = 60'000;
inline constexpr int ArrivalRadiusM = 60;
inline constexpr int PassWindowStops = 2;
inline constexpr int LostAfterPolls = 3;

enum class AlertKind { Notification, Alarm };

struct Target {
    enum Kind { AtStop, NearPlace } kind = AtStop;
    QString stopId;      // AtStop
    QString name;        // durak adı ya da yer etiketi
    std::optional<QGeoCoordinate> location; // durak konumu (biliniyorsa) ya da yer
    int radiusM = 0;     // NearPlace
};

struct Tracking {
    QString id;
    QString vehicleId;   // API busId; boşsa plakayla eşleşir
    QString plate;
    QString routeCode;
    std::optional<int> direction;
    Target target;
    std::optional<int> warnStops;
    AlertKind alert = AlertKind::Notification;
    qint64 createdAt = 0;
    qint64 expiresAt = 0;
    bool warned = false;
    int missedPolls = 0;
    std::optional<int> lastStopsAway;
    std::optional<int> lastMinutesAway;
    std::optional<int> lastDistanceM;
    std::optional<qint64> lastSeenAt;
    /** Araç seçilmeden "bu hattın ilk aracı gelince haber ver". */
    bool waitForRoute = false;

    QJsonObject toJson() const;
    static Tracking fromJson(const QJsonObject &o);
    QVariantMap toVariant() const;
};

struct Vehicle {
    QString plate, routeCode, vehicleId;
    std::optional<int> stopsAway, minutesAway;
    std::optional<QGeoCoordinate> location;
    static Vehicle fromVariant(const QVariant &v);
};

struct Observation {
    std::optional<Vehicle> approaching; // hedef durağa yaklaşanlar (bus/closest)
    std::optional<Vehicle> onRoute;     // hattaki canlı araçlar (route/info)
    bool sourcesOk = true;              // ağ hatasında tur yok sayılır
    std::optional<QGeoCoordinate> targetLocation;
    static Observation unavailable() { Observation o; o.sourcesOk = false; return o; }
};

struct Event {
    enum Kind { Warn, Arrived, Passed, Lost, Expired } kind;
    Tracking tracking;
    bool important() const { return kind == Warn || kind == Arrived || kind == Passed; }
    QString title() const;
    QString text() const;
};

struct Step {
    std::optional<Tracking> tracking; // nullopt → takip bitti
    QList<Event> events;
};

bool matches(const Tracking &t, const Vehicle &v);
QString normalizePlate(const QString &plate);
int distanceMeters(const QGeoCoordinate &a, const QGeoCoordinate &b);

/** Hat beklemesi için: hedef durağa yaklaşan, bu hattın en yakın aracı. */
std::optional<Vehicle> nearestOfRoute(const Tracking &t, const QList<Vehicle> &vehicles);

/** Bir takibi bu turun gözlemiyle ilerletir. Her tetikleyici tek sefer ateşlenir. */
Step step(const Tracking &t, const Observation &obs, qint64 now);

/** Hedefe yakın (ya da henüz görülmemiş) takip varsa sık, yoksa seyrek. */
qint64 nextPollDelayMs(const QList<Tracking> &trackings);

QString targetName(const Tracking &t);
/** "200 · 41 KT 001 → OTOGAR". */
QString title(const Tracking &t);
/** "3 durak · ~6 dk", "1,2 km", "aranıyor…". */
QString progressText(const Tracking &t);

} // namespace tracking
