#ifndef SCANNER_H
#define SCANNER_H

#define PROJECT_SOURCE_DIR "/home/dave/Documents/antigravity/beautiful-rutherford"

#include <QObject>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QDir>
#include <QDirIterator>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include "database.h"

// TagLib headers
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/mp4file.h>
#include <taglib/mp4tag.h>
#include <taglib/mp4coverart.h>

class ScanWorker : public QObject {
    Q_OBJECT
public:
    explicit ScanWorker(const QStringList &dirs, QObject *parent = nullptr);

public slots:
    void process();

signals:
    void progress(int current, int total);
    void finished(const QList<Track> &tracks);

private:
    void scanDir(const QString &dir, QStringList &audioFiles);
    Track parseTrack(const QString &filePath, const QString &coversCacheDir);
    QPair<QString, int> normalizeAlbum(const QString &albumName, const QString &filePath, int tagDiscNo);

    QStringList m_dirs;
};

class LibraryScanner : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    explicit LibraryScanner(QObject *parent = nullptr);

    static LibraryScanner* instance();
    bool scanning() const;

    Q_INVOKABLE void startScan();

signals:
    void scanningChanged();
    void scanFinished(int totalTracks);
    void scanProgress(int current, int total);

private slots:
    void onScanFinished(const QList<Track> &tracks);

private:
    static LibraryScanner *m_instance;
    bool m_scanning = false;
    QThread *m_thread = nullptr;
};

#endif // SCANNER_H
