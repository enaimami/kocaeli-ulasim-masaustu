#include "Api.h"

#include "KentKart.h"
#include "Text.h"

#include <QDateTime>
#include <QLocale>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>

Api::Api(KentKart *kk, QObject *parent)
    : QObject(parent)
    , m_kk(kk)
{
}

Api *Api::create(QQmlEngine *, QJSEngine *engine)
{
    QJSEngine::setObjectOwnership(instance, QJSEngine::CppOwnership);
    instance->m_engine = engine;
    return instance;
}

void Api::reply(QJSValue cb, const QString &error, const QVariant &value)
{
    if (!cb.isCallable() || !m_engine)
        return;
    const QJSValue result = cb.call({QJSValue(error), m_engine->toScriptValue(value)});
    if (result.isError())
        qWarning("QML geri çağrısı hata verdi: %s", qPrintable(result.toString()));
}

void Api::closestStops(double lat, double lng, const QJSValue &cb)
{
    m_kk->closestStops(lat, lng, [this, cb](const QString &e, const QVariantList &v) { reply(cb, e, v); });
}

void Api::stopArrivals(const QString &stopId, const QJSValue &cb)
{
    m_kk->stopArrivals(stopId, [this, cb](const QString &e, const QVariantMap &v) { reply(cb, e, v); });
}

void Api::searchStops(const QString &keyword, const QJSValue &cb)
{
    m_kk->searchStops(keyword, [this, cb](const QString &e, const QVariantList &v) { reply(cb, e, v); });
}

void Api::routeDetail(const QString &code, int direction, const QJSValue &cb)
{
    m_kk->routeDetail(code, direction, [this, cb](const QString &e, const QVariantMap &v) { reply(cb, e, v); });
}

void Api::routeVehicles(const QString &code, int direction, const QJSValue &cb)
{
    m_kk->routeVehicles(code, direction, [this, cb](const QString &e, const QVariantList &v) { reply(cb, e, v); });
}

void Api::stopsBefore(const QString &code, const QString &stopId, const QJSValue &cb)
{
    m_kk->stopsBefore(code, stopId, [this, cb](int index) {
        if (cb.isCallable())
            QJSValue(cb).call({QJSValue(index)});
    });
}

void Api::loadAnnouncements()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (m_announcementsLoaded || m_announcementsLoading || (m_announcementsFailedAt && now - m_announcementsFailedAt < 60'000))
        return;
    m_announcementsLoading = true;
    m_kk->announcements([this](const QString &e, const QVariantList &list) {
        m_announcementsLoading = false;
        if (!e.isEmpty()) {
            m_announcementsFailedAt = QDateTime::currentMSecsSinceEpoch();
            return;
        }
        const QDateTime now = QDateTime::currentDateTime();
        m_announcements.clear();
        for (const QVariant &a : list) {
            const QVariantMap m = a.toMap();
            const QDateTime from = m.value(QStringLiteral("validFrom")).toDateTime();
            const QDateTime to = m.value(QStringLiteral("validTo")).toDateTime();
            if ((from.isValid() && from > now) || (to.isValid() && to < now))
                continue;
            m_announcements.append(m);
        }
        m_announcementsLoaded = true;
        emit announcementsChanged();
    });
}

/**
 * Duyuruda adı geçen hat kodları. Kocaeli metinleri "76 No.lu hattımızda", "15KS nolu hat",
 * "76 ve 80 No.lu hatlarımızda" kalıplarını kullanıyor; kodlar büyük harfe çevrilir.
 */
static QSet<QString> routeCodes(const QVariantMap &a)
{
    static const QString code = QStringLiteral("\\b\\d{1,3}[A-Za-zÇĞİÖŞÜçğıöşü]{0,3}\\b");
    static const QRegularExpression codeRe(code, QRegularExpression::UseUnicodePropertiesOption);
    static const QRegularExpression mention(
        QStringLiteral("((?:%1\\s*(?:,|ve|ile|-)\\s*)*%1)\\s*(?:No\\.?\\s*'?lu|nolu|numaralı)\\s+hat").arg(code),
        QRegularExpression::CaseInsensitiveOption | QRegularExpression::UseUnicodePropertiesOption);
    static const QLocale turkish(QLocale::Turkish);
    const QString text = a.value(QStringLiteral("title")).toString() + u' ' + a.value(QStringLiteral("description")).toString();
    QSet<QString> out;
    for (auto it = mention.globalMatch(text); it.hasNext();) {
        const QString list = it.next().captured(1);
        for (auto c = codeRe.globalMatch(list); c.hasNext();)
            out.insert(turkish.toUpper(c.next().captured(0)));
    }
    return out;
}

QVariantList Api::announcementsFor(const QString &routeCode) const
{
    const QString code = QLocale(QLocale::Turkish).toUpper(routeCode.trimmed());
    if (code.isEmpty())
        return {};
    QVariantList out;
    for (const QVariant &a : m_announcements)
        if (routeCodes(a.toMap()).contains(code))
            out.append(a);
    return out;
}

int Api::serviceMinuteNow() const
{
    return kk::serviceMinute(QTime::currentTime());
}

QString Api::formatDistance(double meters) const
{
    return text::formatDistance(meters);
}

QString Api::tileCacheDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/tiles");
}
