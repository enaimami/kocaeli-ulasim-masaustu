#include "Api.h"
#include "KentKart.h"
#include "Notifier.h"
#include "RouteCatalog.h"
#include "Store.h"
#include "Tracker.h"

#include <KDBusService>
#include <KStatusNotifierItem>
#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QFontDatabase>
#include <QFile>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLibraryInfo>
#include <QLocale>
#include <QMenu>
#include <QQmlApplicationEngine>
#include <QQmlExpression>
#include <QQmlContext>
#include <QTimer>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTranslator>
#include <QUrl>

/**
 * QtLocation'ın osm eklentisi karo sağlayıcılarını bir "depo"dan okur. OpenStreetMap'in standart
 * karoları kullanılır (kişisel, düşük hacimli kullanım; uygulamayı tanıtan User-Agent ve disk
 * önbelleği OSM karo politikası gereği). Koyu tema karoları QML'de gölgelendiriciyle karartılır.
 */
static QString writeTileProviders()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/tile-providers/");
    QDir().mkpath(dir);
    const QJsonObject street{
        {QStringLiteral("UrlTemplate"), QStringLiteral("https://tile.openstreetmap.org/%z/%x/%y.png")},
        {QStringLiteral("ImageFormat"), QStringLiteral("png")},
        {QStringLiteral("QImageFormat"), QStringLiteral("Indexed8")},
        {QStringLiteral("ID"), QStringLiteral("osm-standard")},
        {QStringLiteral("MaximumZoomLevel"), 19},
        {QStringLiteral("MapCopyRight"), QStringLiteral("<a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a>")},
        {QStringLiteral("DataCopyRight"), QStringLiteral("<a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> katkıcıları")},
    };
    QSaveFile f(dir + QStringLiteral("street"));
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(street).toJson());
        f.commit();
    }
    QFile::remove(dir + QStringLiteral("street-hires"));
    QFile::remove(dir + QStringLiteral("night-transit"));
    QFile::remove(dir + QStringLiteral("night-transit-hires"));
    return QUrl::fromLocalFile(dir).toString();
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("kocaeli-ulasim"));
    QApplication::setApplicationDisplayName(QStringLiteral("Kocaeli Ulaşım"));
    QApplication::setApplicationVersion(QStringLiteral(PROJECT_VERSION));
    QApplication::setOrganizationDomain(QStringLiteral("enaimami.dev"));
    QApplication::setDesktopFileName(QStringLiteral("dev.enaimami.KocaeliUlasim"));
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("dev.enaimami.KocaeliUlasim"),
                                                 QIcon(QStringLiteral(":/qt/qml/KocaeliUlasim/data/dev.enaimami.KocaeliUlasim.svg"))));
    // Arayüz yazı tipi (Inter, optik boyutlu) ve simgeler (Material Symbols Rounded) gömülü.
    for (const char *font : {":/qt/qml/KocaeliUlasim/data/fonts/InterVariable.ttf", ":/qt/qml/KocaeliUlasim/data/fonts/symbols.ttf"})
        if (QFontDatabase::addApplicationFont(QLatin1String(font)) < 0)
            qWarning("Yazı tipi yüklenemedi: %s", font);

    // Qt'nin kendi düğme metinleri ("İptal" vb.) Türkçe olsun.
    QTranslator qtTranslator;
    if (qtTranslator.load(QLocale::system(), QStringLiteral("qtbase"), QStringLiteral("_"),
                          QLibraryInfo::path(QLibraryInfo::TranslationsPath)))
        QCoreApplication::installTranslator(&qtTranslator);
    // Takip sürerken pencere kapanınca uygulama tepside çalışmaya devam eder.
    QApplication::setQuitOnLastWindowClosed(false);
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Kocaeli toplu taşıma: duraklar, canlı araçlar, hat saatleri, varış takibi"));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption stopOpt(QStringLiteral("durak"), QStringLiteral("Bu kimlikli durağı aç."), QStringLiteral("kimlik"));
    const QCommandLineOption routeOpt(QStringLiteral("hat"), QStringLiteral("Bu hattı aç (ör. 200)."), QStringLiteral("kod"));
    const QCommandLineOption pageOpt(QStringLiteral("sayfa"), QStringLiteral("Açılış bölümü: ana, harita, takipler, ayarlar."),
                                     QStringLiteral("ad"));
    parser.addOptions({stopOpt, routeOpt, pageOpt});
    parser.process(app);

    // İkinci kez açılırsa mevcut pencere öne gelir (argümanlarıyla).
    KDBusService service(KDBusService::Unique);

    KentKart kk;
    Notifier notifier;
    Notifier::instance = &notifier;
    Api api(&kk);
    Api::instance = &api;
    Api::tileProviders = writeTileProviders();
    RouteCatalog catalog(&kk);
    RouteCatalog::instance = &catalog;
    Store store;
    Store::instance = &store;
    Tracker tracker(&kk, &notifier);
    Tracker::instance = &tracker;

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);
    engine.loadFromModule("KocaeliUlasim", "Main");
    auto *window = engine.rootObjects().isEmpty() ? nullptr : qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!window)
        return 1;

    auto showWindow = [window] {
        window->show();
        window->raise();
        window->requestActivate();
    };
    // Komut satırı: bölüm, durak ya da hat açar.
    auto handleArgs = [&, window](const QStringList &args) {
        QCommandLineParser p;
        p.addOptions({stopOpt, routeOpt, pageOpt});
        p.parse(args);
        static const QHash<QString, QString> sections{{QStringLiteral("ana"), QStringLiteral("home")},
                                                      {QStringLiteral("harita"), QStringLiteral("map")},
                                                      {QStringLiteral("takipler"), QStringLiteral("trackings")},
                                                      {QStringLiteral("ayarlar"), QStringLiteral("settings")}};
        if (p.isSet(pageOpt) && sections.contains(p.value(pageOpt)))
            QMetaObject::invokeMethod(window, "showSection", Q_ARG(QVariant, sections.value(p.value(pageOpt))));
        if (p.isSet(stopOpt)) {
            const QVariantMap stop{{QStringLiteral("id"), p.value(stopOpt)}};
            QMetaObject::invokeMethod(window, "openStop", Q_ARG(QVariant, stop));
        }
        if (p.isSet(routeOpt))
            QMetaObject::invokeMethod(window, "openRoute", Q_ARG(QVariant, p.value(routeOpt)), Q_ARG(QVariant, 0));
    };
    handleArgs(QCoreApplication::arguments());
    QObject::connect(&service, &KDBusService::activateRequested, window,
                     [=](const QStringList &args, const QString &) {
                         showWindow();
                         handleArgs(args);
                     });
    QObject::connect(&notifier, &Notifier::openRequested, window, showWindow);

    // Tepsi simgesi: takip varken etkin; pencere kapalıyken uygulamaya dönüş yolu.
    KStatusNotifierItem tray(QStringLiteral("kocaeli-ulasim"));
    tray.setTitle(QStringLiteral("Kocaeli Ulaşım"));
    tray.setIconByName(QStringLiteral("dev.enaimami.KocaeliUlasim"));
    tray.setCategory(KStatusNotifierItem::ApplicationStatus);
    tray.setAssociatedWindow(window);
    auto *menu = new QMenu;
    menu->addAction(QIcon::fromTheme(QStringLiteral("window")), QStringLiteral("Pencereyi göster"), window, showWindow);
    QAction *stopAll = menu->addAction(QIcon::fromTheme(QStringLiteral("media-playback-stop")),
                                       QStringLiteral("Tüm takipleri durdur"), &tracker, &Tracker::stopAll);
    tray.setContextMenu(menu);

    auto updateTray = [&] {
        const int n = tracker.count();
        tray.setStatus(n > 0 || !window->isVisible() ? KStatusNotifierItem::Active : KStatusNotifierItem::Passive);
        stopAll->setEnabled(n > 0);
        QStringList lines;
        for (const QVariant &t : tracker.trackings())
            lines << t.toMap().value(QStringLiteral("title")).toString() + QStringLiteral(" — ")
                    + t.toMap().value(QStringLiteral("progress")).toString();
        tray.setToolTip(QStringLiteral("dev.enaimami.KocaeliUlasim"), QStringLiteral("Kocaeli Ulaşım"),
                        n > 0 ? lines.join(u'\n') : QStringLiteral("Etkin takip yok"));
        // Pencere kapalı ve izlenecek bir şey kalmadıysa uygulama kapanır.
        if (n == 0 && !window->isVisible() && !notifier.alarmActive())
            QCoreApplication::quit();
    };
    // Bağlam nesnesi tepsi: kapanışta tepsi silinince bağlantılar da kopar (pencere sonra yok edilir).
    QObject::connect(&tracker, &Tracker::trackingsChanged, &tray, updateTray);
    QObject::connect(&notifier, &Notifier::alarmChanged, &tray, updateTray);
    QObject::connect(window, &QWindow::visibleChanged, &tray, updateTray);

    // Geliştirme kancası (yalnızca ortam değişkeniyle): KU_EVAL'deki QML ifadelerini ';;' ile ayrılmış
    // adımlar olarak sırayla çalıştırır, sonra pencereyi KU_SNAP dosyasına kaydedip çıkar. Ekranda
    // pencere açmadan test için QT_QPA_PLATFORM=offscreen ile kullanılır.
    if (qEnvironmentVariableIsSet("KU_SNAP")) {
        const QStringList steps = qEnvironmentVariable("KU_EVAL").split(QStringLiteral(";;"), Qt::SkipEmptyParts);
        const int delay = qEnvironmentVariableIntValue("KU_SNAP_DELAY") > 0 ? qEnvironmentVariableIntValue("KU_SNAP_DELAY") : 6000;
        for (int i = 0; i < steps.size(); ++i)
            QTimer::singleShot(delay * (i + 1) / (steps.size() + 1), window, [&engine, window, step = steps[i]] {
                QQmlExpression expr(engine.rootContext(), window, step);
                expr.evaluate();
                if (expr.hasError())
                    qWarning("KU_EVAL: %s", qPrintable(expr.error().toString()));
            });
        QTimer::singleShot(delay, window, [window] {
            window->grabWindow().save(qEnvironmentVariable("KU_SNAP"));
            QCoreApplication::quit();
        });
    }

    catalog.start();
    tracker.start();
    updateTray();
    return app.exec();
}
