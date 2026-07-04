#include "database.h"

Database* Database::m_instance = nullptr;

Database::Database(QObject *parent) : QObject(parent) {
    m_instance = this;
    load();
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
        list.append(map);
    }
    return list;
}

QVariantList Database::collectionsVariant() const {
    return m_collections.toVariantList();
}

void Database::addMusicDir(const QString &dir) {
    if (!m_musicDirs.contains(dir)) {
        m_musicDirs.append(dir);
        save();
        emit musicDirsChanged();
    }
}

void Database::removeMusicDir(const QString &dir) {
    if (m_musicDirs.removeOne(dir)) {
        save();
        emit musicDirsChanged();
    }
}

void Database::saveCollection(const QString &id, const QString &name, const QString &coverPath, const QVariantList &rules) {
    QJsonObject colObj;
    QString finalId = id;
    
    if (id.isEmpty()) {
        finalId = QStringLiteral("col-%1").arg(QDateTime::currentMSecsSinceEpoch());
    }
    
    colObj["id"] = finalId;
    colObj["name"] = name;
    colObj["coverPath"] = coverPath;
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
