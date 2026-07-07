#ifndef PLAYER_H
#define PLAYER_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QVariantList>
#include <QVariantMap>
#include <QUrl>
#include <QRandomGenerator>
#include <QDebug>

class Player : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap currentTrack READ currentTrack NOTIFY currentTrackChanged)
    Q_PROPERTY(QString playbackStatus READ playbackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(int queueIndex READ queueIndex NOTIFY queueIndexChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(double position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(QString loopStatus READ loopStatus WRITE setLoopStatus NOTIFY loopStatusChanged)
    Q_PROPERTY(QVariantList queue READ queue NOTIFY queueChanged)
    Q_PROPERTY(QVariantList autoDJRules READ autoDJRules WRITE setAutoDJRules NOTIFY autoDJRulesChanged)

public:
    explicit Player(QObject *parent = nullptr);
    static Player* instance();

    QVariantMap currentTrack() const;
    QString playbackStatus() const;
    int queueIndex() const;
    double volume() const;
    double position() const;
    double duration() const;
    bool shuffle() const;
    QString loopStatus() const;
    QVariantList queue() const;
    bool autoDJ() const;
    void setAutoDJ(bool enabled);

    QVariantList autoDJRules() const;
    void setAutoDJRules(const QVariantList &rules);

    void setVolume(double volume);
    void setPosition(double positionSeconds);
    void setShuffle(bool enabled);
    void setLoopStatus(const QString &status);

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void togglePlay();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    
    Q_INVOKABLE void setQueue(const QVariantList &tracks, int startIndex);
    Q_INVOKABLE void clearQueue();
    Q_INVOKABLE void removeQueueIndex(int index);
    Q_INVOKABLE void playNext(const QVariantMap &track);
    Q_INVOKABLE void queueLast(const QVariantMap &track);
    Q_INVOKABLE void playNextAlbum(const QVariantList &tracks);
    Q_INVOKABLE void queueLastAlbum(const QVariantList &tracks);
    Q_INVOKABLE QString getLyricsForTrack(const QString &filePath);
    void updateTrackRating(const QString &trackId, int rating);

    QVariantList getAutoDJMatchingTracks();

signals:
    void currentTrackChanged();
    void playbackStatusChanged();
    void queueIndexChanged();
    void volumeChanged();
    void positionChanged();
    void durationChanged();
    void shuffleChanged();
    void loopStatusChanged();
    void queueChanged();
    void autoDJChanged();
    void autoDJRulesChanged();

    // Signal emitted when seek completes
    void seeked(double positionSeconds);

private slots:
    void onPositionChanged(qint64 ms);
    void onDurationChanged(qint64 ms);
    void onPlaybackStateChanged(QMediaPlayer::PlaybackState state);
    void onMediaStatusChanged(QMediaPlayer::MediaStatus status);

private:
    void playTrack(int index);
    void handleTrackEnded();

    QMediaPlayer *m_mediaPlayer;
    QAudioOutput *m_audioOutput;
    
    QVariantList m_queue;
    QVariantList m_originalQueue; // Holds unshuffled order
    int m_queueIndex = -1;
    bool m_shuffle = false;
    bool m_autoDJ = false;
    QString m_loopStatus = QStringLiteral("None"); // None, Track, Playlist

    QVariantList m_autoDJRules;

    static Player* m_instance;
};

#endif // PLAYER_H
