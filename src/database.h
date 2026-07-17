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
    QString albumArtist;
    bool compilation = false;
    double trackGain = 0.0;

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
        obj["albumArtist"] = albumArtist;
        obj["compilation"] = compilation;
        obj["trackGain"] = trackGain;
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
        t.albumArtist = obj["albumArtist"].toString();
        t.compilation = obj["compilation"].toBool(false);
        t.trackGain = obj["trackGain"].toDouble(0.0);
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
    Q_PROPERTY(QVariantList libraries READ librariesVariant NOTIFY librariesChanged)
    Q_PROPERTY(QString activeLibraryId READ activeLibraryId NOTIFY activeLibraryChanged)
    Q_PROPERTY(QString activeLibraryName READ activeLibraryName NOTIFY activeLibraryChanged)

public:
    explicit Database(QObject *parent = nullptr);

    static Database* instance();
    QString getDbFilePath() const;
    QString getLibraryDataFilePath(const QString &libId) const;

    QStringList musicDirs() const;
    void setMusicDirs(const QStringList &dirs);

    QList<Track> getTracks() const;
    void saveTracks(const QList<Track> &tracks);

    QVariantList tracksVariant() const;
    QVariantList collectionsVariant() const;
    QVariantList librariesVariant() const;
    QString activeLibraryId() const;
    QString activeLibraryName() const;
    
    Q_INVOKABLE QStringList allGenres() const;
    Q_INVOKABLE QStringList allArtists() const;
    Q_INVOKABLE QStringList allAlbums() const;

    Q_INVOKABLE void addMusicDir(const QString &dir);
    Q_INVOKABLE void removeMusicDir(const QString &dir);
    
    // Multiple Libraries Management
    Q_INVOKABLE void createLibrary(const QString &name, const QStringList &dirs);
    Q_INVOKABLE void deleteLibrary(const QString &id);
    Q_INVOKABLE void setActiveLibrary(const QString &id);
    Q_INVOKABLE void renameLibrary(const QString &id, const QString &newName);
    
    // Smart Collections CRUD
    Q_INVOKABLE void saveCollection(const QString &id, const QString &name, const QString &coverPath, const QString &displayMode, const QVariantList &rules, const QString &folder = QString());
    Q_INVOKABLE void deleteCollection(const QString &id);
    Q_INVOKABLE void setTrackRating(const QString &trackId, int rating);
    Q_INVOKABLE bool writeTrackTags(const QString &filePath, const QString &title, const QString &artist, const QString &album, const QString &genre, int year, const QString &albumType, const QString &albumArtist, bool compilation);
    Q_INVOKABLE bool saveLrcFile(const QString &trackFilePath, const QString &lrcContent);

signals:
    void musicDirsChanged();
    void tracksChanged();
    void collectionsChanged();
    void librariesChanged();
    void activeLibraryChanged();

private slots:
    void onDirectoryChanged(const QString &path);
    void onDebounceTimeout();

private:
    void load();
    void save();
    void loadMaster();
    void saveMaster();
    void loadLibraryData(const QString &libId);
    void saveLibraryData(const QString &libId);
    void saveLibraryDataHelper(const QString &libId, const QList<Track> &tracks, const QJsonArray &collections);
    void setupDirectoryWatcher();

    QStringList m_musicDirs;
    QList<Track> m_tracks;
    QJsonArray m_collections;
    
    QJsonArray m_libraries;
    QString m_activeLibraryId;
    
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_watchDebounceTimer = nullptr;

    static Database* m_instance;
};

#endif // DATABASE_H
