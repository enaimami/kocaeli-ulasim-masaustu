#pragma once

#include <QJsonObject>
#include <QObject>
#include <QQmlEngine>
#include <QVariantList>

/**
 * Kullanıcının kalıcı verisi: favori duraklar ve hatlar, son aramalar ve ayarlar.
 * Tek JSON dosyası (~/.local/share/kocaeli-ulasim/store.json), her değişiklikte atomik yazılır.
 */
class Store : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList favoriteStops READ favoriteStops NOTIFY favoritesChanged)
    Q_PROPERTY(QVariantList favoriteRoutes READ favoriteRoutes NOTIFY favoritesChanged)
    Q_PROPERTY(QStringList recentSearches READ recentSearches NOTIFY recentSearchesChanged)
    Q_PROPERTY(bool showAnnouncements READ showAnnouncements WRITE setShowAnnouncements NOTIFY settingsChanged)
    /** 0 = sistem, 1 = açık, 2 = koyu (harita karoları için). */
    Q_PROPERTY(int mapTheme READ mapTheme WRITE setMapTheme NOTIFY settingsChanged)
    /** Takip penceresinin son seçimi: kaç durak kala haber (0 = kapalı) ve alarm mı. */
    Q_PROPERTY(int trackWarnStops READ trackWarnStops WRITE setTrackWarnStops NOTIFY settingsChanged)
    Q_PROPERTY(bool trackAlarm READ trackAlarm WRITE setTrackAlarm NOTIFY settingsChanged)
    /** Konum servisi yoksa kullanılan son bilinen / elle seçilen konum. */
    Q_PROPERTY(double homeLat READ homeLat NOTIFY settingsChanged)
    Q_PROPERTY(double homeLng READ homeLng NOTIFY settingsChanged)
    Q_PROPERTY(bool hasHome READ hasHome NOTIFY settingsChanged)
    /** Konum kullanıcı tarafından haritadan seçildi (konum servisi bunu ezmez). */
    Q_PROPERTY(bool homeManual READ homeManual NOTIFY settingsChanged)

public:
    static constexpr int MaxRecent = 8;

    explicit Store(QObject *parent = nullptr);
    static Store *create(QQmlEngine *, QJSEngine *);
    static inline Store *instance = nullptr;

    Q_INVOKABLE bool isFavoriteStop(const QString &id) const;
    Q_INVOKABLE void toggleFavoriteStop(const QString &id, const QString &name);
    Q_INVOKABLE void removeFavoriteStop(const QString &id);
    /** Geri al için: kaldırılan favoriyi eski yerine koyar. */
    Q_INVOKABLE void restoreFavoriteStop(const QVariantMap &stop, int index);
    Q_INVOKABLE void moveFavoriteStop(int from, int to);

    Q_INVOKABLE bool isFavoriteRoute(const QString &code) const;
    Q_INVOKABLE void toggleFavoriteRoute(const QString &code, const QString &name, const QString &color, const QString &textColor);

    Q_INVOKABLE void addRecentSearch(const QString &query);
    Q_INVOKABLE void clearRecentSearches();

    /** [manual] = kullanıcı haritadan seçti; otomatik konum elle seçileni ezmez. */
    Q_INVOKABLE void setHome(double lat, double lng, bool manual = false);
    Q_INVOKABLE void clearManualHome();

    QVariantList favoriteStops() const;
    QVariantList favoriteRoutes() const;
    QStringList recentSearches() const;
    bool showAnnouncements() const { return m_data.value(u"showAnnouncements").toBool(false); }
    void setShowAnnouncements(bool v) { set(QStringLiteral("showAnnouncements"), v); }
    int mapTheme() const { return m_data.value(u"mapTheme").toInt(0); }
    void setMapTheme(int v) { set(QStringLiteral("mapTheme"), v); }
    int trackWarnStops() const { return m_data.value(u"trackWarnStops").toInt(2); }
    void setTrackWarnStops(int v) { set(QStringLiteral("trackWarnStops"), v); }
    bool trackAlarm() const { return m_data.value(u"trackAlarm").toBool(false); }
    void setTrackAlarm(bool v) { set(QStringLiteral("trackAlarm"), v); }
    double homeLat() const { return m_data.value(u"homeLat").toDouble(40.7654); }
    double homeLng() const { return m_data.value(u"homeLng").toDouble(29.9408); }
    bool hasHome() const { return m_data.contains(u"homeLat"); }
    bool homeManual() const { return m_data.value(u"homeManual").toBool(false); }

signals:
    void favoritesChanged();
    void recentSearchesChanged();
    void settingsChanged();

private:
    void set(const QString &key, const QJsonValue &value);
    void save();
    QJsonArray array(const char *key) const;

    QString m_file;
    QJsonObject m_data;
};
