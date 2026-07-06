#include "player.h"
#include "database.h"

Player* Player::m_instance = nullptr;

Player::Player(QObject *parent) : QObject(parent) {
    m_instance = this;

    m_mediaPlayer = new QMediaPlayer(this);
    m_audioOutput = new QAudioOutput(this);
    m_mediaPlayer->setAudioOutput(m_audioOutput);

    m_audioOutput->setVolume(0.8); // Default volume

    m_autoDJGenre = QString();
    m_autoDJArtist = QString();
    m_autoDJAlbumArtist = QString();

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
    } else if (m_autoDJ) {
        // HUMAN-READABLE COMMENT:
        // If the user manually skips to the next track while at the end of the queue
        // and Auto-DJ is enabled, automatically query matching tracks, append one, and play it.
        QVariantList matchingTracks = getAutoDJMatchingTracks();
        if (!matchingTracks.isEmpty()) {
            int randIdx = QRandomGenerator::global()->bounded(matchingTracks.size());
            m_queue.append(matchingTracks[randIdx]);
            emit queueChanged();
            playTrack(m_queueIndex + 1);
        }
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
            // HUMAN-READABLE COMMENT:
            // Fetch next track that matches the currently configured Auto-DJ filters.
            QVariantList matchingTracks = getAutoDJMatchingTracks();
            if (!matchingTracks.isEmpty()) {
                int randIdx = QRandomGenerator::global()->bounded(matchingTracks.size());
                m_queue.append(matchingTracks[randIdx]);
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

    // HUMAN-READABLE COMMENT:
    // When the Auto-DJ feature is toggled on, check if the play queue is currently empty
    // or if the player is currently in a stopped state. If so, automatically query the
    // database for tracks matching the configured filters, select a random track, populate
    // the playback queue, and start playing immediately.
    if (m_autoDJ && (m_queue.isEmpty() || m_mediaPlayer->playbackState() == QMediaPlayer::StoppedState)) {
        QVariantList matchingTracks = getAutoDJMatchingTracks();
        if (!matchingTracks.isEmpty()) {
            int randIdx = QRandomGenerator::global()->bounded(matchingTracks.size());
            setQueue(QVariantList() << matchingTracks[randIdx], 0);
        }
    }
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

QString Player::autoDJGenre() const {
    return m_autoDJGenre;
}

void Player::setAutoDJGenre(const QString &genre) {
    if (m_autoDJGenre == genre) return;
    m_autoDJGenre = genre;
    emit autoDJGenreChanged();
}

QString Player::autoDJArtist() const {
    return m_autoDJArtist;
}

void Player::setAutoDJArtist(const QString &artist) {
    if (m_autoDJArtist == artist) return;
    m_autoDJArtist = artist;
    emit autoDJArtistChanged();
}

QString Player::autoDJAlbumArtist() const {
    return m_autoDJAlbumArtist;
}

void Player::setAutoDJAlbumArtist(const QString &albumArtist) {
    if (m_autoDJAlbumArtist == albumArtist) return;
    m_autoDJAlbumArtist = albumArtist;
    emit autoDJAlbumArtistChanged();
}

void Player::clearQueue() {
    // HUMAN-READABLE COMMENT:
    // Stops current track playback and completely empties the queue list and indexes.
    // Emits notify signals so that the QML queue view updates instantly.
    stop();
    m_queue.clear();
    m_originalQueue.clear();
    m_queueIndex = -1;
    emit queueChanged();
    emit queueIndexChanged();
    emit currentTrackChanged();
}

void Player::removeQueueIndex(int index) {
    // HUMAN-READABLE COMMENT:
    // Removes a specific track index from the current queue.
    // Handles active index re-adjustments and triggers correct track updates.
    if (index < 0 || index >= m_queue.size()) return;
    m_queue.removeAt(index);
    emit queueChanged();

    if (m_queueIndex == index) {
        if (m_queue.isEmpty()) {
            stop();
        } else {
            if (m_queueIndex >= m_queue.size()) {
                m_queueIndex = m_queue.size() - 1;
            }
            emit queueIndexChanged();
            playTrack(m_queueIndex);
        }
    } else if (m_queueIndex > index) {
        m_queueIndex--;
        emit queueIndexChanged();
    }
}

QVariantList Player::getAutoDJMatchingTracks() {
    // HUMAN-READABLE COMMENT:
    // Performs database track filtering for Auto-DJ. If a Genre, Artist, or Album Artist
    // filter is active, it runs case-insensitive matches against each database track.
    // Falls back to all database tracks if no matches are found, so player never stalls.
    QVariantList allTracks = Database::instance()->tracksVariant();
    if (m_autoDJGenre.isEmpty() && m_autoDJArtist.isEmpty() && m_autoDJAlbumArtist.isEmpty()) {
        return allTracks;
    }

    QVariantList matching;
    for (const QVariant &trackVar : allTracks) {
        QVariantMap t = trackVar.toMap();

        if (!m_autoDJGenre.isEmpty()) {
            QString g = t["genre"].toString().trimmed();
            if (g.compare(m_autoDJGenre.trimmed(), Qt::CaseInsensitive) != 0) {
                continue;
            }
        }

        if (!m_autoDJArtist.isEmpty()) {
            QString a = t["artist"].toString().trimmed();
            if (a.compare(m_autoDJArtist.trimmed(), Qt::CaseInsensitive) != 0) {
                continue;
            }
        }

        if (!m_autoDJAlbumArtist.isEmpty()) {
            QString aa = t["artist"].toString().trimmed(); // Various Artists matching
            if (aa.compare(m_autoDJAlbumArtist.trimmed(), Qt::CaseInsensitive) != 0) {
                continue;
            }
        }

        matching.append(trackVar);
    }

    if (matching.isEmpty()) {
        qDebug() << "Auto-DJ: No matching tracks found for specified filters. Falling back to all tracks.";
        return allTracks;
    }
    return matching;
}
