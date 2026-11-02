#include "KentKart.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QGeoCoordinate>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <algorithm>
#include <memory>

namespace kk {

static QString str(const QJsonObject &o, const char *key)
{
    const QJsonValue v = o.value(QLatin1String(key));
    if (v.isString())
        return v.toString().trimmed();
    if (v.isDouble())
        return QString::number(v.toDouble(), 'g', 15);
    return {};
}

static QStringList splitCsv(const QString &s)
{
    if (s.trimmed().isEmpty())
        return {};
    QStringList parts = s.split(u',');
    for (QString &p : parts)
        p = p.trimmed();
    return parts;
}

static QVariant intOrNull(const QString &s)
{
    bool ok = false;
    const int v = s.trimmed().toInt(&ok);
    return ok ? QVariant(v) : QVariant();
}

static QVariant doubleOrNull(const QString &s)
{
    bool ok = false;
    const double v = s.trimmed().toDouble(&ok);
    return ok ? QVariant(v) : QVariant();
}

/** Bazı plakalarda boşluk yerine NBSP geliyor. */
static QString cleanPlate(QString plate)
{
    return plate.replace(QChar(0x00A0), u' ').trimmed();
}

static void putLocation(QVariantMap &m, const QString &lat, const QString &lng)
{
    const QVariant la = doubleOrNull(lat), ln = doubleOrNull(lng);
    if (la.isValid() && ln.isValid()) {
        m[QStringLiteral("lat")] = la;
        m[QStringLiteral("lng")] = ln;
    }
}

QString parseColor(const QString &hex, const QString &fallback)
{
    QString clean = hex.trimmed();
    if (clean.startsWith(u'#'))
        clean.remove(0, 1);
    if (clean.size() != 6)
        return fallback;
    bool ok = false;
    clean.toUInt(&ok, 16);
    return ok ? u'#' + clean.toUpper() : fallback;
}

int routeType(const QString &value)
{
    const QString v = value.trimmed();
    if (v == u"3") return 3;
    if (v == u"0") return 0;
    if (v == u"4") return 4;
    if (v == u"7") return 7;
    return -1;
}

QVariantList parseBadges(const QString &routes, const QString &colors, const QString &types, const QString &textColors)
{
    const QStringList codes = splitCsv(routes), c = splitCsv(colors), t = splitCsv(types), tc = splitCsv(textColors);
    qsizetype count = -1;
    for (const QStringList *l : {&codes, &c, &t, &tc})
        if (!l->isEmpty())
            count = count < 0 ? l->size() : std::min(count, l->size());
    QVariantList out;
    for (qsizetype i = 0; i < count; ++i) {
        const QString code = codes.value(i);
        if (code.isEmpty())
            continue;
        out.append(QVariantMap{
            {QStringLiteral("code"), code},
            {QStringLiteral("color"), parseColor(c.value(i), QLatin1String(DefaultRouteColor))},
            {QStringLiteral("textColor"), parseColor(tc.value(i), QLatin1String(DefaultTextColor))},
            {QStringLiteral("type"), routeType(t.value(i))},
        });
    }
    return out;
}

std::optional<int> parseServiceMinute(const QString &value)
{
    const QStringList parts = value.trimmed().split(u':');
    if (parts.size() < 2)
        return std::nullopt;
    bool okH = false, okM = false;
    const int h = parts[0].toInt(&okH), m = parts[1].toInt(&okM);
    if (!okH || !okM || h < 0 || m < 0 || m > 59)
        return std::nullopt;
    return h * 60 + m;
}

QString clock(int minute)
{
    const int m = ((minute % MinutesPerDay) + MinutesPerDay) % MinutesPerDay;
    return QStringLiteral("%1:%2").arg(m / 60, 2, 10, QChar(u'0')).arg(m % 60, 2, 10, QChar(u'0'));
}

int serviceMinute(const QTime &now)
{
    const int minute = now.hour() * 60 + now.minute();
    return minute < ServiceDayStartMinute ? minute + MinutesPerDay : minute;
}

QList<int> parseDayMask(const QString &mask)
{
    QList<int> days;
    const QString m = mask.trimmed().left(7);
    for (int i = 0; i < m.size(); ++i)
        if (m[i].isUpper())
            days.append(i + 1);
    return days;
}

QVariantMap stop(const QJsonObject &o)
{
    QVariantMap m{
        {QStringLiteral("id"), str(o, "stopId")},
        {QStringLiteral("name"), str(o, "stopName")},
        {QStringLiteral("routes"), parseBadges(str(o, "routes"), str(o, "route_color"), str(o, "route_type"), str(o, "route_text_color"))},
        {QStringLiteral("wheelchair"), str(o, "wheelchair_boarding") == u"1"},
    };
    const QVariant km = doubleOrNull(str(o, "distance"));
    if (km.isValid())
        m[QStringLiteral("distance")] = km.toDouble() * 1000.0;
    putLocation(m, str(o, "lat"), str(o, "lng"));
    return m;
}

QVariantMap searchStop(const QJsonObject &o)
{
    QVariantMap m{
        {QStringLiteral("id"), str(o, "stopId")},
        {QStringLiteral("name"), str(o, "name")},
        {QStringLiteral("routes"), QVariantList()},
        {QStringLiteral("wheelchair"), false},
    };
    putLocation(m, str(o, "lat"), str(o, "lng"));
    return m;
}

QVariantMap route(const QJsonObject &o)
{
    return {
        {QStringLiteral("routeCode"), str(o, "routeCode")},
        {QStringLiteral("code"), str(o, "displayRouteCode")},
        {QStringLiteral("name"), str(o, "name")},
        {QStringLiteral("color"), parseColor(str(o, "routeColor"), QLatin1String(DefaultRouteColor))},
        {QStringLiteral("textColor"), parseColor(str(o, "routeTextColor"), QLatin1String(DefaultTextColor))},
        {QStringLiteral("type"), routeType(str(o, "routeType"))},
        {QStringLiteral("agency"), str(o, "agencyName")},
    };
}

QVariantMap closestVehicle(const QJsonObject &o)
{
    QVariantMap m{
        {QStringLiteral("plate"), cleanPlate(str(o, "plate"))},
        {QStringLiteral("routeCode"), str(o, "displayRouteCode")},
        {QStringLiteral("color"), parseColor(str(o, "routeColor"), QLatin1String(DefaultRouteColor))},
        {QStringLiteral("textColor"), parseColor(str(o, "routeTextColor"), QLatin1String(DefaultTextColor))},
        {QStringLiteral("headSign"), str(o, "headSign")},
        {QStringLiteral("bearing"), doubleOrNull(str(o, "bearing"))},
        {QStringLiteral("stopsAway"), intOrNull(str(o, "stopDiff"))},
        {QStringLiteral("minutesAway"), intOrNull(str(o, "timeDiff"))},
        {QStringLiteral("vehicleId"), str(o, "busId")},
        {QStringLiteral("accessible"), str(o, "disabledPerson") == u"1"},
        {QStringLiteral("direction"), intOrNull(str(o, "direction"))},
    };
    putLocation(m, str(o, "lat"), str(o, "lng"));
    return m;
}

QVariantMap pathVehicle(const QJsonObject &o, const QString &routeCode, int direction)
{
    QVariantMap m{
        {QStringLiteral("plate"), cleanPlate(str(o, "plateNumber"))},
        {QStringLiteral("routeCode"), routeCode},
        {QStringLiteral("headSign"), str(o, "busLabel")},
        {QStringLiteral("bearing"), doubleOrNull(str(o, "bearing"))},
        {QStringLiteral("stopsAway"), QVariant()},
        {QStringLiteral("minutesAway"), intOrNull(str(o, "timeDiff"))},
        {QStringLiteral("stopId"), str(o, "stopId")},
        {QStringLiteral("vehicleId"), str(o, "busId")},
        {QStringLiteral("accessible"), str(o, "disabledPerson") == u"1"},
        {QStringLiteral("direction"), direction},
    };
    putLocation(m, str(o, "lat"), str(o, "lng"));
    return m;
}

QVariantMap arrivals(const QJsonObject &root, const QString &requestedStopId)
{
    const QJsonObject info = root.value(u"stopInfo").toObject();
    QVariantList vehicles;
    for (const QJsonValue &v : root.value(u"busList").toArray())
        vehicles.append(closestVehicle(v.toObject()));
    std::stable_sort(vehicles.begin(), vehicles.end(), [](const QVariant &a, const QVariant &b) {
        const QVariant sa = a.toMap().value(QStringLiteral("stopsAway")), sb = b.toMap().value(QStringLiteral("stopsAway"));
        if (!sa.isValid()) return false;
        if (!sb.isValid()) return true;
        return sa.toInt() < sb.toInt();
    });

    QVariantList nextTrips;
    for (const QJsonValue &v : root.value(u"routeList").toArray()) {
        const QJsonObject o = v.toObject();
        const QString t = str(o, "nextTripArrivalTime");
        QString time;
        if (!t.isEmpty()) {
            const auto minute = parseServiceMinute(t);
            time = minute ? clock(*minute) : t.left(5);
        }
        nextTrips.append(QVariantMap{
            {QStringLiteral("routeCode"), str(o, "displayRouteCode")},
            {QStringLiteral("headSign"), str(o, "headSign")},
            {QStringLiteral("color"), parseColor(str(o, "routeColor"), QLatin1String(DefaultRouteColor))},
            {QStringLiteral("textColor"), parseColor(str(o, "routeTextColor"), QLatin1String(DefaultTextColor))},
            {QStringLiteral("type"), routeType(str(o, "routeType"))},
            {QStringLiteral("time"), time},
        });
    }

    const QString id = str(info, "busStopid");
    QVariantMap m{
        {QStringLiteral("stopId"), id.isEmpty() ? requestedStopId : id},
        {QStringLiteral("stopName"), str(info, "busStopName")},
        {QStringLiteral("vehicles"), vehicles},
        {QStringLiteral("nextTrips"), nextTrips},
        {QStringLiteral("fetchedAt"), QDateTime::currentDateTime()},
    };
    putLocation(m, str(info, "lat"), str(info, "lng"));
    return m;
}

QVariantMap departure(const QJsonObject &o)
{
    const QString raw = str(o, "departureTime");
    const auto minute = parseServiceMinute(raw);
    return {
        {QStringLiteral("time"), minute ? clock(*minute) : raw.left(5)},
        {QStringLiteral("minute"), minute ? QVariant(*minute) : QVariant()},
        {QStringLiteral("nextDay"), minute && *minute >= MinutesPerDay},
        {QStringLiteral("tripId"), str(o, "tripId")},
        {QStringLiteral("note"), str(o, "tripHeadSign")},
    };
}

static int seqOf(const QJsonObject &o)
{
    return str(o, "seq").toInt();
}

QVariantMap routeDetail(const QJsonObject &path, const QString &requestedCode, int requestedDirection)
{
    QString code = str(path, "displayRouteCode");
    if (code.isEmpty())
        code = requestedCode;
    bool ok = false;
    int direction = str(path, "direction").toInt(&ok);
    if (!ok)
        direction = requestedDirection;

    QList<QJsonObject> points;
    for (const QJsonValue &v : path.value(u"pointList").toArray())
        points.append(v.toObject());
    std::stable_sort(points.begin(), points.end(), [](const auto &a, const auto &b) { return seqOf(a) < seqOf(b); });
    QVariantList line;
    for (const QJsonObject &p : points) {
        const QVariant la = doubleOrNull(str(p, "lat")), ln = doubleOrNull(str(p, "lng"));
        if (la.isValid() && ln.isValid())
            line.append(QVariant::fromValue(QGeoCoordinate(la.toDouble(), ln.toDouble())));
    }

    QList<QJsonObject> stopObjs;
    for (const QJsonValue &v : path.value(u"busStopList").toArray())
        stopObjs.append(v.toObject());
    std::stable_sort(stopObjs.begin(), stopObjs.end(), [](const auto &a, const auto &b) { return seqOf(a) < seqOf(b); });
    QVariantList stops;
    for (const QJsonObject &s : stopObjs) {
        QVariantMap m{
            {QStringLiteral("seq"), seqOf(s)},
            {QStringLiteral("id"), str(s, "stopId")},
            {QStringLiteral("name"), str(s, "stopName")},
            // API saniye veriyor (belge dakika diyor; yanlış).
            {QStringLiteral("offsetMin"), [&] {
                 const QVariant sec = intOrNull(str(s, "arrival_offset"));
                 return sec.isValid() ? QVariant(sec.toInt() / 60) : QVariant();
             }()},
            {QStringLiteral("routes"), parseBadges(str(s, "routes"), str(s, "routeColor"), str(s, "routeType"), str(s, "routeTextColor"))},
        };
        putLocation(m, str(s, "lat"), str(s, "lng"));
        stops.append(m);
    }

    QVariantList upcoming;
    for (const QJsonValue &v : path.value(u"timeTableList").toArray())
        upcoming.append(departure(v.toObject()));

    QVariantList schedules;
    for (const QJsonValue &v : path.value(u"scheduleList").toArray()) {
        const QJsonObject s = v.toObject();
        QVariantList deps;
        for (const QJsonValue &d : s.value(u"timeList").toArray())
            deps.append(departure(d.toObject()));
        QVariantList days;
        for (int d : parseDayMask(str(s, "description")))
            days.append(d);
        schedules.append(QVariantMap{
            {QStringLiteral("mask"), str(s, "description")},
            {QStringLiteral("days"), days},
            {QStringLiteral("departures"), deps},
        });
    }

    QVariantList vehicles;
    for (const QJsonValue &v : path.value(u"busList").toArray())
        vehicles.append(pathVehicle(v.toObject(), code, direction));

    return {
        {QStringLiteral("code"), code},
        {QStringLiteral("direction"), direction},
        {QStringLiteral("headSign"), str(path, "headSign")},
        {QStringLiteral("note"), str(path, "tripShortName")},
        {QStringLiteral("path"), line},
        {QStringLiteral("stops"), stops},
        {QStringLiteral("upcoming"), upcoming},
        {QStringLiteral("schedules"), schedules},
        {QStringLiteral("vehicles"), vehicles},
    };
}

QVariantMap announcement(const QJsonObject &o)
{
    auto date = [&](const char *key) {
        const QDateTime d = QDateTime::fromString(str(o, key), QStringLiteral("yyyyMMddHHmmss"));
        return d.isValid() ? QVariant(d) : QVariant();
    };
    return {
        {QStringLiteral("id"), o.value(u"id").toVariant()},
        {QStringLiteral("title"), str(o, "title")},
        {QStringLiteral("description"), str(o, "description")},
        {QStringLiteral("validFrom"), date("valid_from")},
        {QStringLiteral("validTo"), date("valid_to")},
    };
}

} // namespace kk

static const QString BaseUrl = QStringLiteral("https://service.kentkart.com/rl1/");

KentKart::KentKart(QObject *parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
{
    m_clock.start();
}

void KentKart::get(const QString &path, QUrlQuery query, Raw done, QList<int> allowedCodes)
{
    query.addQueryItem(QStringLiteral("region"), QStringLiteral("004"));
    query.addQueryItem(QStringLiteral("authType"), QStringLiteral("4"));
    query.addQueryItem(QStringLiteral("accuracy"), QStringLiteral("0"));
    query.addQueryItem(QStringLiteral("lang"), QStringLiteral("tr"));
    QUrl url(BaseUrl + path);
    url.setQuery(query);

    QNetworkRequest req(url);
    req.setTransferTimeout(15'000);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("KocaeliUlasimMasaustu/1.0"));
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [reply, done = std::move(done), allowedCodes] {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::OperationCanceledError || reply->error() == QNetworkReply::TimeoutError) {
            done(QStringLiteral("Sunucu zamanında yanıt vermedi."), {});
            return;
        }
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError && http == 0) {
            done(QStringLiteral("Bağlantı kurulamadı. İnternetinizi kontrol edin."), {});
            return;
        }
        if (http >= 400) {
            done(QStringLiteral("Sunucu yanıt vermedi (HTTP %1).").arg(http), {});
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject()) {
            done(QStringLiteral("Beklenmeyen sunucu yanıtı."), {});
            return;
        }
        const QJsonObject root = doc.object();
        const QJsonObject result = root.value(u"result").toObject();
        const int code = result.value(u"code").toInt(-1);
        if (code != 0 && !allowedCodes.contains(code)) {
            const QString msg = result.value(u"message").toString().trimmed();
            // Kök de verilir: çağıran ağ hatasını (boş kök) API hatasından ayırabilsin.
            done(msg.isEmpty() ? QStringLiteral("Sunucu hatası (kod %1)").arg(code) : msg, root);
            return;
        }
        done({}, root);
    });
}

void KentKart::closestStops(double lat, double lng, Done<QVariantList> done)
{
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("lat"), QString::number(lat, 'f', 6));
    q.addQueryItem(QStringLiteral("lng"), QString::number(lng, 'f', 6));
    get(QStringLiteral("api/stop/closest"), q, [done](const QString &err, const QJsonObject &root) {
        QVariantList stops;
        for (const QJsonValue &v : root.value(u"busStopList").toArray())
            stops.append(kk::stop(v.toObject()));
        done(err, stops);
    });
}

void KentKart::stopArrivals(const QString &stopId, Done<QVariantMap> done)
{
    const qint64 now = m_clock.elapsed();
    auto it = m_recentArrivals.constFind(stopId);
    if (it != m_recentArrivals.constEnd() && now - it->at < ArrivalsTtlMs) {
        done({}, it->value);
        return;
    }
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("busStopId"), stopId);
    get(QStringLiteral("api/bus/closest"), q, [this, stopId, done](const QString &err, const QJsonObject &root) {
        if (!err.isEmpty()) {
            done(err, {});
            return;
        }
        const QVariantMap value = kk::arrivals(root, stopId);
        const qint64 at = m_clock.elapsed();
        m_recentArrivals.removeIf([at](const auto &e) { return at - e.value().at >= ArrivalsTtlMs; });
        m_recentArrivals.insert(stopId, {at, value});
        done({}, value);
    });
}

void KentKart::searchStops(const QString &keyword, Done<QVariantList> done)
{
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("keyword"), keyword);
    get(QStringLiteral("api/v2.0/route/list"), q, [done](const QString &err, const QJsonObject &root) {
        QVariantList stops;
        // Eşleşme yoksa API code 3 "Sonuç Bulunamadı" döndürür → boş liste.
        if (root.value(u"result").toObject().value(u"code").toInt() == 0)
            for (const QJsonValue &v : root.value(u"stopList").toArray())
                stops.append(kk::searchStop(v.toObject()));
        done(err, stops);
    }, {NoResultCode});
}

void KentKart::allRoutes(Done<QJsonArray> done)
{
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("keyword"), QString());
    get(QStringLiteral("api/v2.0/route/list"), q, [done](const QString &err, const QJsonObject &root) {
        done(err, root.value(u"routeList").toArray());
    });
}

static QUrlQuery routeQuery(const QString &code, int direction, const char *resultType)
{
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("displayRouteCode"), code);
    q.addQueryItem(QStringLiteral("direction"), QString::number(direction));
    q.addQueryItem(QStringLiteral("resultType"), QLatin1String(resultType));
    return q;
}

QString KentKart::routeCachePath(const QString &code, int direction) const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/routeinfo");
    QString safe = code;
    safe.replace(QRegularExpression(QStringLiteral("[^\\p{L}\\p{N}_-]")), QStringLiteral("_"));
    return dir + u'/' + safe + u'_' + QString::number(direction) + QStringLiteral(".json");
}

std::optional<QJsonObject> KentKart::loadCachedPath(const QString &code, int direction, qint64 *savedAt) const
{
    QFile f(routeCachePath(code, direction));
    if (!f.open(QIODevice::ReadOnly))
        return std::nullopt;
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    if (!o.contains(u"path"))
        return std::nullopt;
    if (savedAt)
        *savedAt = o.value(u"savedAt").toInteger();
    return o.value(u"path").toObject();
}

void KentKart::routeDetail(const QString &code, int direction, Done<QVariantMap> done)
{
    get(QStringLiteral("api/v2.0/route/info"), routeQuery(code, direction, "111111"),
        [this, code, direction, done](const QString &err, const QJsonObject &root) {
            if (!err.isEmpty()) {
                // Yalnızca ağ/sunucu hatasında; API'nin kendi hatası (ör. tanımsız hat) olduğu gibi gösterilir.
                const bool network = root.isEmpty();
                qint64 savedAt = 0;
                if (network) {
                    if (auto cached = loadCachedPath(code, direction, &savedAt)) {
                        QVariantMap detail = kk::routeDetail(*cached, code, direction);
                        detail[QStringLiteral("vehicles")] = QVariantList();
                        detail[QStringLiteral("offline")] = true;
                        detail[QStringLiteral("savedAt")] = QDateTime::fromMSecsSinceEpoch(savedAt);
                        done({}, detail);
                        return;
                    }
                }
                done(err, {});
                return;
            }
            const QJsonArray paths = root.value(u"pathList").toArray();
            if (paths.isEmpty()) {
                done({}, {});
                return;
            }
            const QJsonObject path = paths.first().toObject();
            const QString file = routeCachePath(code, direction);
            QDir().mkpath(QFileInfo(file).absolutePath());
            QFile f(file);
            if (f.open(QIODevice::WriteOnly)) {
                QJsonObject copy = path;
                copy.remove(QStringLiteral("busList"));
                f.write(QJsonDocument(QJsonObject{{QStringLiteral("savedAt"), QDateTime::currentMSecsSinceEpoch()},
                                                  {QStringLiteral("path"), copy}})
                            .toJson(QJsonDocument::Compact));
            }
            done({}, kk::routeDetail(path, code, direction));
        });
}

void KentKart::routeVehicles(const QString &code, int direction, Done<QVariantList> done)
{
    get(QStringLiteral("api/v2.0/route/info"), routeQuery(code, direction, "010000"),
        [code, direction, done](const QString &err, const QJsonObject &root) {
            QVariantList vehicles;
            const QJsonArray paths = root.value(u"pathList").toArray();
            if (!paths.isEmpty())
                for (const QJsonValue &v : paths.first().toObject().value(u"busList").toArray())
                    vehicles.append(kk::pathVehicle(v.toObject(), code, direction));
            done(err, vehicles);
        });
}

void KentKart::stopsBefore(const QString &code, const QString &stopId, std::function<void(int)> done)
{
    auto best = std::make_shared<int>(-1);
    auto indexIn = [stopId](const QJsonArray &stops) {
        QList<QJsonObject> list;
        for (const QJsonValue &v : stops)
            list.append(v.toObject());
        std::stable_sort(list.begin(), list.end(), [](const auto &a, const auto &b) { return kk::str(a, "seq").toInt() < kk::str(b, "seq").toInt(); });
        for (int i = 0; i < list.size(); ++i)
            if (kk::str(list[i], "stopId") == stopId)
                return i;
        return -1;
    };
    // İki yön sırayla: önce cihazdaki kopya, yoksa yalnızca durak listesi (~20 KB).
    auto step = std::make_shared<std::function<void(int)>>();
    *step = [=, this](int direction) {
        if (direction > 1) {
            done(*best);
            *step = nullptr; // döngüyü kır
            return;
        }
        if (auto cached = loadCachedPath(code, direction)) {
            *best = std::max(*best, indexIn(cached->value(u"busStopList").toArray()));
            (*step)(direction + 1);
            return;
        }
        get(QStringLiteral("api/v2.0/route/info"), routeQuery(code, direction, "001000"),
            [=](const QString &err, const QJsonObject &root) {
                const QJsonArray paths = root.value(u"pathList").toArray();
                if (err.isEmpty() && !paths.isEmpty())
                    *best = std::max(*best, indexIn(paths.first().toObject().value(u"busStopList").toArray()));
                (*step)(direction + 1);
            });
    };
    (*step)(0);
}

void KentKart::announcements(Done<QVariantList> done)
{
    get(QStringLiteral("api/info/announce"), {}, [done](const QString &err, const QJsonObject &root) {
        QVariantList list;
        for (const QJsonValue &v : root.value(u"announceList").toArray())
            list.append(kk::announcement(v.toObject()));
        done(err, list);
    });
}
