#include "scanner.h"

// ScanWorker Implementation

ScanWorker::ScanWorker(const QStringList &dirs, QObject *parent)
    : QObject(parent), m_dirs(dirs) {}

void ScanWorker::scanDir(const QString &dir, QStringList &audioFiles) {
    QDirIterator it(dir, QStringList() << "*.mp3" << "*.flac" << "*.ogg" << "*.wav" << "*.m4a" << "*.wma" << "*.opus",
                    QDir::Files | QDir::NoSymLinks, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        audioFiles.append(it.next());
    }
}

QPair<QString, int> ScanWorker::normalizeAlbum(const QString &albumName, const QString &filePath, int tagDiscNo) {
    if (albumName.isEmpty()) {
        return qMakePair(QStringLiteral("Unknown Album"), 1);
    }

    QString name = albumName.trimmed();
    int discNo = tagDiscNo > 0 ? tagDiscNo : 1;

    // Matches (CD 1), [CD1], (Disc 2), - Disc 2, CD2, etc. at the end of the string
    QRegularExpression discRegex(QStringLiteral(R"(\s*[\(\[-]?\s*(?:CD|Disc|Disk|Disque)\s*(\d+)[\)\]]?\s*$)"), QRegularExpression::CaseInsensitiveOption);
    QRegularExpressionMatch match = discRegex.match(name);
    
    if (match.hasMatch()) {
        discNo = match.captured(1).toInt();
        name = name.remove(discRegex).trimmed();
    } else {
        // If not matched in string, check directory name
        QFileInfo info(filePath);
        QString parentDir = info.dir().dirName();
        QRegularExpression dirRegex(QStringLiteral(R"(^(?:CD|Disc|Disk|CD\s*|Disc\s*|Disk\s*)(\d+)$)"), QRegularExpression::CaseInsensitiveOption);
        QRegularExpressionMatch dirMatch = dirRegex.match(parentDir);
        if (dirMatch.hasMatch()) {
            discNo = dirMatch.captured(1).toInt();
        }
    }

    if (name.isEmpty()) {
        name = albumName;
    }

    return qMakePair(name, discNo);
}

Track ScanWorker::parseTrack(const QString &filePath, const QString &coversCacheDir) {
    Track t;
    t.filePath = filePath;
    
    // Generate unique MD5 hash for the track based on its filepath
    QByteArray pathHash = QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5);
    t.id = QString::fromUtf8(pathHash.toHex());

    // Fallback values
    QFileInfo info(filePath);
    t.title = info.baseName();
    t.artist = QStringLiteral("Unknown Artist");
    t.album = QStringLiteral("Unknown Album");
    t.genre = QStringLiteral("Unknown");
    t.year = 0;
    t.trackNo = 0;
    t.discNo = 1;
    t.duration = 0.0;

    // Use TagLib to parse tags
    TagLib::FileRef fileRef(filePath.toLocal8Bit().constData());
    if (!fileRef.isNull() && fileRef.tag()) {
        TagLib::Tag *tag = fileRef.tag();
        
        if (!tag->title().isEmpty()) t.title = QString::fromStdString(tag->title().to8Bit(true));
        if (!tag->artist().isEmpty()) t.artist = QString::fromStdString(tag->artist().to8Bit(true));
        if (!tag->album().isEmpty()) t.album = QString::fromStdString(tag->album().to8Bit(true));
        if (!tag->genre().isEmpty()) t.genre = QString::fromStdString(tag->genre().to8Bit(true));
        
        t.year = tag->year();
        t.trackNo = tag->track();
    }

    if (!fileRef.isNull() && fileRef.audioProperties()) {
        t.duration = fileRef.audioProperties()->lengthInSeconds();
    }

    // Try reading disc number tag (custom property) and album type
    int tagDiscNo = 1;
    QString albumTypeVal = QStringLiteral("Studio Albums");
    if (!fileRef.isNull() && fileRef.file()) {
        // TagLib property mapping
        TagLib::PropertyMap properties = fileRef.file()->properties();
        if (properties.contains("DISCNUMBER")) {
            bool ok;
            int d = QString::fromStdString(properties["DISCNUMBER"].front().to8Bit(true)).toInt(&ok);
            if (ok) tagDiscNo = d;
        }
        
        QString rawType;
        if (properties.contains("ALBUMTYPE")) {
            rawType = QString::fromStdString(properties["ALBUMTYPE"].front().to8Bit(true)).trimmed();
        } else if (properties.contains("ALBUM_TYPE")) {
            rawType = QString::fromStdString(properties["ALBUM_TYPE"].front().to8Bit(true)).trimmed();
        }
        
        if (!rawType.isEmpty()) {
            QString typeLower = rawType.toLower();
            if (typeLower.contains(QLatin1String("single"))) {
                albumTypeVal = QStringLiteral("Singles");
            } else if (typeLower.contains(QLatin1String("live"))) {
                albumTypeVal = QStringLiteral("Live Albums");
            } else if (typeLower.contains(QLatin1String("compilation")) || typeLower.contains(QLatin1String("greatest")) || typeLower.contains(QLatin1String("hits")) || typeLower.contains(QLatin1String("gold"))) {
                albumTypeVal = QStringLiteral("Compilations");
            } else {
                albumTypeVal = QStringLiteral("Studio Albums");
            }
        }
    }
    t.albumType = albumTypeVal;

    // Normalize CD/disc grouping
    auto albumNorm = normalizeAlbum(t.album, filePath, tagDiscNo);
    t.album = albumNorm.first;
    t.discNo = albumNorm.second;

    // Generate unique ID for the album cover (artist::album hash)
    QByteArray albumHash = QCryptographicHash::hash(QStringLiteral("%1::%2").arg(t.album, t.artist).toUtf8(), QCryptographicHash::Md5);
    QString coverFilename = QStringLiteral("%1.jpg").arg(QString::fromUtf8(albumHash.toHex()));
    QString cachedCoverPath = QStringLiteral("%1/%2").arg(coversCacheDir, coverFilename);

    if (QFile::exists(cachedCoverPath)) {
        t.coverPath = QStringLiteral("file://%1").arg(cachedCoverPath);
    } else {
        QByteArray coverData;
        QString mimeType = QStringLiteral("image/jpeg");

        // 1. Try embedded picture via specific file types
        QString ext = info.suffix().toLower();
        if (ext == QLatin1String("mp3")) {
            TagLib::MPEG::File mpegFile(filePath.toLocal8Bit().constData());
            if (mpegFile.isValid() && mpegFile.ID3v2Tag()) {
                TagLib::ID3v2::Tag *id3v2 = mpegFile.ID3v2Tag();
                auto pictureFrames = id3v2->frameListMap()["APIC"];
                if (!pictureFrames.isEmpty()) {
                    auto *pictureFrame = static_cast<TagLib::ID3v2::AttachedPictureFrame*>(pictureFrames.front());
                    coverData = QByteArray(pictureFrame->picture().data(), pictureFrame->picture().size());
                    mimeType = QString::fromStdString(pictureFrame->mimeType().to8Bit(true));
                }
            }
        } else if (ext == QLatin1String("flac")) {
            TagLib::FLAC::File flacFile(filePath.toLocal8Bit().constData());
            if (flacFile.isValid()) {
                const auto &pictureList = flacFile.pictureList();
                if (!pictureList.isEmpty()) {
                    auto *picture = pictureList.front();
                    coverData = QByteArray(picture->data().data(), picture->data().size());
                    mimeType = QString::fromStdString(picture->mimeType().to8Bit(true));
                }
            }
        } else if (ext == QLatin1String("m4a") || ext == QLatin1String("mp4")) {
            TagLib::MP4::File mp4File(filePath.toLocal8Bit().constData());
            if (mp4File.isValid() && mp4File.tag()) {
                TagLib::MP4::Tag *mp4tag = mp4File.tag();
                if (mp4tag->itemMap().contains("covr")) {
                    TagLib::MP4::CoverArtList covers = mp4tag->itemMap()["covr"].toCoverArtList();
                    if (!covers.isEmpty()) {
                        coverData = QByteArray(covers.front().data().data(), covers.front().data().size());
                    }
                }
            }
        }

        // 2. Try directory cover fallback
        if (coverData.isEmpty()) {
            QDir dir = info.dir();
            QStringList filters = { "cover.jpg", "cover.png", "folder.jpg", "folder.png", "album.jpg", "album.png" };
            QFileInfoList list = dir.entryInfoList(filters, QDir::Files, QDir::Name);
            if (!list.isEmpty()) {
                QFile file(list.front().absoluteFilePath());
                if (file.open(QIODevice::ReadOnly)) {
                    coverData = file.readAll();
                    file.close();
                }
            }
        }

        // Save cover buffer if found
        if (!coverData.isEmpty()) {
            QFile file(cachedCoverPath);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(coverData);
                file.close();
                t.coverPath = QStringLiteral("file://%1").arg(cachedCoverPath);
            }
        }
    }

    return t;
}

void ScanWorker::process() {
    QStringList audioFiles;
    for (const auto &dir : m_dirs) {
        scanDir(dir, audioFiles);
    }

    int total = audioFiles.size();
    QList<Track> tracks;
    
    // Covers cache directory inside project root folder
    QString coversCacheDir = QStringLiteral("%1/cache/covers").arg(PROJECT_SOURCE_DIR);
    QDir().mkpath(coversCacheDir);

    for (int i = 0; i < total; ++i) {
        tracks.append(parseTrack(audioFiles[i], coversCacheDir));
        if (i % 5 == 0 || i == total - 1) {
            emit progress(i + 1, total);
        }
    }

    emit finished(tracks);
}


// LibraryScanner Implementation

LibraryScanner* LibraryScanner::m_instance = nullptr;

LibraryScanner::LibraryScanner(QObject *parent) : QObject(parent) {
    m_instance = this;
}

LibraryScanner* LibraryScanner::instance() {
    return m_instance;
}

bool LibraryScanner::scanning() const {
    return m_scanning;
}

void LibraryScanner::startScan() {
    if (m_scanning) return;

    QStringList dirs = Database::instance()->musicDirs();
    if (dirs.isEmpty()) {
        qWarning() << "Scanner: No directories configured.";
        emit scanFinished(0);
        return;
    }

    m_scanning = true;
    emit scanningChanged();

    m_thread = new QThread();
    ScanWorker *worker = new ScanWorker(dirs);
    worker->moveToThread(m_thread);

    connect(m_thread, &QThread::started, worker, &ScanWorker::process);
    connect(worker, &ScanWorker::progress, this, &LibraryScanner::scanProgress);
    connect(worker, &ScanWorker::finished, this, &LibraryScanner::onScanFinished);
    
    // Cleanup
    connect(worker, &ScanWorker::finished, worker, &QObject::deleteLater);
    connect(m_thread, &QThread::finished, m_thread, &QObject::deleteLater);

    m_thread->start();
}

void LibraryScanner::onScanFinished(const QList<Track> &tracks) {
    Database::instance()->saveTracks(tracks);

    m_scanning = false;
    emit scanningChanged();
    emit scanFinished(tracks.size());

    m_thread->quit();
    m_thread->wait();
    m_thread = nullptr;
}
