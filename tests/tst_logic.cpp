#include "KentKart.h"
#include "Text.h"
#include "TrackingLogic.h"

#include <QFile>
#include <QGeoCoordinate>
#include <QJsonDocument>
#include <QTest>

using namespace tracking;

static QJsonObject fixture(const char *name)
{
    QFile f(QStringLiteral(FIXTURES_DIR "/") + QLatin1String(name));
    if (!f.open(QIODevice::ReadOnly))
        qFatal("fixture yok: %s", name);
    return QJsonDocument::fromJson(f.readAll()).object();
}

static Tracking stopTracking()
{
    Tracking t;
    t.id = QStringLiteral("t1");
    t.vehicleId = QStringLiteral("42");
    t.plate = QStringLiteral("41 KT 001");
    t.routeCode = QStringLiteral("200");
    t.direction = 0;
    t.target.stopId = QStringLiteral("80399");
    t.target.name = QStringLiteral("OTOGAR");
    t.warnStops = 2;
    t.expiresAt = 1'000'000;
    return t;
}

static Vehicle vehicle(std::optional<int> stops, QString id = QStringLiteral("42"))
{
    Vehicle v;
    v.vehicleId = id;
    v.plate = QStringLiteral("41 KT 001");
    v.routeCode = QStringLiteral("200");
    v.stopsAway = stops;
    return v;
}

class LogicTest : public QObject
{
    Q_OBJECT
private slots:
    void colors()
    {
        QCOMPARE(kk::parseColor(QStringLiteral("000fe7"), QStringLiteral("#111111")), QStringLiteral("#000FE7"));
        QCOMPARE(kk::parseColor(QStringLiteral(""), QStringLiteral("#111111")), QStringLiteral("#111111"));
        QCOMPARE(kk::parseColor(QStringLiteral("zzzzzz"), QStringLiteral("#111111")), QStringLiteral("#111111"));
    }

    void badgesAlignToShortest()
    {
        const QVariantList b = kk::parseBadges(QStringLiteral("T1,T2,T3"), QStringLiteral("DEDC00,DEDC00"),
                                               QStringLiteral("0,0,0"), QStringLiteral("FFFFFF,FFFFFF,FFFFFF"));
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()[QStringLiteral("code")].toString(), QStringLiteral("T1"));
        QCOMPARE(b[0].toMap()[QStringLiteral("type")].toInt(), 0);
    }

    void serviceTimes()
    {
        QCOMPARE(*kk::parseServiceMinute(QStringLiteral("25:30:00")), 1530);
        QCOMPARE(kk::clock(1530), QStringLiteral("01:30"));
        QVERIFY(!kk::parseServiceMinute(QStringLiteral("x")));
        QCOMPARE(kk::serviceMinute(QTime(0, 30)), 1470);
        QCOMPARE(kk::serviceMinute(QTime(15, 0)), 900);
        QCOMPARE(kk::parseDayMask(QStringLiteral("MTWTFss")), (QList<int>{1, 2, 3, 4, 5}));
        QCOMPARE(kk::parseDayMask(QStringLiteral("mtwtfsS")), (QList<int>{7}));
    }

    void closestStopsFixture()
    {
        const QJsonArray list = fixture("stop_closest.json").value(u"busStopList").toArray();
        QVERIFY(!list.isEmpty());
        const QVariantMap s = kk::stop(list.first().toObject());
        QVERIFY(!s[QStringLiteral("id")].toString().isEmpty());
        QVERIFY(s.contains(QStringLiteral("lat")));
        QVERIFY(s[QStringLiteral("distance")].toDouble() >= 0);
        QVERIFY(!s[QStringLiteral("routes")].toList().isEmpty());
    }

    void arrivalsFixtureSorted()
    {
        const QVariantMap a = kk::arrivals(fixture("bus_closest_80399.json"), QStringLiteral("80399"));
        const QVariantList v = a[QStringLiteral("vehicles")].toList();
        QVERIFY(!v.isEmpty());
        int last = -1;
        for (const QVariant &x : v) {
            const QVariant s = x.toMap()[QStringLiteral("stopsAway")];
            if (!s.isValid())
                continue;
            QVERIFY(s.toInt() >= last);
            last = s.toInt();
            QVERIFY(!x.toMap()[QStringLiteral("plate")].toString().contains(QChar(0x00A0)));
        }
    }

    void routeInfoFixture()
    {
        const QJsonObject path = fixture("route_info_200_d0.json").value(u"pathList").toArray().first().toObject();
        const QVariantMap d = kk::routeDetail(path, QStringLiteral("200"), 0);
        QCOMPARE(d[QStringLiteral("code")].toString(), QStringLiteral("200"));
        QVERIFY(d[QStringLiteral("path")].toList().size() > 10);
        const QVariantList stops = d[QStringLiteral("stops")].toList();
        QVERIFY(stops.size() > 5);
        int prev = -1;
        for (const QVariant &s : stops) {
            QVERIFY(s.toMap()[QStringLiteral("seq")].toInt() >= prev);
            prev = s.toMap()[QStringLiteral("seq")].toInt();
        }
        QVERIFY(!d[QStringLiteral("schedules")].toList().isEmpty());
    }

    void searchTurkish()
    {
        QCOMPARE(text::normalizeForSearch(QStringLiteral("İZMİT Çarşı")), QStringLiteral("izmit carsi"));
        QVariantList routes;
        for (const QJsonValue &v : fixture("route_list_all.json").value(u"routeList").toArray())
            routes.append(kk::route(v.toObject()));
        text::RouteIndex idx;
        idx.reset(routes);
        const QVariantList r200 = idx.search(QStringLiteral("200"));
        QVERIFY(!r200.isEmpty());
        QCOMPARE(r200.first().toMap()[QStringLiteral("code")].toString(), QStringLiteral("200"));
        QVERIFY(!idx.search(QStringLiteral("T1")).isEmpty());
        QVERIFY(!idx.search(QStringLiteral("izmit")).isEmpty());
        QCOMPARE(idx.search(QStringLiteral("izmit")), idx.search(QStringLiteral("İZMİT")));
        for (const QVariant &t : idx.search(QString(), 0))
            QCOMPARE(t.toMap()[QStringLiteral("type")].toInt(), 0);
    }

    void distance()
    {
        QCOMPARE(text::formatDistance(850), QStringLiteral("850 m"));
        QCOMPARE(text::formatDistance(1234), QStringLiteral("1,2 km"));
    }

    void warnThenArrive()
    {
        Tracking t = stopTracking();
        Observation o;
        o.approaching = vehicle(5);
        Step s = step(t, o, 10);
        QVERIFY(s.tracking && s.events.isEmpty());
        o.approaching = vehicle(2);
        s = step(*s.tracking, o, 20);
        QCOMPARE(s.events.size(), 1);
        QCOMPARE(s.events[0].kind, Event::Warn);
        s = step(*s.tracking, o, 30); // tek sefer
        QVERIFY(s.events.isEmpty());
        o.approaching = vehicle(0);
        s = step(*s.tracking, o, 40);
        QVERIFY(!s.tracking);
        QCOMPARE(s.events[0].kind, Event::Arrived);
    }

    void passedWhenDroppedNearStop()
    {
        Tracking t = stopTracking();
        t.lastStopsAway = 1;
        t.lastSeenAt = 1;
        Observation o;
        o.onRoute = vehicle(std::nullopt);
        const Step s = step(t, o, 50);
        QVERIFY(!s.tracking);
        QCOMPARE(s.events[0].kind, Event::Passed);
    }

    void lostAfterThreeMisses()
    {
        Tracking t = stopTracking();
        Step s = step(t, Observation(), 1);
        s = step(*s.tracking, Observation(), 2);
        QVERIFY(s.tracking);
        s = step(*s.tracking, Observation(), 3);
        QVERIFY(!s.tracking);
        QCOMPARE(s.events[0].kind, Event::Lost);
        // Ağ hatası tur sayılmaz.
        s = step(t, Observation::unavailable(), 1);
        QCOMPARE(s.tracking->missedPolls, 0);
    }

    void expires()
    {
        const Step s = step(stopTracking(), Observation(), 2'000'000);
        QCOMPARE(s.events[0].kind, Event::Expired);
    }

    void waitLocksOnNearest()
    {
        Tracking t = stopTracking();
        t.waitForRoute = true;
        t.vehicleId.clear();
        t.plate.clear();
        Observation o;
        o.approaching = vehicle(6, QStringLiteral("7"));
        Step s = step(t, o, 10);
        QVERIFY(s.tracking->waitForRoute);
        QCOMPARE(*s.tracking->lastStopsAway, 6);
        o.approaching = vehicle(2, QStringLiteral("7"));
        s = step(*s.tracking, o, 20);
        QVERIFY(!s.tracking->waitForRoute);
        QCOMPARE(s.tracking->vehicleId, QStringLiteral("7"));
        QCOMPARE(s.events[0].kind, Event::Warn);
    }

    void nearPlace()
    {
        Tracking t = stopTracking();
        t.target.kind = Target::NearPlace;
        t.target.location = QGeoCoordinate(40.7654, 29.9408);
        t.target.radiusM = 300;
        Observation o;
        Vehicle v = vehicle(std::nullopt);
        v.location = QGeoCoordinate(40.78, 29.94);
        o.onRoute = v;
        Step s = step(t, o, 10);
        QVERIFY(s.tracking);
        v.location = QGeoCoordinate(40.7660, 29.9408);
        o.onRoute = v;
        s = step(*s.tracking, o, 20);
        QVERIFY(!s.tracking);
        QCOMPARE(s.events[0].kind, Event::Arrived);
    }

    void pollDelay()
    {
        Tracking t = stopTracking();
        QCOMPARE(nextPollDelayMs({t}), MinPollMs);
        t.lastSeenAt = 1;
        t.lastStopsAway = 20;
        t.lastDistanceM = 5000;
        QCOMPARE(nextPollDelayMs({t}), FarPollMs);
    }

    void jsonRoundTrip()
    {
        Tracking t = stopTracking();
        t.target.location = QGeoCoordinate(40.1, 29.2);
        t.lastStopsAway = 3;
        const Tracking back = Tracking::fromJson(t.toJson());
        QCOMPARE(back.plate, t.plate);
        QCOMPARE(*back.warnStops, 2);
        QCOMPARE(*back.lastStopsAway, 3);
        QVERIFY(!back.lastMinutesAway);
        QCOMPARE(back.target.location->latitude(), 40.1);
    }

    void texts()
    {
        Tracking t = stopTracking();
        t.lastStopsAway = 3;
        t.lastMinutesAway = 6;
        QCOMPARE(progressText(t), QStringLiteral("3 durak · ~6 dk"));
        QCOMPARE(title(t), QStringLiteral("200 · 41 KT 001 → OTOGAR"));
    }
};

QTEST_GUILESS_MAIN(LogicTest)
#include "tst_logic.moc"
