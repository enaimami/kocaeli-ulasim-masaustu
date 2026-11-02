#include "Notifier.h"

#include <QAudioOutput>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QFile>
#include <QMediaPlayer>
#include <QUrl>

static const QString Service = QStringLiteral("org.freedesktop.Notifications");
static const QString Path = QStringLiteral("/org/freedesktop/Notifications");
static const QString DesktopEntry = QStringLiteral("dev.enaimami.KocaeliUlasim");

Notifier::Notifier(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(Service, Path, Service, QStringLiteral("ActionInvoked"), this, SLOT(onActionInvoked(uint, QString)));
    bus.connect(Service, Path, Service, QStringLiteral("NotificationClosed"), this, SLOT(onClosed(uint, uint)));
}

uint Notifier::send(const QString &title, const QString &body, const QStringList &actions, const QVariantMap &hints, int timeoutMs)
{
    QDBusInterface iface(Service, Path, Service, QDBusConnection::sessionBus());
    QVariantMap h = hints;
    h.insert(QStringLiteral("desktop-entry"), DesktopEntry);
    const QDBusReply<uint> reply = iface.call(QStringLiteral("Notify"), QStringLiteral("Kocaeli Ulaşım"), uint(0),
                                              DesktopEntry, title, body, actions, h, timeoutMs);
    if (!reply.isValid()) {
        qWarning("Bildirim gönderilemedi: %s", qPrintable(reply.error().message()));
        return 0;
    }
    m_ours.insert(reply.value());
    return reply.value();
}

void Notifier::close(uint id)
{
    if (!id)
        return;
    QDBusInterface iface(Service, Path, Service, QDBusConnection::sessionBus());
    iface.call(QDBus::NoBlock, QStringLiteral("CloseNotification"), id);
}

void Notifier::notify(const QString &title, const QString &body, bool important)
{
    QVariantMap hints{{QStringLiteral("urgency"), QVariant::fromValue<uchar>(important ? 1 : 0)}};
    if (important)
        hints.insert(QStringLiteral("sound-name"), QStringLiteral("message-new-instant"));
    else
        hints.insert(QStringLiteral("suppress-sound"), true);
    send(title, body, {QStringLiteral("default"), QStringLiteral("Aç")}, hints, important ? -1 : 8000);
}

void Notifier::startAlarm(const QString &title, const QString &body)
{
    stopAlarm();
    m_alarmTitle = title;
    m_alarmText = body;
    m_alarmId = send(title, body,
                     {QStringLiteral("default"), QStringLiteral("Aç"), QStringLiteral("stop"), QStringLiteral("Durdur")},
                     {{QStringLiteral("urgency"), QVariant::fromValue<uchar>(2)}, // kritik: "Rahatsız etme"yi aşar
                      {QStringLiteral("resident"), true},
                      {QStringLiteral("suppress-sound"), true},
                      {QStringLiteral("category"), QStringLiteral("alarm")}},
                     0);

    if (!m_player) {
        m_player = new QMediaPlayer(this);
        m_audio = new QAudioOutput(this);
        m_player->setAudioOutput(m_audio);
        m_player->setLoops(QMediaPlayer::Infinite);
    }
    for (const char *path : {"/usr/share/sounds/ocean/stereo/alarm-clock-elapsed.oga",
                             "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"}) {
        if (QFile::exists(QLatin1String(path))) {
            m_player->setSource(QUrl::fromLocalFile(QLatin1String(path)));
            m_player->play();
            m_alarmPlaying = true;
            break;
        }
    }
    emit alarmChanged();
}

void Notifier::stopAlarm()
{
    if (!alarmActive())
        return;
    if (m_player)
        m_player->stop();
    m_alarmPlaying = false;
    const uint id = m_alarmId;
    m_alarmId = 0;
    close(id);
    emit alarmChanged();
}

void Notifier::onActionInvoked(uint id, const QString &action)
{
    if (!m_ours.contains(id))
        return;
    if (id == m_alarmId && action == u"stop") {
        stopAlarm();
        return;
    }
    if (action == u"default") {
        if (id == m_alarmId)
            stopAlarm();
        emit openRequested();
    }
}

void Notifier::onClosed(uint id, uint reason)
{
    if (!m_ours.remove(id))
        return;
    // Kullanıcı alarm bildirimini kapattıysa (2) ses de susar.
    if (id == m_alarmId && id != 0 && reason == 2)
        stopAlarm();
}
