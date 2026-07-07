#ifndef DATABASE_H
#define DATABASE_H

#define PROJECT_SOURCE_DIR "/home/dave/Documents/antigravity/beautiful-rutherford"

#include <QObject>
#include <QString>
#include <QList>
#include <QVariantMap>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QFileSystemWatcher>
#include <QTimer>

struct Track {
    QString id;
    QString filePath;
    QString title;
    QString artist;
    QString album;
    QString genre;
    int year = 0;
    int trackNo = 0;
    int discNo = 1;
    double duration = 0.0;
    QString coverPath;
    QString albumType;
    int rating = 0;

    QJsonObject toJsonObject() const {
        QJsonObject obj;
        obj["id"] = id;
        obj["filePath"] = filePath;
        obj["title"] = title;
        obj["artist"] = artist;
        obj["album"] = album;
        obj["genre"] = genre;
        obj["year"] = year;
        obj["trackNo"] = trackNo;
        obj["discNo"] = discNo;
        obj["duration"] = duration;
        obj["coverPath"] = coverPath;
        obj["albumType"] = albumType;
        obj["rating"] = rating;
        return obj;
    }

    static Track fromJsonObject(const QJsonObject &obj) {
        Track t;
        t.id = obj["id"].toString();
        t.filePath = obj["filePath"].toString();
        t.title = obj["title"].toString();
        t.artist = obj["artist"].toString();
        t.album = obj["album"].toString();
        t.genre = obj["genre"].toString();
        t.year = obj["year"].toInt();
        t.trackNo = obj["trackNo"].toInt();
        t.discNo = obj["discNo"].toInt(1);
        t.duration = obj["duration"].toDouble();
        t.coverPath = obj["coverPath"].toString();
        t.albumType = obj["albumType"].toString(QStringLiteral("Studio Albums"));
        t.rating = obj["rating"].toInt(0);
        return t;
    }
};

class Database : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList musicDirs READ musicDirs WRITE setMusicDirs NOTIFY musicDirsChanged)
    Q_PROPERTY(QVariantList tracks READ tracksVariant NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList collections READ collectionsVariant NOTIFY collectionsChanged)
    Q_PROPERTY(QStringList allGenres READ allGenres NOTIFY tracksChanged)
    Q_PROPERTY(QStringList allArtists READ allArtists NOTIFY tracksChanged)
    Q_PROPERTY(QStringList allAlbums READ allAlbums NOTIFY tracksChanged)

public:
    explicit Database(QObject *parent = nullptr);

    static Database* instance();

    QStringList musicDirs() const;
    void setMusicDirs(const QStringList &dirs);

    QList<Track> getTracks() const;
    void saveTracks(const QList<Track> &tracks);

    QVariantList tracksVariant() const;
    QVariantList collectionsVariant() const;
    
    Q_INVOKABLE QStringList allGenres() const;
    Q_INVOKABLE QStringList allArtists() const;
    Q_INVOKABLE QStringList allAlbums() const;

    Q_INVOKABLE void addMusicDir(const QString &dir);
    Q_INVOKABLE void removeMusicDir(const QString &dir);
    
    // Smart Collections CRUD
    Q_INVOKABLE void saveCollection(const QString &id, const QString &name, const QString &coverPath, const QString &displayMode, const QVariantList &rules);
    Q_INVOKABLE void deleteCollection(const QString &id);
    Q_INVOKABLE void setTrackRating(const QString &trackId, int rating);
    Q_INVOKABLE bool writeTrackTags(const QString &filePath, const QString &title, const QString &artist, const QString &album, const QString &genre, int year, const QString &albumType);

signals:
    void musicDirsChanged();
    void tracksChanged();
    void collectionsChanged();

private slots:
    void onDirectoryChanged(const QString &path);
    void onDebounceTimeout();

private:
    void load();
    void save();
    QString getDbFilePath() const;
    void setupDirectoryWatcher();

    QStringList m_musicDirs;
    QList<Track> m_tracks;
    QJsonArray m_collections;
    
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_watchDebounceTimer = nullptr;

    static Database* m_instance;
};

#endif // DATABASE_H
