#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include "database.h"
#include "scanner.h"
#include "player.h"
#include "mpris.h"

#include <QQuickImageProvider>
#include <QPixmap>

class ThemeIconProvider : public QQuickImageProvider {
public:
    ThemeIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override {
        QIcon icon = QIcon::fromTheme(id);
        QSize actualSize = requestedSize.isValid() ? requestedSize : QSize(64, 64);
        if (size) {
            *size = actualSize;
        }
        return icon.pixmap(actualSize);
    }
};

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    
    app.setApplicationName(QStringLiteral("aether"));
    app.setApplicationDisplayName(QStringLiteral("Aether Player"));
    app.setOrganizationName(QStringLiteral("Aether"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("multimedia-audio-player")));

    // Instantiate Singletons/Models
    Database db;
    LibraryScanner scanner;
    Player player;
    MprisService mpris(&player);

    // Register MPRIS Service
    mpris.registerService();

    // Start QML Engine
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("theme"), new ThemeIconProvider());

    // Inject C++ models into QML context
    engine.rootContext()->setContextProperty(QStringLiteral("database"), &db);
    engine.rootContext()->setContextProperty(QStringLiteral("scanner"), &scanner);
    engine.rootContext()->setContextProperty(QStringLiteral("player"), &player);

    // Load QML main window
    engine.loadFromModule(QStringLiteral("Aether"), QStringLiteral("Main"));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "QML Engine failed to load main module. Exiting.";
        return -1;
    }

    return app.exec();
}
