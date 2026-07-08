#include "database.h"
#include "scanner.h"
#include "player.h"
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>
#include <QDirIterator>

Database* Database::m_instance = nullptr;

Database::Database(QObject *parent) : QObject(parent) {
    m_instance = this;
    
    m_watcher = new QFileSystemWatcher(this);
    m_watchDebounceTimer = new QTimer(this);
    m_watchDebounceTimer->setSingleShot(true);

    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, &Database::onDirectoryChanged);
    connect(m_watchDebounceTimer, &QTimer::timeout, this, &Database::onDebounceTimeout);

    load();
    setupDirectoryWatcher();
}

Database* Database::instance() {
    return m_instance;
}

QString Database::getDbFilePath() const {
    // Save to db.json in the project root folder
    return QStringLiteral("%1/db.json").arg(PROJECT_SOURCE_DIR);
}

void Database::load() {
    QString path = getDbFilePath();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "No database file found. Initializing empty DB at:" << path;
        save();
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        qWarning() << "Invalid database format. Resetting DB.";
        save();
        return;
    }

    QJsonObject root = doc.object();
    
    // Load Settings
    QJsonObject settings = root["settings"].toObject();
    QJsonArray dirs = settings["musicDirs"].toArray();
    m_musicDirs.clear();
    for (const auto &dirVal : dirs) {
        m_musicDirs.append(dirVal.toString());
    }

    // Load Tracks
    QJsonArray tracksArr = root["tracks"].toArray();
    m_tracks.clear();
    for (const auto &trackVal : tracksArr) {
        m_tracks.append(Track::fromJsonObject(trackVal.toObject()));
    }

    // Load Collections
    m_collections = root["collections"].toArray();

    emit musicDirsChanged();
    emit tracksChanged();
    emit collectionsChanged();
}

void Database::save() {
    QString path = getDbFilePath();
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to write database file at:" << path;
        return;
    }

    QJsonObject root;
    
    // Save Settings
    QJsonObject settings;
    QJsonArray dirs;
    for (const auto &dir : m_musicDirs) {
        dirs.append(dir);
    }
    settings["musicDirs"] = dirs;
    root["settings"] = settings;

    // Save Tracks
    QJsonArray tracksArr;
    for (const auto &track : m_tracks) {
        tracksArr.append(track.toJsonObject());
    }
    root["tracks"] = tracksArr;

    // Save Collections
    root["collections"] = m_collections;

    QJsonDocument doc(root);
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();
}

QStringList Database::musicDirs() const {
    return m_musicDirs;
}

void Database::setMusicDirs(const QStringList &dirs) {
    if (m_musicDirs != dirs) {
        m_musicDirs = dirs;
        save();
        setupDirectoryWatcher();
        emit musicDirsChanged();
    }
}

QList<Track> Database::getTracks() const {
    return m_tracks;
}

void Database::saveTracks(const QList<Track> &tracks) {
    m_tracks = tracks;
    save();
    emit tracksChanged();
}

#include <QSet>

QVariantList Database::tracksVariant() const {
    QVariantList list;
    for (const auto &track : m_tracks) {
        QVariantMap map;
        map["id"] = track.id;
        map["filePath"] = track.filePath;
        map["title"] = track.title;
        map["artist"] = track.artist;
        map["album"] = track.album;
        map["genre"] = track.genre;
        map["year"] = track.year;
        map["trackNo"] = track.trackNo;
        map["discNo"] = track.discNo;
        map["duration"] = track.duration;
        map["coverPath"] = track.coverPath;
        map["albumType"] = track.albumType;
        map["rating"] = track.rating;
        map["albumArtist"] = track.albumArtist;
        map["compilation"] = track.compilation;
        list.append(map);
    }
    return list;
}

QVariantList Database::collectionsVariant() const {
    return m_collections.toVariantList();
}

QStringList Database::allGenres() const {
    QSet<QString> genresSet;
    for (const auto &track : m_tracks) {
        if (track.genre.isEmpty()) continue;
        QStringList list = track.genre.split(QLatin1Char(','));
        for (const auto &genre : list) {
            QString trimmed = genre.trimmed();
            if (!trimmed.isEmpty()) {
                genresSet.insert(trimmed);
            }
        }
    }
    QStringList result = genresSet.values();
    result.sort(Qt::CaseInsensitive);
    return result;
}

QStringList Database::allArtists() const {
    QSet<QString> artistsSet;
    for (const auto &track : m_tracks) {
        if (!track.artist.isEmpty()) {
            artistsSet.insert(track.artist.trimmed());
        }
    }
    QStringList result = artistsSet.values();
    result.sort(Qt::CaseInsensitive);
    return result;
}

QStringList Database::allAlbums() const {
    QSet<QString> albumsSet;
    for (const auto &track : m_tracks) {
        if (!track.album.isEmpty()) {
            albumsSet.insert(track.album.trimmed());
        }
    }
    QStringList result = albumsSet.values();
    result.sort(Qt::CaseInsensitive);
    return result;
}

void Database::addMusicDir(const QString &dir) {
    if (!m_musicDirs.contains(dir)) {
        m_musicDirs.append(dir);
        save();
        setupDirectoryWatcher();
        emit musicDirsChanged();
    }
}

void Database::removeMusicDir(const QString &dir) {
    if (m_musicDirs.removeOne(dir)) {
        save();
        setupDirectoryWatcher();
        emit musicDirsChanged();
    }
}

void Database::saveCollection(const QString &id, const QString &name, const QString &coverPath, const QString &displayMode, const QVariantList &rules) {
    QJsonObject colObj;
    QString finalId = id;
    
    if (id.isEmpty()) {
        finalId = QStringLiteral("col-%1").arg(QDateTime::currentMSecsSinceEpoch());
    }
    
    colObj["id"] = finalId;
    colObj["name"] = name;
    colObj["coverPath"] = coverPath;
    colObj["displayMode"] = displayMode;
    colObj["rules"] = QJsonArray::fromVariantList(rules);

    // If updating, replace existing
    bool found = false;
    for (int i = 0; i < m_collections.size(); ++i) {
        QJsonObject existing = m_collections[i].toObject();
        if (existing["id"].toString() == finalId) {
            m_collections[i] = colObj;
            found = true;
            break;
        }
    }

    if (!found) {
        m_collections.append(colObj);
    }

    save();
    emit collectionsChanged();
}

void Database::deleteCollection(const QString &id) {
    for (int i = 0; i < m_collections.size(); ++i) {
        if (m_collections[i].toObject()["id"].toString() == id) {
            m_collections.removeAt(i);
            save();
            emit collectionsChanged();
            return;
        }
    }
}

void Database::setTrackRating(const QString &trackId, int rating) {
    bool updated = false;
    for (auto &track : m_tracks) {
        if (track.id == trackId) {
            track.rating = qBound(0, rating, 5);
            updated = true;
            break;
        }
    }
    if (updated) {
        save();
        emit tracksChanged();
        if (Player::instance()) {
            Player::instance()->updateTrackRating(trackId, rating);
        }
    }
}

bool Database::writeTrackTags(const QString &filePath, const QString &title, const QString &artist, const QString &album, const QString &genre, int year, const QString &albumType) {
    TagLib::FileRef fileRef(filePath.toLocal8Bit().constData());
    if (fileRef.isNull() || !fileRef.tag()) {
        qWarning() << "Failed to open audio file with TagLib for writing:" << filePath;
        return false;
    }

    TagLib::Tag *tag = fileRef.tag();
    tag->setTitle(TagLib::String(title.toUtf8().constData(), TagLib::String::UTF8));
    tag->setArtist(TagLib::String(artist.toUtf8().constData(), TagLib::String::UTF8));
    tag->setAlbum(TagLib::String(album.toUtf8().constData(), TagLib::String::UTF8));
    tag->setGenre(TagLib::String(genre.toUtf8().constData(), TagLib::String::UTF8));
    tag->setYear(year);

    if (fileRef.file()) {
        TagLib::PropertyMap properties = fileRef.file()->properties();
        properties["ALBUMTYPE"] = TagLib::StringList(TagLib::String(albumType.toUtf8().constData(), TagLib::String::UTF8));
        fileRef.file()->setProperties(properties);
    }

    if (!fileRef.save()) {
        qWarning() << "Failed to save audio tags to file:" << filePath;
        return false;
    }

    // Update in-memory track cache
    bool found = false;
    for (int i = 0; i < m_tracks.size(); ++i) {
        if (m_tracks[i].filePath == filePath) {
            m_tracks[i].title = title;
            m_tracks[i].artist = artist;
            m_tracks[i].album = album;
            m_tracks[i].genre = genre;
            m_tracks[i].year = year;
            m_tracks[i].albumType = albumType;
            found = true;
            break;
        }
    }

    if (found) {
        save();
        emit tracksChanged();
    }
    return true;
}

void Database::onDirectoryChanged(const QString &path) {
    Q_UNUSED(path);
    qDebug() << "Library Watcher: Directory modification detected at:" << path;
    // Reset debounce timer to fire in 1.5 seconds
    if (m_watchDebounceTimer) {
        m_watchDebounceTimer->start(1500);
    }
}

void Database::onDebounceTimeout() {
    qDebug() << "Library Watcher: Debounce timer expired. Triggering library rescan.";
    if (LibraryScanner::instance()) {
        LibraryScanner::instance()->startScan();
    }
    setupDirectoryWatcher();
}

void Database::setupDirectoryWatcher() {
    if (!m_watcher) return;
    
    // Unwatch old directories
    QStringList watched = m_watcher->directories();
    if (!watched.isEmpty()) {
        m_watcher->removePaths(watched);
    }
    
    QStringList toWatch;
    for (const QString &musicDir : m_musicDirs) {
        QDir rootDir(musicDir);
        if (rootDir.exists()) {
            toWatch.append(musicDir);
            
            // Find all subdirectories recursively
            QDirIterator it(musicDir, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                toWatch.append(it.next());
            }
        }
    }
    
    if (!toWatch.isEmpty()) {
        m_watcher->addPaths(toWatch);
        qDebug() << "Library Watcher: Watching" << toWatch.size() << "directories recursively.";
    }
}
