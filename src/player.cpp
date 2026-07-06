#include "player.h"
#include "database.h"

Player* Player::m_instance = nullptr;

Player::Player(QObject *parent) : QObject(parent) {
    m_instance = this;

    m_mediaPlayer = new QMediaPlayer(this);
    m_audioOutput = new QAudioOutput(this);
    m_mediaPlayer->setAudioOutput(m_audioOutput);

    m_audioOutput->setVolume(0.8); // Default volume

    connect(m_mediaPlayer, &QMediaPlayer::positionChanged, this, &Player::onPositionChanged);
    connect(m_mediaPlayer, &QMediaPlayer::durationChanged, this, &Player::onDurationChanged);
    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged, this, &Player::onPlaybackStateChanged);
    connect(m_mediaPlayer, &QMediaPlayer::mediaStatusChanged, this, &Player::onMediaStatusChanged);
}

Player* Player::instance() {
    return m_instance;
}

QVariantMap Player::currentTrack() const {
    if (m_queueIndex >= 0 && m_queueIndex < m_queue.size()) {
        return m_queue[m_queueIndex].toMap();
    }
    return QVariantMap();
}

QString Player::playbackStatus() const {
    switch (m_mediaPlayer->playbackState()) {
        case QMediaPlayer::PlayingState:
            return QStringLiteral("Playing");
        case QMediaPlayer::PausedState:
            return QStringLiteral("Paused");
        case QMediaPlayer::StoppedState:
        default:
            return QStringLiteral("Stopped");
    }
}

int Player::queueIndex() const {
    return m_queueIndex;
}

double Player::volume() const {
    return m_audioOutput->volume();
}

void Player::setVolume(double volume) {
    double vol = qMax(0.0, qMin(1.0, volume));
    if (qFuzzyCompare(static_cast<float>(m_audioOutput->volume()), static_cast<float>(vol))) return;
    
    m_audioOutput->setVolume(vol);
    emit volumeChanged();
}

double Player::position() const {
    return m_mediaPlayer->position() / 1000.0;
}

void Player::setPosition(double positionSeconds) {
    qint64 ms = static_cast<qint64>(positionSeconds * 1000.0);
    if (m_mediaPlayer->position() == ms) return;
    
    m_mediaPlayer->setPosition(ms);
    emit positionChanged();
    emit seeked(positionSeconds);
}

double Player::duration() const {
    return m_mediaPlayer->duration() / 1000.0;
}

bool Player::shuffle() const {
    return m_shuffle;
}

void Player::setShuffle(bool enabled) {
    if (m_shuffle == enabled) return;
    m_shuffle = enabled;
    emit shuffleChanged();

    if (m_queue.isEmpty()) return;

    QVariantMap current = currentTrack();

    if (m_shuffle) {
        // Shuffle queue keeping current track at index 0
        QVariantList remaining = m_queue;
        if (!current.isEmpty()) {
            remaining.removeAt(m_queueIndex);
        }

        // Shuffle remaining
        for (int i = remaining.size() - 1; i > 0; --i) {
            int j = QRandomGenerator::global()->bounded(i + 1);
            remaining.swapItemsAt(i, j);
        }

        m_queue.clear();
        if (!current.isEmpty()) {
            m_queue.append(current);
            m_queueIndex = 0;
        } else {
            m_queueIndex = -1;
        }
        m_queue.append(remaining);
    } else {
        // Restore original queue order, finding the current track's new index
        m_queue = m_originalQueue;
        if (!current.isEmpty()) {
            for (int i = 0; i < m_queue.size(); ++i) {
                if (m_queue[i].toMap()["id"].toString() == current["id"].toString()) {
                    m_queueIndex = i;
                    break;
                }
            }
        }
    }
    
    emit queueChanged();
    emit queueIndexChanged();
}

QString Player::loopStatus() const {
    return m_loopStatus;
}

void Player::setLoopStatus(const QString &status) {
    if (m_loopStatus != status) {
        m_loopStatus = status;
        emit loopStatusChanged();
    }
}

QVariantList Player::queue() const {
    return m_queue;
}

void Player::play() {
    if (m_mediaPlayer->source().isEmpty() && !m_queue.isEmpty()) {
        playTrack(0);
    } else {
        m_mediaPlayer->play();
    }
}

void Player::pause() {
    m_mediaPlayer->pause();
}

void Player::stop() {
    m_mediaPlayer->stop();
    m_mediaPlayer->setPosition(0);
}

void Player::togglePlay() {
    if (m_mediaPlayer->playbackState() == QMediaPlayer::PlayingState) {
        pause();
    } else {
        play();
    }
}

void Player::next() {
    if (m_queue.isEmpty()) return;
    if (m_queueIndex < m_queue.size() - 1) {
        playTrack(m_queueIndex + 1);
    } else if (m_loopStatus == QLatin1String("Playlist")) {
        playTrack(0);
    }
}

void Player::previous() {
    if (m_queue.isEmpty()) return;
    // If track is > 3s in, restart it
    if (position() > 3.0) {
        setPosition(0);
    } else if (m_queueIndex > 0) {
        playTrack(m_queueIndex - 1);
    } else if (m_loopStatus == QLatin1String("Playlist")) {
        playTrack(m_queue.size() - 1);
    }
}

void Player::setQueue(const QVariantList &tracks, int startIndex) {
    m_originalQueue = tracks;
    m_queue = tracks;
    
    emit queueChanged();

    int playIndex = startIndex;
    if (m_shuffle) {
        // Shuffle queue putting target startIndex track first
        QVariantMap targetTrack;
        if (startIndex >= 0 && startIndex < tracks.size()) {
            targetTrack = tracks[startIndex].toMap();
        }
        
        QVariantList remaining = tracks;
        if (!targetTrack.isEmpty()) {
            remaining.removeAt(startIndex);
        }

        for (int i = remaining.size() - 1; i > 0; --i) {
            int j = QRandomGenerator::global()->bounded(i + 1);
            remaining.swapItemsAt(i, j);
        }

        m_queue.clear();
        if (!targetTrack.isEmpty()) {
            m_queue.append(targetTrack);
            playIndex = 0;
        } else {
            playIndex = -1;
        }
        m_queue.append(remaining);
        emit queueChanged();
    }

    if (playIndex >= 0 && playIndex < m_queue.size()) {
        playTrack(playIndex);
    }
}

void Player::playTrack(int index) {
    if (index < 0 || index >= m_queue.size()) return;

    m_queueIndex = index;
    emit queueIndexChanged();
    emit currentTrackChanged();

    QString path = m_queue[m_queueIndex].toMap()["filePath"].toString();
    m_mediaPlayer->setSource(QUrl::fromLocalFile(path));
    m_mediaPlayer->play();
}

void Player::handleTrackEnded() {
    if (m_loopStatus == QLatin1String("Track")) {
        m_mediaPlayer->setPosition(0);
        m_mediaPlayer->play();
    } else {
        if (m_autoDJ && m_queueIndex >= m_queue.size() - 1) {
            QVariantList allTracks = Database::instance()->tracksVariant();
            if (!allTracks.isEmpty()) {
                int randIdx = QRandomGenerator::global()->bounded(allTracks.size());
                m_queue.append(allTracks[randIdx]);
                emit queueChanged();
            }
        }

        if (m_queueIndex < m_queue.size() - 1) {
            playTrack(m_queueIndex + 1);
        } else if (m_loopStatus == QLatin1String("Playlist")) {
            playTrack(0);
        } else {
            stop();
        }
    }
}

bool Player::autoDJ() const {
    return m_autoDJ;
}

void Player::setAutoDJ(bool enabled) {
    if (m_autoDJ == enabled) return;
    m_autoDJ = enabled;
    emit autoDJChanged();
}

void Player::onPositionChanged(qint64 ms) {
    Q_UNUSED(ms);
    emit positionChanged();
}

void Player::onDurationChanged(qint64 ms) {
    Q_UNUSED(ms);
    emit durationChanged();
}

void Player::onPlaybackStateChanged(QMediaPlayer::PlaybackState state) {
    Q_UNUSED(state);
    emit playbackStatusChanged();
}

void Player::onMediaStatusChanged(QMediaPlayer::MediaStatus status) {
    if (status == QMediaPlayer::EndOfMedia) {
        handleTrackEnded();
    }
}
