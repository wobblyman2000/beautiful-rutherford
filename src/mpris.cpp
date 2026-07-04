#include "mpris.h"
#include <QCoreApplication>

// -------------------------------------------------------------
// MprisRootAdaptor Implementation
// -------------------------------------------------------------
MprisRootAdaptor::MprisRootAdaptor(QObject *parent)
    : QDBusAbstractAdaptor(parent) {}

bool MprisRootAdaptor::CanQuit() const { return true; }
bool MprisRootAdaptor::Fullscreen() const { return false; }
void MprisRootAdaptor::setFullscreen(bool fs) { Q_UNUSED(fs); }
bool MprisRootAdaptor::CanSetFullscreen() const { return false; }
bool MprisRootAdaptor::CanRaise() const { return false; }
bool MprisRootAdaptor::HasTrackList() const { return false; }
QString MprisRootAdaptor::Identity() const { return QStringLiteral("Aether Player"); }
QString MprisRootAdaptor::DesktopEntry() const { return QStringLiteral("aether"); }
QStringList MprisRootAdaptor::SupportedUriSchemes() const { return QStringList() << QStringLiteral("file"); }
QStringList MprisRootAdaptor::SupportedMimeTypes() const {
    return QStringList() << QStringLiteral("audio/mpeg") << QStringLiteral("audio/flac")
                         << QStringLiteral("audio/ogg") << QStringLiteral("audio/mp4")
                         << QStringLiteral("audio/wav");
}

void MprisRootAdaptor::Raise() {
    qDebug() << "MPRIS: Raise called";
}

void MprisRootAdaptor::Quit() {
    qDebug() << "MPRIS: Quit called";
    qApp->quit();
}


// -------------------------------------------------------------
// MprisPlayerAdaptor Implementation
// -------------------------------------------------------------
MprisPlayerAdaptor::MprisPlayerAdaptor(Player *player, QObject *parent)
    : QDBusAbstractAdaptor(parent), m_player(player) {
    
    connect(m_player, &Player::currentTrackChanged, this, &MprisPlayerAdaptor::onPlayerChanged);
    connect(m_player, &Player::playbackStatusChanged, this, &MprisPlayerAdaptor::onPlayerChanged);
    connect(m_player, &Player::volumeChanged, this, &MprisPlayerAdaptor::onPlayerChanged);
    connect(m_player, &Player::shuffleChanged, this, &MprisPlayerAdaptor::onPlayerChanged);
    connect(m_player, &Player::loopStatusChanged, this, &MprisPlayerAdaptor::onPlayerChanged);
    connect(m_player, &Player::seeked, this, &MprisPlayerAdaptor::onPlayerSeeked);
}

QString MprisPlayerAdaptor::PlaybackStatus() const {
    return m_player->playbackStatus();
}

QString MprisPlayerAdaptor::LoopStatus() const {
    QString status = m_player->loopStatus();
    if (status == QLatin1String("Track")) return QStringLiteral("Track");
    if (status == QLatin1String("Playlist")) return QStringLiteral("Playlist");
    return QStringLiteral("None");
}

void MprisPlayerAdaptor::setLoopStatus(const QString &status) {
    if (status == QLatin1String("Track") || status == QLatin1String("Playlist") || status == QLatin1String("None")) {
        m_player->setLoopStatus(status);
    }
}

double MprisPlayerAdaptor::Rate() const { return 1.0; }
void MprisPlayerAdaptor::setRate(double rate) { Q_UNUSED(rate); }

bool MprisPlayerAdaptor::Shuffle() const { return m_player->shuffle(); }
void MprisPlayerAdaptor::setShuffle(bool shuffle) { m_player->setShuffle(shuffle); }

QVariantMap MprisPlayerAdaptor::Metadata() const {
    QVariantMap mprisMetadata;
    QVariantMap track = m_player->currentTrack();
    if (track.isEmpty()) {
        return mprisMetadata;
    }

    // MPRIS key spec:
    mprisMetadata[QStringLiteral("mpris:trackid")] = QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/mpris/MediaPlayer2/Track/%1").arg(track["id"].toString())));
    
    double durationSec = track["duration"].toDouble();
    if (durationSec > 0.0) {
        qlonglong lengthUs = static_cast<qlonglong>(durationSec * 1000000.0);
        mprisMetadata[QStringLiteral("mpris:length")] = QVariant::fromValue(lengthUs);
    }

    mprisMetadata[QStringLiteral("xesam:title")] = track["title"].toString();
    mprisMetadata[QStringLiteral("xesam:artist")] = QStringList() << track["artist"].toString();
    mprisMetadata[QStringLiteral("xesam:album")] = track["album"].toString();
    mprisMetadata[QStringLiteral("xesam:genre")] = QStringList() << track["genre"].toString();

    QString cover = track["coverPath"].toString();
    if (!cover.isEmpty()) {
        mprisMetadata[QStringLiteral("mpris:artUrl")] = cover;
    }

    return mprisMetadata;
}

double MprisPlayerAdaptor::Volume() const {
    return m_player->volume();
}

void MprisPlayerAdaptor::setVolume(double volume) {
    m_player->setVolume(volume);
}

qlonglong MprisPlayerAdaptor::Position() const {
    return static_cast<qlonglong>(m_player->position() * 1000000.0);
}

double MprisPlayerAdaptor::MinimumRate() const { return 1.0; }
double MprisPlayerAdaptor::MaximumRate() const { return 1.0; }
bool MprisPlayerAdaptor::CanGoNext() const { return true; }
bool MprisPlayerAdaptor::CanGoPrevious() const { return true; }
bool MprisPlayerAdaptor::CanPlay() const { return true; }
bool MprisPlayerAdaptor::CanPause() const { return true; }
bool MprisPlayerAdaptor::CanSeek() const { return true; }
bool MprisPlayerAdaptor::CanControl() const { return true; }

void MprisPlayerAdaptor::Next() { m_player->next(); }
void MprisPlayerAdaptor::Previous() { m_player->previous(); }
void MprisPlayerAdaptor::Pause() { m_player->pause(); }
void MprisPlayerAdaptor::PlayPause() { m_player->togglePlay(); }
void MprisPlayerAdaptor::Stop() { m_player->stop(); }
void MprisPlayerAdaptor::Play() { m_player->play(); }

void MprisPlayerAdaptor::Seek(qlonglong Offset) {
    double offsetSeconds = Offset / 1000000.0;
    m_player->setPosition(m_player->position() + offsetSeconds);
}

void MprisPlayerAdaptor::SetPosition(const QDBusObjectPath &TrackId, qlonglong Position) {
    Q_UNUSED(TrackId);
    double positionSeconds = Position / 1000000.0;
    m_player->setPosition(positionSeconds);
}

void MprisPlayerAdaptor::OpenUri(const QString &Uri) {
    Q_UNUSED(Uri);
}

void MprisPlayerAdaptor::onPlayerSeeked(double positionSeconds) {
    qlonglong us = static_cast<qlonglong>(positionSeconds * 1000000.0);
    emit Seeked(us);
}

void MprisPlayerAdaptor::onPlayerChanged() {
    // Construct D-Bus PropertiesChanged notification
    QVariantMap properties;
    properties[QStringLiteral("PlaybackStatus")] = PlaybackStatus();
    properties[QStringLiteral("Metadata")] = Metadata();
    properties[QStringLiteral("Volume")] = Volume();
    properties[QStringLiteral("Shuffle")] = Shuffle();
    properties[QStringLiteral("LoopStatus")] = LoopStatus();

    QDBusMessage msg = QDBusMessage::createSignal(
        QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged")
    );
    msg << QStringLiteral("org.mpris.MediaPlayer2.Player");
    msg << properties;
    msg << QStringList(); // Invalidated properties

    QDBusConnection::sessionBus().send(msg);
}


// -------------------------------------------------------------
// MprisService Implementation
// -------------------------------------------------------------
MprisService::MprisService(Player *player, QObject *parent)
    : QObject(parent), m_player(player) {
    
    m_rootAdaptor = new MprisRootAdaptor(this);
    m_playerAdaptor = new MprisPlayerAdaptor(player, this);
}

void MprisService::registerService() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    
    if (!bus.isConnected()) {
        qWarning() << "MPRIS: D-Bus Session Bus is not connected. Media widget integration disabled.";
        return;
    }

    const QString objectPath = QStringLiteral("/org/mpris/MediaPlayer2");
    
    if (!bus.registerObject(objectPath, this)) {
        qWarning() << "MPRIS: Failed to register object at /org/mpris/MediaPlayer2";
        return;
    }

    const QString serviceName = QStringLiteral("org.mpris.MediaPlayer2.aether");
    if (!bus.registerService(serviceName)) {
        qWarning() << "MPRIS: Failed to request service name" << serviceName << ". Another player instance might be running.";
        return;
    }

    qDebug() << "MPRIS: Successfully registered service on Session Bus as" << serviceName;
}
