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
    loadMaster();
    loadLibraryData(m_activeLibraryId);
    
    emit musicDirsChanged();
    emit tracksChanged();
    emit collectionsChanged();
    emit librariesChanged();
    emit activeLibraryChanged();
}

void Database::save() {
    saveLibraryData(m_activeLibraryId);
}

QStringList Database::musicDirs() const {
    return m_musicDirs;
}

void Database::setMusicDirs(const QStringList &dirs) {
    bool modified = false;
    for (int i = 0; i < m_libraries.size(); ++i) {
        QJsonObject lib = m_libraries[i].toObject();
        if (lib["id"].toString() == m_activeLibraryId) {
            QJsonArray arr;
            for (const auto &d : dirs) {
                arr.append(d);
            }
            lib["musicDirs"] = arr;
            m_libraries[i] = lib;
            modified = true;
            break;
        }
    }
    
    if (modified || m_musicDirs != dirs) {
        m_musicDirs = dirs;
        saveMaster();
        save();
        setupDirectoryWatcher();
        emit musicDirsChanged();
        emit librariesChanged();
        
        if (LibraryScanner::instance()) {
            LibraryScanner::instance()->startScan();
        }
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
    bool modified = false;
    for (int i = 0; i < m_libraries.size(); ++i) {
        QJsonObject lib = m_libraries[i].toObject();
        if (lib["id"].toString() == m_activeLibraryId) {
            QJsonArray dirs = lib["musicDirs"].toArray();
            QString cleanDir = dir.trimmed();
            
            bool exists = false;
            for (const auto &dVal : dirs) {
                if (dVal.toString() == cleanDir) {
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                dirs.append(cleanDir);
                lib["musicDirs"] = dirs;
                m_libraries[i] = lib;
                m_musicDirs.append(cleanDir);
                modified = true;
            }
            break;
        }
    }
    
    if (modified) {
        saveMaster();
        setupDirectoryWatcher();
        emit musicDirsChanged();
        emit librariesChanged();
        
        if (LibraryScanner::instance()) {
            LibraryScanner::instance()->startScan();
        }
    }
}

void Database::removeMusicDir(const QString &dir) {
    bool modified = false;
    for (int i = 0; i < m_libraries.size(); ++i) {
        QJsonObject lib = m_libraries[i].toObject();
        if (lib["id"].toString() == m_activeLibraryId) {
            QJsonArray dirs = lib["musicDirs"].toArray();
            for (int j = 0; j < dirs.size(); ++j) {
                if (dirs[j].toString() == dir) {
                    dirs.removeAt(j);
                    lib["musicDirs"] = dirs;
                    m_libraries[i] = lib;
                    m_musicDirs.removeOne(dir);
                    modified = true;
                    break;
                }
            }
            break;
        }
    }
    
    if (modified) {
        saveMaster();
        setupDirectoryWatcher();
        emit musicDirsChanged();
        emit librariesChanged();
        
        if (LibraryScanner::instance()) {
            LibraryScanner::instance()->startScan();
        }
    }
}

void Database::saveCollection(const QString &id, const QString &name, const QString &coverPath, const QString &displayMode, const QVariantList &rules, const QString &folder) {
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
    colObj["folder"] = folder.trimmed();

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

bool Database::writeTrackTags(const QString &filePath, const QString &title, const QString &artist, const QString &album, const QString &genre, int year, const QString &albumType, const QString &albumArtist, bool compilation) {
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
        properties["ALBUMARTIST"] = TagLib::StringList(TagLib::String(albumArtist.toUtf8().constData(), TagLib::String::UTF8));
        properties["ALBUM_ARTIST"] = TagLib::StringList(TagLib::String(albumArtist.toUtf8().constData(), TagLib::String::UTF8));
        properties["COMPILATION"] = TagLib::StringList(compilation ? "1" : "0");
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
            m_tracks[i].albumArtist = albumArtist;
            m_tracks[i].compilation = compilation;
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

bool Database::saveLrcFile(const QString &trackFilePath, const QString &lrcContent) {
    QFileInfo trackInfo(trackFilePath);
    QString dirPath = trackInfo.absolutePath();
    QString baseName = trackInfo.completeBaseName();
    QString lrcPath = dirPath + "/" + baseName + ".lrc";

    QFile file(lrcPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to write LRC file:" << lrcPath;
        return false;
    }

    QTextStream out(&file);
    out << lrcContent;
    file.close();
    qDebug() << "Successfully saved lyrics to LRC file:" << lrcPath;
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

QString Database::getLibraryDataFilePath(const QString &libId) const {
    return QStringLiteral("%1/db_lib_%2.json").arg(PROJECT_SOURCE_DIR, libId);
}

void Database::loadMaster() {
    QString path = getDbFilePath();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "No master database file found. Creating default master.";
        QJsonObject defaultLib;
        defaultLib["id"] = QStringLiteral("default");
        defaultLib["name"] = QStringLiteral("Default Library");
        defaultLib["musicDirs"] = QJsonArray();
        m_libraries.append(defaultLib);
        m_activeLibraryId = QStringLiteral("default");
        saveMaster();
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        qWarning() << "Invalid master database format.";
        return;
    }

    QJsonObject root = doc.object();
    
    if (!root.contains("libraries")) {
        qDebug() << "Migrating old database to multi-library layout...";
        
        QJsonObject settings = root["settings"].toObject();
        QJsonArray dirs = settings["musicDirs"].toArray();
        
        QJsonObject defaultLib;
        defaultLib["id"] = QStringLiteral("default");
        defaultLib["name"] = QStringLiteral("Default Library");
        defaultLib["musicDirs"] = dirs;
        m_libraries.append(defaultLib);
        m_activeLibraryId = QStringLiteral("default");
        
        QJsonArray tracksArr = root["tracks"].toArray();
        QList<Track> oldTracks;
        for (const auto &trackVal : tracksArr) {
            oldTracks.append(Track::fromJsonObject(trackVal.toObject()));
        }
        QJsonArray oldCollections = root["collections"].toArray();
        
        saveLibraryDataHelper(QStringLiteral("default"), oldTracks, oldCollections);
        saveMaster();
        return;
    }

    m_libraries = root["libraries"].toArray();
    m_activeLibraryId = root["activeLibraryId"].toString();
    if (m_activeLibraryId.isEmpty() && !m_libraries.isEmpty()) {
        m_activeLibraryId = m_libraries[0].toObject()["id"].toString();
    }
}

void Database::saveMaster() {
    QString path = getDbFilePath();
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to write master database file at:" << path;
        return;
    }

    QJsonObject root;
    root["activeLibraryId"] = m_activeLibraryId;
    root["libraries"] = m_libraries;

    QJsonDocument doc(root);
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();
}

void Database::loadLibraryData(const QString &libId) {
    QString path = getLibraryDataFilePath(libId);
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Library data file not found at:" << path;
        m_tracks.clear();
        m_collections = QJsonArray();
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        m_tracks.clear();
        m_collections = QJsonArray();
        return;
    }

    QJsonObject root = doc.object();
    
    QJsonArray tracksArr = root["tracks"].toArray();
    m_tracks.clear();
    for (const auto &trackVal : tracksArr) {
        m_tracks.append(Track::fromJsonObject(trackVal.toObject()));
    }

    m_collections = root["collections"].toArray();
    
    m_musicDirs.clear();
    for (const auto &libVal : m_libraries) {
        QJsonObject lib = libVal.toObject();
        if (lib["id"].toString() == libId) {
            QJsonArray dirs = lib["musicDirs"].toArray();
            for (const auto &dirVal : dirs) {
                m_musicDirs.append(dirVal.toString());
            }
            break;
        }
    }
}

void Database::saveLibraryData(const QString &libId) {
    saveLibraryDataHelper(libId, m_tracks, m_collections);
}

void Database::saveLibraryDataHelper(const QString &libId, const QList<Track> &tracks, const QJsonArray &collections) {
    QString path = getLibraryDataFilePath(libId);
    
    QFileInfo info(path);
    QDir().mkpath(info.absolutePath());
    
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to write library data file at:" << path;
        return;
    }

    QJsonObject root;
    
    QJsonArray tracksArr;
    for (const auto &track : tracks) {
        tracksArr.append(track.toJsonObject());
    }
    root["tracks"] = tracksArr;

    root["collections"] = collections;

    QJsonDocument doc(root);
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();
}

QVariantList Database::librariesVariant() const {
    return m_libraries.toVariantList();
}

QString Database::activeLibraryId() const {
    return m_activeLibraryId;
}

QString Database::activeLibraryName() const {
    for (const auto &libVal : m_libraries) {
        QJsonObject lib = libVal.toObject();
        if (lib["id"].toString() == m_activeLibraryId) {
            return lib["name"].toString();
        }
    }
    return QStringLiteral("Unknown Library");
}

void Database::createLibrary(const QString &name, const QStringList &dirs) {
    QString id = QStringLiteral("lib-%1").arg(QDateTime::currentMSecsSinceEpoch());
    QJsonObject libObj;
    libObj["id"] = id;
    libObj["name"] = name.trimmed().isEmpty() ? QStringLiteral("New Library") : name.trimmed();
    QJsonArray dirsArr;
    for (const auto &d : dirs) {
        if (!d.trimmed().isEmpty()) {
            dirsArr.append(d.trimmed());
        }
    }
    libObj["musicDirs"] = dirsArr;
    
    m_libraries.append(libObj);
    saveMaster();
    
    QList<Track> emptyTracks;
    QJsonArray emptyCollections;
    saveLibraryDataHelper(id, emptyTracks, emptyCollections);
    
    emit librariesChanged();
    setActiveLibrary(id);
    
    if (!dirs.isEmpty()) {
        if (LibraryScanner::instance()) {
            LibraryScanner::instance()->startScan();
        }
    }
}

void Database::deleteLibrary(const QString &id) {
    if (m_libraries.size() <= 1) {
        return;
    }
    
    int indexToDelete = -1;
    for (int i = 0; i < m_libraries.size(); ++i) {
        if (m_libraries[i].toObject()["id"].toString() == id) {
            indexToDelete = i;
            break;
        }
    }
    
    if (indexToDelete != -1) {
        QString filePath = getLibraryDataFilePath(id);
        QFile::remove(filePath);
        
        m_libraries.removeAt(indexToDelete);
        saveMaster();
        emit librariesChanged();
        
        if (m_activeLibraryId == id) {
            QString nextActiveId = m_libraries[0].toObject()["id"].toString();
            setActiveLibrary(nextActiveId);
        }
    }
}

void Database::setActiveLibrary(const QString &id) {
    if (m_activeLibraryId == id) return;
    
    saveLibraryData(m_activeLibraryId);
    m_activeLibraryId = id;
    saveMaster();
    loadLibraryData(m_activeLibraryId);
    setupDirectoryWatcher();
    
    emit activeLibraryChanged();
    emit musicDirsChanged();
    emit tracksChanged();
    emit collectionsChanged();
}

void Database::renameLibrary(const QString &id, const QString &newName) {
    bool modified = false;
    for (int i = 0; i < m_libraries.size(); ++i) {
        QJsonObject lib = m_libraries[i].toObject();
        if (lib["id"].toString() == id) {
            lib["name"] = newName.trimmed().isEmpty() ? QStringLiteral("Unnamed Library") : newName.trimmed();
            m_libraries[i] = lib;
            modified = true;
            break;
        }
    }
    
    if (modified) {
        saveMaster();
        emit librariesChanged();
        if (m_activeLibraryId == id) {
            emit activeLibraryChanged();
        }
    }
}

void Database::resetLibraryCache() {
    m_tracks.clear();
    m_collections = QJsonArray();
    saveLibraryData(m_activeLibraryId);
    
    QString coversCacheDir = QStringLiteral("%1/cache/covers").arg(PROJECT_SOURCE_DIR);
    QDir dir(coversCacheDir);
    if (dir.exists()) {
        QFileInfoList list = dir.entryInfoList(QDir::Files);
        for (const auto &fileInfo : list) {
            QFile::remove(fileInfo.absoluteFilePath());
        }
    }
    
    emit tracksChanged();
    emit collectionsChanged();
    
    if (LibraryScanner::instance()) {
        LibraryScanner::instance()->startScan();
    }
}

