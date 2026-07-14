#include "player.h"
#include "database.h"
#include <QFileInfo>
#include <QFile>
#include <taglib/tag.h>
#include <taglib/fileref.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/unsynchronizedlyricsframe.h>
#include <taglib/flacfile.h>
#include <taglib/xiphcomment.h>

Player* Player::m_instance = nullptr;

Player::Player(QObject *parent) : QObject(parent) {
    m_instance = this;

    m_mediaPlayer = new QMediaPlayer(this);
    m_audioOutput = new QAudioOutput(this);
    m_mediaPlayer->setAudioOutput(m_audioOutput);

    m_baseVolume = 0.8;
    m_replayGainEnabled = true;
    m_audioOutput->setVolume(0.8); // Default volume

    m_autoDJRules = QVariantList();

    connect(m_mediaPlayer, &QMediaPlayer::positionChanged, this, &Player::onPositionChanged);
    connect(m_mediaPlayer, &QMediaPlayer::durationChanged, this, &Player::onDurationChanged);
    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged, this, &Player::onPlaybackStateChanged);
    connect(m_mediaPlayer, &QMediaPlayer::mediaStatusChanged, this, &Player::onMediaStatusChanged);
    connect(this, &Player::currentTrackChanged, this, &Player::updateAudioOutputVolume);
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
    return m_baseVolume;
}

void Player::setVolume(double volume) {
    double vol = qMax(0.0, qMin(1.0, volume));
    if (qFuzzyCompare(static_cast<float>(m_baseVolume), static_cast<float>(vol))) return;
    m_baseVolume = vol;
    updateAudioOutputVolume();
    emit volumeChanged();
}

bool Player::replayGainEnabled() const {
    return m_replayGainEnabled;
}

void Player::setReplayGainEnabled(bool enabled) {
    if (m_replayGainEnabled == enabled) return;
    m_replayGainEnabled = enabled;
    updateAudioOutputVolume();
    emit replayGainEnabledChanged();
}

void Player::updateAudioOutputVolume() {
    double multiplier = 1.0;
    if (m_replayGainEnabled) {
        QVariantMap track = currentTrack();
        if (track.contains(QStringLiteral("trackGain"))) {
            double trackGain = track[QStringLiteral("trackGain")].toDouble();
            if (trackGain != 0.0) {
                multiplier = qMin(1.0, qMax(0.01, pow(10.0, trackGain / 20.0)));
                qDebug() << "ReplayGain: Applied gain" << trackGain << "dB, target volume multiplier =" << multiplier;
            }
        }
    }
    double targetVol = qMax(0.0, qMin(1.0, m_baseVolume * multiplier));
    m_audioOutput->setVolume(targetVol);
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

QVariantList Player::autoDJRules() const {
    return m_autoDJRules;
}

void Player::setAutoDJRules(const QVariantList &rules) {
    m_autoDJRules = rules;
    emit autoDJRulesChanged();
}

bool matchAutoDJRules(const QVariantMap &track, const QVariantList &rules) {
    if (rules.isEmpty()) return true;

    for (const QVariant &ruleVar : rules) {
        QVariantMap rule = ruleVar.toMap();
        QString field = rule["field"].toString().trimmed().toLower();
        QString op = rule["operator"].toString().trimmed().toLower();
        QString criteria = rule["value"].toString().trimmed().toLower();

        QString fieldKey = field;
        if (field == QStringLiteral("album")) fieldKey = QStringLiteral("album");
        else if (field == QStringLiteral("artist")) fieldKey = QStringLiteral("artist");
        else if (field == QStringLiteral("genre")) fieldKey = QStringLiteral("genre");
        else if (field == QStringLiteral("title")) fieldKey = QStringLiteral("title");
        else if (field == QStringLiteral("filepath")) fieldKey = QStringLiteral("filePath");
        else if (field == QStringLiteral("rating")) fieldKey = QStringLiteral("rating");
        else if (field == QStringLiteral("year")) fieldKey = QStringLiteral("year");

        QString val = track[fieldKey].toString().trimmed().toLower();
        bool matched = false;

        if (op == QStringLiteral("contains")) {
            matched = val.contains(criteria);
        } else if (op == QStringLiteral("is")) {
            matched = (val == criteria);
        } else if (op == QStringLiteral("starts_with")) {
            matched = val.startsWith(criteria);
        } else if (op == QStringLiteral("ends_with")) {
            matched = val.endsWith(criteria);
        } else if (op == QStringLiteral("not_contains")) {
            matched = !val.contains(criteria);
        }

        if (!matched) return false;
    }
    return true;
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
    // Performs database track filtering for Auto-DJ using complex collection rules list.
    // If a rule fails the AND condition check, it is filtered out of matching list.
    // Falls back to all database tracks if no matches are found, so player never stalls.
    QVariantList allTracks = Database::instance()->tracksVariant();
    if (m_autoDJRules.isEmpty()) {
        return allTracks;
    }

    QVariantList matching;
    for (const QVariant &trackVar : allTracks) {
        QVariantMap t = trackVar.toMap();
        if (matchAutoDJRules(t, m_autoDJRules)) {
            matching.append(trackVar);
        }
    }

    if (matching.isEmpty()) {
        qDebug() << "Auto-DJ: No matching tracks found for rules. Falling back to all tracks.";
        return allTracks;
    }
    return matching;
}

void Player::playNext(const QVariantMap &track) {
    if (m_queue.isEmpty()) {
        setQueue(QVariantList() << track, 0);
        return;
    }
    int insertPos = m_queueIndex + 1;
    m_queue.insert(insertPos, track);
    emit queueChanged();
}

void Player::queueLast(const QVariantMap &track) {
    if (m_queue.isEmpty()) {
        setQueue(QVariantList() << track, 0);
        return;
    }
    m_queue.append(track);
    emit queueChanged();
}

void Player::playNextAlbum(const QVariantList &tracks) {
    if (tracks.isEmpty()) return;
    if (m_queue.isEmpty()) {
        setQueue(tracks, 0);
        return;
    }
    int insertPos = m_queueIndex + 1;
    for (int i = 0; i < tracks.size(); ++i) {
        m_queue.insert(insertPos + i, tracks[i]);
    }
    emit queueChanged();
}

void Player::queueLastAlbum(const QVariantList &tracks) {
    if (tracks.isEmpty()) return;
    if (m_queue.isEmpty()) {
        setQueue(tracks, 0);
        return;
    }
    for (int i = 0; i < tracks.size(); ++i) {
        m_queue.append(tracks[i]);
    }
    emit queueChanged();
}

QString Player::getLyricsForTrack(const QString &filePath) {
    // 1. Check for local .lrc file in the same directory
    QFileInfo fileInfo(filePath);
    QString baseName = fileInfo.completeBaseName();
    QString dirPath = fileInfo.absolutePath();
    QString lrcPath = QStringLiteral("%1/%2.lrc").arg(dirPath, baseName);
    QFile lrcFile(lrcPath);
    if (lrcFile.exists() && lrcFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString content = QString::fromUtf8(lrcFile.readAll());
        lrcFile.close();
        return content;
    }

    // 2. Fallback to TagLib embedded lyrics
    QByteArray localPath = filePath.toLocal8Bit();
    TagLib::FileRef fileRef(localPath.constData());
    if (!fileRef.isNull() && fileRef.tag()) {
        // A. MP3 / MPEG (ID3v2 USLT frame)
        TagLib::MPEG::File mpegFile(localPath.constData());
        if (mpegFile.isValid() && mpegFile.ID3v2Tag()) {
            TagLib::ID3v2::Tag *id3v2 = mpegFile.ID3v2Tag();
            TagLib::ID3v2::FrameList frames = id3v2->frameListMap()["USLT"];
            if (!frames.isEmpty()) {
                auto *lyricsFrame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame*>(frames.front());
                if (lyricsFrame) {
                    return QString::fromUtf8(lyricsFrame->text().toCString(true));
                }
            }
        }
        
        // B. FLAC (Vorbis Comments "LYRICS" or "UNSYNCEDLYRICS")
        TagLib::FLAC::File flacFile(localPath.constData());
        if (flacFile.isValid() && flacFile.xiphComment()) {
            TagLib::Ogg::XiphComment *comment = flacFile.xiphComment();
            if (comment->fieldListMap().contains("LYRICS")) {
                TagLib::StringList list = comment->fieldListMap()["LYRICS"];
                if (!list.isEmpty()) {
                    return QString::fromUtf8(list.front().toCString(true));
                }
            }
            if (comment->fieldListMap().contains("UNSYNCEDLYRICS")) {
                TagLib::StringList list = comment->fieldListMap()["UNSYNCEDLYRICS"];
                if (!list.isEmpty()) {
                    return QString::fromUtf8(list.front().toCString(true));
                }
            }
        }
    }

    return QString();
}

void Player::updateTrackRating(const QString &trackId, int rating) {
    bool changed = false;
    for (int i = 0; i < m_queue.size(); ++i) {
        QVariantMap trackMap = m_queue[i].toMap();
        if (trackMap["id"].toString() == trackId) {
            trackMap["rating"] = rating;
            m_queue[i] = trackMap;
            changed = true;
        }
    }
    for (int i = 0; i < m_originalQueue.size(); ++i) {
        QVariantMap trackMap = m_originalQueue[i].toMap();
        if (trackMap["id"].toString() == trackId) {
            trackMap["rating"] = rating;
            m_originalQueue[i] = trackMap;
        }
    }
    if (changed) {
        emit queueChanged();
        
        QVariantMap currentMap = currentTrack();
        if (currentMap["id"].toString() == trackId) {
            emit currentTrackChanged();
        }
    }
}
