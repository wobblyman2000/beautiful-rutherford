/****************************************************************************
** Meta object code from reading C++ file 'database.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../src/database.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'database.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN8DatabaseE_t {};
} // unnamed namespace

template <> constexpr inline auto Database::qt_create_metaobjectdata<qt_meta_tag_ZN8DatabaseE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "Database",
        "musicDirsChanged",
        "",
        "tracksChanged",
        "collectionsChanged",
        "onDirectoryChanged",
        "path",
        "onDebounceTimeout",
        "allGenres",
        "allArtists",
        "allAlbums",
        "addMusicDir",
        "dir",
        "removeMusicDir",
        "saveCollection",
        "id",
        "name",
        "coverPath",
        "displayMode",
        "QVariantList",
        "rules",
        "deleteCollection",
        "setTrackRating",
        "trackId",
        "rating",
        "writeTrackTags",
        "filePath",
        "title",
        "artist",
        "album",
        "genre",
        "year",
        "albumType",
        "musicDirs",
        "tracks",
        "collections"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'musicDirsChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'tracksChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'collectionsChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onDirectoryChanged'
        QtMocHelpers::SlotData<void(const QString &)>(5, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 6 },
        }}),
        // Slot 'onDebounceTimeout'
        QtMocHelpers::SlotData<void()>(7, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'allGenres'
        QtMocHelpers::MethodData<QStringList() const>(8, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'allArtists'
        QtMocHelpers::MethodData<QStringList() const>(9, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'allAlbums'
        QtMocHelpers::MethodData<QStringList() const>(10, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'addMusicDir'
        QtMocHelpers::MethodData<void(const QString &)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 12 },
        }}),
        // Method 'removeMusicDir'
        QtMocHelpers::MethodData<void(const QString &)>(13, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 12 },
        }}),
        // Method 'saveCollection'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &, const QString &, const QVariantList &)>(14, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 15 }, { QMetaType::QString, 16 }, { QMetaType::QString, 17 }, { QMetaType::QString, 18 },
            { 0x80000000 | 19, 20 },
        }}),
        // Method 'deleteCollection'
        QtMocHelpers::MethodData<void(const QString &)>(21, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 15 },
        }}),
        // Method 'setTrackRating'
        QtMocHelpers::MethodData<void(const QString &, int)>(22, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 }, { QMetaType::Int, 24 },
        }}),
        // Method 'writeTrackTags'
        QtMocHelpers::MethodData<bool(const QString &, const QString &, const QString &, const QString &, const QString &, int, const QString &)>(25, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 26 }, { QMetaType::QString, 27 }, { QMetaType::QString, 28 }, { QMetaType::QString, 29 },
            { QMetaType::QString, 30 }, { QMetaType::Int, 31 }, { QMetaType::QString, 32 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'musicDirs'
        QtMocHelpers::PropertyData<QStringList>(33, QMetaType::QStringList, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'tracks'
        QtMocHelpers::PropertyData<QVariantList>(34, 0x80000000 | 19, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 1),
        // property 'collections'
        QtMocHelpers::PropertyData<QVariantList>(35, 0x80000000 | 19, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 2),
        // property 'allGenres'
        QtMocHelpers::PropertyData<QStringList>(8, QMetaType::QStringList, QMC::DefaultPropertyFlags, 1),
        // property 'allArtists'
        QtMocHelpers::PropertyData<QStringList>(9, QMetaType::QStringList, QMC::DefaultPropertyFlags, 1),
        // property 'allAlbums'
        QtMocHelpers::PropertyData<QStringList>(10, QMetaType::QStringList, QMC::DefaultPropertyFlags, 1),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<Database, qt_meta_tag_ZN8DatabaseE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject Database::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8DatabaseE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8DatabaseE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN8DatabaseE_t>.metaTypes,
    nullptr
} };

void Database::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<Database *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->musicDirsChanged(); break;
        case 1: _t->tracksChanged(); break;
        case 2: _t->collectionsChanged(); break;
        case 3: _t->onDirectoryChanged((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 4: _t->onDebounceTimeout(); break;
        case 5: { QStringList _r = _t->allGenres();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 6: { QStringList _r = _t->allArtists();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 7: { QStringList _r = _t->allAlbums();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 8: _t->addMusicDir((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 9: _t->removeMusicDir((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 10: _t->saveCollection((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[5]))); break;
        case 11: _t->deleteCollection((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 12: _t->setTrackRating((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2]))); break;
        case 13: { bool _r = _t->writeTrackTags((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[6])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[7])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (Database::*)()>(_a, &Database::musicDirsChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (Database::*)()>(_a, &Database::tracksChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (Database::*)()>(_a, &Database::collectionsChanged, 2))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QStringList*>(_v) = _t->musicDirs(); break;
        case 1: *reinterpret_cast<QVariantList*>(_v) = _t->tracksVariant(); break;
        case 2: *reinterpret_cast<QVariantList*>(_v) = _t->collectionsVariant(); break;
        case 3: *reinterpret_cast<QStringList*>(_v) = _t->allGenres(); break;
        case 4: *reinterpret_cast<QStringList*>(_v) = _t->allArtists(); break;
        case 5: *reinterpret_cast<QStringList*>(_v) = _t->allAlbums(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setMusicDirs(*reinterpret_cast<QStringList*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *Database::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *Database::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8DatabaseE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int Database::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 14)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 14;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 14)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 14;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void Database::musicDirsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void Database::tracksChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void Database::collectionsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}
QT_WARNING_POP
