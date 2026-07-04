#ifndef MPRIS_H
#define MPRIS_H

#include <QObject>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVariant>
#include <QVariantMap>
#include <QStringList>
#include <QDebug>
#include "player.h"

// 1. Adaptor for org.mpris.MediaPlayer2
class MprisRootAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    
    Q_PROPERTY(bool CanQuit READ CanQuit)
    Q_PROPERTY(bool Fullscreen READ Fullscreen WRITE setFullscreen)
    Q_PROPERTY(bool CanSetFullscreen READ CanSetFullscreen)
    Q_PROPERTY(bool CanRaise READ CanRaise)
    Q_PROPERTY(bool HasTrackList READ HasTrackList)
    Q_PROPERTY(QString Identity READ Identity)
    Q_PROPERTY(QString DesktopEntry READ DesktopEntry)
    Q_PROPERTY(QStringList SupportedUriSchemes READ SupportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ SupportedMimeTypes)

public:
    explicit MprisRootAdaptor(QObject *parent);

    bool CanQuit() const;
    bool Fullscreen() const;
    void setFullscreen(bool fs);
    bool CanSetFullscreen() const;
    bool CanRaise() const;
    bool HasTrackList() const;
    QString Identity() const;
    QString DesktopEntry() const;
    QStringList SupportedUriSchemes() const;
    QStringList SupportedMimeTypes() const;

public slots:
    void Raise();
    void Quit();
};

// 2. Adaptor for org.mpris.MediaPlayer2.Player
class MprisPlayerAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    
    Q_PROPERTY(QString PlaybackStatus READ PlaybackStatus)
    Q_PROPERTY(QString LoopStatus READ LoopStatus WRITE setLoopStatus)
    Q_PROPERTY(double Rate READ Rate WRITE setRate)
    Q_PROPERTY(bool Shuffle READ Shuffle WRITE setShuffle)
    Q_PROPERTY(QVariantMap Metadata READ Metadata)
    Q_PROPERTY(double Volume READ Volume WRITE setVolume)
    Q_PROPERTY(qlonglong Position READ Position)
    Q_PROPERTY(double MinimumRate READ MinimumRate)
    Q_PROPERTY(double MaximumRate READ MaximumRate)
    Q_PROPERTY(bool CanGoNext READ CanGoNext)
    Q_PROPERTY(bool CanGoPrevious READ CanGoPrevious)
    Q_PROPERTY(bool CanPlay READ CanPlay)
    Q_PROPERTY(bool CanPause READ CanPause)
    Q_PROPERTY(bool CanSeek READ CanSeek)
    Q_PROPERTY(bool CanControl READ CanControl)

public:
    explicit MprisPlayerAdaptor(Player *player, QObject *parent);

    QString PlaybackStatus() const;
    
    QString LoopStatus() const;
    void setLoopStatus(const QString &status);
    
    double Rate() const;
    void setRate(double rate);
    
    bool Shuffle() const;
    void setShuffle(bool shuffle);
    
    QVariantMap Metadata() const;
    
    double Volume() const;
    void setVolume(double volume);
    
    qlonglong Position() const;
    
    double MinimumRate() const;
    double MaximumRate() const;
    bool CanGoNext() const;
    bool CanGoPrevious() const;
    bool CanPlay() const;
    bool CanPause() const;
    bool CanSeek() const;
    bool CanControl() const;

public slots:
    void Next();
    void Previous();
    void Pause();
    void PlayPause();
    void Stop();
    void Play();
    void Seek(qlonglong Offset);
    void SetPosition(const QDBusObjectPath &TrackId, qlonglong Position);
    void OpenUri(const QString &Uri);

signals:
    void Seeked(qlonglong Position);

private slots:
    void onPlayerSeeked(double positionSeconds);
    void onPlayerChanged();

private:
    Player *m_player;
};

class MprisService : public QObject {
    Q_OBJECT
public:
    explicit MprisService(Player *player, QObject *parent = nullptr);
    
    void registerService();

private:
    Player *m_player;
    MprisRootAdaptor *m_rootAdaptor;
    MprisPlayerAdaptor *m_playerAdaptor;
};

#endif // MPRIS_H
