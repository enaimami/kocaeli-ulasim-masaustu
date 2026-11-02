#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QSet>

class QAudioOutput;
class QMediaPlayer;

/**
 * Masaüstü bildirimleri (org.freedesktop.Notifications; Plasma'nın kendi bildirim balonu)
 * ve alarm: kritik, kendiliğinden kapanmayan bildirim + kullanıcı durdurana kadar çalan ses.
 */
class Notifier : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool alarmActive READ alarmActive NOTIFY alarmChanged)
    Q_PROPERTY(QString alarmTitle READ alarmTitle NOTIFY alarmChanged)
    Q_PROPERTY(QString alarmText READ alarmText NOTIFY alarmChanged)

public:
    explicit Notifier(QObject *parent = nullptr);
    static Notifier *create(QQmlEngine *, QJSEngine *)
    {
        QJSEngine::setObjectOwnership(instance, QJSEngine::CppOwnership);
        return instance;
    }
    static inline Notifier *instance = nullptr;

    /** [important] = sesli; değilse sessiz bilgi bildirimi. */
    void notify(const QString &title, const QString &body, bool important);
    void startAlarm(const QString &title, const QString &body);
    Q_INVOKABLE void stopAlarm();

    bool alarmActive() const { return m_alarmId != 0 || m_alarmPlaying; }
    QString alarmTitle() const { return m_alarmTitle; }
    QString alarmText() const { return m_alarmText; }

signals:
    void alarmChanged();
    /** Bildirimdeki "Aç" eylemi ya da bildirime tıklama. */
    void openRequested();

private slots:
    void onActionInvoked(uint id, const QString &action);
    void onClosed(uint id, uint reason);

private:
    uint send(const QString &title, const QString &body, const QStringList &actions, const QVariantMap &hints, int timeoutMs);
    void close(uint id);

    QMediaPlayer *m_player = nullptr;
    QAudioOutput *m_audio = nullptr;
    QSet<uint> m_ours; // ActionInvoked tüm uygulamalar için gelir; yalnızca bizimkiler
    uint m_alarmId = 0;
    bool m_alarmPlaying = false;
    QString m_alarmTitle, m_alarmText;
};
