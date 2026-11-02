#pragma once

// KentKart public GET uçları (yalnızca region=004, Kocaeli) ve yanıtların QML'e
// uygun haritalara dönüştürülmesi. API neredeyse tüm değerleri string döndürür;
// dönüşüm burada yapılır (bkz. KENTKART_API.md ve PLAN §2).

#include <QDateTime>
#include <QElapsedTimer>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QUrlQuery>
#include <QVariantList>
#include <QVariantMap>
#include <functional>
#include <optional>

class QNetworkAccessManager;

namespace kk {

inline constexpr int MinutesPerDay = 24 * 60;
/** Gece seferleri 27:30'a kadar sürer; 04:00'ten önceki "şimdi" önceki servis gününe sayılır. */
inline constexpr int ServiceDayStartMinute = 4 * 60;
inline constexpr const char *DefaultRouteColor = "#1EA9BD";
inline constexpr const char *DefaultTextColor = "#FFFFFF";

/** `#` olmadan 6 haneli hex ("000FE7") → "#000FE7". Boş/bozuksa [fallback]. */
QString parseColor(const QString &hex, const QString &fallback);

/** "3" otobüs, "0" tramvay, "4" vapur, "7" teleferik; diğerleri -1. */
int routeType(const QString &value);

/** Virgülle ayrık, indeks hizalı alanlar; kısa olana göre kesilir. */
QVariantList parseBadges(const QString &routes, const QString &colors, const QString &types, const QString &textColors);

/** "HH:mm[:ss]" → servis gününün başından dakika; 24'ü aşabilir ("25:30" → 1530). Okunamazsa nullopt. */
std::optional<int> parseServiceMinute(const QString &value);

/** Dakika → "HH:mm"; 24 saati aşan değer ertesi günün saatine indirgenir. */
QString clock(int minute);

/** Servis günü içindeki dakika (00:30 → 1470, önceki gün). */
int serviceMinute(const QTime &now);

/** "MTWTFss" → aktif günler (1 = Pazartesi … 7 = Pazar). */
QList<int> parseDayMask(const QString &mask);

QVariantMap stop(const QJsonObject &o);
QVariantMap searchStop(const QJsonObject &o);
QVariantMap route(const QJsonObject &o);
QVariantMap closestVehicle(const QJsonObject &o);
QVariantMap pathVehicle(const QJsonObject &o, const QString &routeCode, int direction);
QVariantMap arrivals(const QJsonObject &root, const QString &requestedStopId);
QVariantMap departure(const QJsonObject &o);
QVariantMap routeDetail(const QJsonObject &path, const QString &requestedCode, int requestedDirection);
QVariantMap announcement(const QJsonObject &o);

} // namespace kk

class KentKart : public QObject
{
    Q_OBJECT
public:
    template<typename T>
    using Done = std::function<void(const QString &error, const T &value)>;

    static constexpr qint64 ArrivalsTtlMs = 15'000;
    static constexpr int NoResultCode = 3;

    explicit KentKart(QObject *parent = nullptr);

    void closestStops(double lat, double lng, Done<QVariantList> done);
    /** Aynı durak için 15 sn'den genç başarılı yanıt yeniden kullanılır (API nezaketi). */
    void stopArrivals(const QString &stopId, Done<QVariantMap> done);
    void searchStops(const QString &keyword, Done<QVariantList> done);
    void allRoutes(Done<QJsonArray> done);
    /** Ağ hatasında son kayıtlı kopya döner (`offline`, `savedAt` alanlarıyla, araçsız). */
    void routeDetail(const QString &code, int direction, Done<QVariantMap> done);
    void routeVehicles(const QString &code, int direction, Done<QVariantList> done);
    /** Durağın hattın başından sırası (iki yönden büyüğü); bilinmiyorsa -1. */
    void stopsBefore(const QString &code, const QString &stopId, std::function<void(int)> done);
    void announcements(Done<QVariantList> done);

private:
    using Raw = std::function<void(const QString &error, const QJsonObject &root)>;
    /** `result.code != 0` hata sayılır; [allowedCodes] dışında. */
    void get(const QString &path, QUrlQuery query, Raw done, QList<int> allowedCodes = {});
    QString routeCachePath(const QString &code, int direction) const;
    std::optional<QJsonObject> loadCachedPath(const QString &code, int direction, qint64 *savedAt = nullptr) const;

    struct TimedArrivals {
        qint64 at;
        QVariantMap value;
    };
    QNetworkAccessManager *m_net;
    QElapsedTimer m_clock;
    QHash<QString, TimedArrivals> m_recentArrivals;
};
