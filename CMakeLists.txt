cmake_minimum_required(VERSION 3.16)

project(aether VERSION 1.3.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find Qt6 components
find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Multimedia
    DBus
    Widgets
)

# Find TagLib using PkgConfig
find_package(PkgConfig REQUIRED)
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)

# Add native executable
qt_add_executable(aether
    src/main.cpp
    src/database.h src/database.cpp
    src/scanner.h src/scanner.cpp
    src/player.h src/player.cpp
    src/mpris.h src/mpris.cpp
)

# Register QML Module
qt_add_qml_module(aether
    URI Aether
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Sidebar.qml
        qml/PlayerBar.qml
        qml/AlbumGrid.qml
        qml/ArtistList.qml
        qml/GenreGrid.qml
        qml/CollectionGrid.qml
        qml/AlbumModal.qml
        qml/ArtistModal.qml
        qml/LyricsVisualizer.qml
)

# Link libraries
target_link_libraries(aether PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
    Qt6::DBus
    Qt6::Widgets
    PkgConfig::TAGLIB
)

# Set compile definitions
target_compile_definitions(aether PRIVATE
    PROJECT_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)
