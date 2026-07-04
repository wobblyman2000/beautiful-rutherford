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
        return t;
    }
};

class Database : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList musicDirs READ musicDirs WRITE setMusicDirs NOTIFY musicDirsChanged)
    Q_PROPERTY(QVariantList tracks READ tracksVariant NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList collections READ collectionsVariant NOTIFY collectionsChanged)

public:
    explicit Database(QObject *parent = nullptr);

    static Database* instance();

    QStringList musicDirs() const;
    void setMusicDirs(const QStringList &dirs);

    QList<Track> getTracks() const;
    void saveTracks(const QList<Track> &tracks);

    QVariantList tracksVariant() const;
    QVariantList collectionsVariant() const;

    Q_INVOKABLE void addMusicDir(const QString &dir);
    Q_INVOKABLE void removeMusicDir(const QString &dir);
    
    // Smart Collections CRUD
    Q_INVOKABLE void saveCollection(const QString &id, const QString &name, const QString &coverPath, const QVariantList &rules);
    Q_INVOKABLE void deleteCollection(const QString &id);

signals:
    void musicDirsChanged();
    void tracksChanged();
    void collectionsChanged();

private:
    void load();
    void save();
    QString getDbFilePath() const;

    QStringList m_musicDirs;
    QList<Track> m_tracks;
    QJsonArray m_collections;
    
    static Database* m_instance;
};

#endif // DATABASE_H
