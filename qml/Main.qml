import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

ApplicationWindow {
    id: window
    width: 1100
    height: 720
    visible: true
    visibility: isTheaterMode ? ApplicationWindow.FullScreen : (window.isCompactMode ? ApplicationWindow.Windowed : ApplicationWindow.Maximized)
    title: qsTr("Aether Player")
    
    // Global properties
    property string activePage: "albums"
    property string searchQuery: ""
    property bool isCompactMode: false
    property bool isTheaterMode: false
    property bool autoTheaterEnabled: false

    onAutoTheaterEnabledChanged: {
        if (!autoTheaterEnabled) {
            inactivityTimer.stop();
        } else {
            inactivityTimer.restart();
        }
    }
    onClosing: (close) => {
        // HUMAN-READABLE COMMENT:
        // Intercept the close event to keep the application running in the system tray.
        // Hiding the main window allows background playback to continue uninterrupted.
        if (systemTray.visible) {
            close.accepted = false;
            window.hide();
        }
    }

    SystemTrayIcon {
        id: systemTray
        visible: true
        icon.name: "media-optical"
        tooltip: qsTr("Aether Player")

        onActivated: (reason) => {
            if (reason === SystemTrayIcon.Trigger || reason === SystemTrayIcon.DoubleClick) {
                window.show();
                window.raise();
                window.requestActivate();
            }
        }

        menu: Menu {
            MenuItem {
                text: qsTr("Play / Pause")
                onTriggered: player.togglePlay()
            }
            MenuItem {
                text: qsTr("Next Track")
                onTriggered: player.next()
            }
            MenuItem {
                text: qsTr("Previous Track")
                onTriggered: player.previous()
            }
            MenuSeparator {}
            MenuItem {
                text: qsTr("Show Aether")
                onTriggered: {
                    window.show();
                    window.raise();
                    window.requestActivate();
                }
            }
            MenuItem {
                text: qsTr("Quit")
                onTriggered: {
                    systemTray.visible = false;
                    Qt.quit();
                }
            }
        }
    }
    onIsCompactModeChanged: {
        if (isCompactMode) {
            window.isTheaterMode = false;
            window.width = 360;
            window.height = 130;
        } else {
            window.width = 1100;
            window.height = 720;
        }
    }

    // Global User Inactivity Monitor (1-minute timer)
    Timer {
        id: inactivityTimer
        interval: 60000 // 1 minute inactivity
        running: window.autoTheaterEnabled && !window.isTheaterMode && !window.isCompactMode
        repeat: false
        onTriggered: {
            // HUMAN-READABLE COMMENT:
            // When the inactivity timer expires, automatically transition the application
            // into Theater Mode to display full-screen ambient visuals.
            window.isTheaterMode = true;
        }
    }

    // Transparent event listener covering the window to detect interactions and reset the inactivity timer
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        hoverEnabled: true
        // Position on top of normal controls, but let everything propagate down
        z: 9999
        // Do not block actual mouse clicks on other components
        onPressed: (mouse) => {
            inactivityTimer.restart();
            mouse.accepted = false;
        }
        onReleased: (mouse) => {
            inactivityTimer.restart();
            mouse.accepted = false;
        }
        onPositionChanged: (mouse) => {
            inactivityTimer.restart();
            mouse.accepted = false;
        }
    }

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1a2e" }
            GradientStop { position: 1.0; color: "#0d0d15" }
        }
    }

    // Main layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            visible: !window.isCompactMode

            // Left Sidebar
            Sidebar {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: 240
            }

            // Right Main Content Panel
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Header Search Row
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    color: "#330d0d15"
                    border.color: "#0dffffff"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 30
                        anchors.rightMargin: 30
                        spacing: 12

                        // Search Input
                        Rectangle {
                            Layout.preferredWidth: 320
                            Layout.preferredHeight: 38
                            color: "#0affffff"
                            border.color: "#14ffffff"
                            border.width: 1
                            radius: 10

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Image {
                                    source: "image://theme/edit-find"
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    opacity: 0.6
                                }

                                TextField {
                                    id: searchField
                                    placeholderText: qsTr("Search albums, artists, genres...")
                                    Layout.fillWidth: true
                                    background: null
                                    color: "#ffffff"
                                    placeholderTextColor: "#666a8a"
                                    font.pixelSize: 14
                                    onTextChanged: window.searchQuery = text
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Scanner status
                        RowLayout {
                            visible: scanner.scanning
                            spacing: 8

                            BusyIndicator {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }

                            Text {
                                text: qsTr("Scanning library...")
                                color: "#00f2fe"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // Main Views Stack (Visiblity toggles)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    AlbumGrid {
                        anchors.fill: parent
                        visible: window.activePage === "albums"
                    }

                    ArtistList {
                        anchors.fill: parent
                        visible: window.activePage === "artists"
                    }

                    GenreGrid {
                        anchors.fill: parent
                        visible: window.activePage === "genres"
                    }

                    CollectionGrid {
                        anchors.fill: parent
                        visible: window.activePage === "collections"
                    }

                    // Auto-DJ Dashboard Page
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 30
                        spacing: 24
                        visible: window.activePage === "autodj"

                        // Left Pane: Filters & Configuration
                        Rectangle {
                            Layout.preferredWidth: 360
                            Layout.fillHeight: true
                            color: "#73191928"
                            border.color: "#14ffffff"
                            border.width: 1
                            radius: 16

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 16

                                Text {
                                    text: qsTr("Auto-DJ Settings")
                                    color: "#ffffff"
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Switch {
                                        id: autoDJViewSwitch
                                        checked: player.autoDJ
                                        onCheckedChanged: player.autoDJ = checked
                                    }
                                    Text {
                                        text: qsTr("Enable Auto-DJ")
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#14ffffff"
                                }

                                Text {
                                    text: qsTr("Queue Filter Rules")
                                    color: "#00f2fe"
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }

                                // Genre Filter
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { text: qsTr("Filter by Genre"); color: "#9ea2c0"; font.pixelSize: 12 }
                                    ComboBox {
                                        id: filterGenreCombo
                                        Layout.fillWidth: true
                                        model: {
                                            var list = [""];
                                            var dbGenres = database.allGenres;
                                            if (dbGenres) {
                                                for (var i = 0; i < dbGenres.length; ++i) {
                                                    list.push(dbGenres[i]);
                                                }
                                            }
                                            return list;
                                        }
                                        currentIndex: {
                                            var idx = model ? model.indexOf(player.autoDJGenre) : -1;
                                            return idx >= 0 ? idx : 0;
                                        }
                                        onActivated: (index) => {
                                            player.autoDJGenre = model[index];
                                        }
                                    }
                                }

                                // Artist Filter
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { text: qsTr("Filter by Artist"); color: "#9ea2c0"; font.pixelSize: 12 }
                                    TextField {
                                        id: filterArtist
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("e.g. ABBA, Queen")
                                        text: player.autoDJArtist
                                        color: "#ffffff"
                                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                                        onEditingFinished: player.autoDJArtist = text.trim()
                                    }
                                }

                                // Album Artist Filter
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { text: qsTr("Filter by Album Artist"); color: "#9ea2c0"; font.pixelSize: 12 }
                                    TextField {
                                        id: filterAlbumArtist
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("e.g. Various Artists")
                                        text: player.autoDJAlbumArtist
                                        color: "#ffffff"
                                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                                        onEditingFinished: player.autoDJAlbumArtist = text.trim()
                                    }
                                }

                                Button {
                                    text: qsTr("Reset Filters")
                                    Layout.fillWidth: true
                                    onClicked: {
                                        filterGenreCombo.currentIndex = 0;
                                        filterArtist.text = "";
                                        filterAlbumArtist.text = "";
                                        player.autoDJGenre = "";
                                        player.autoDJArtist = "";
                                        player.autoDJAlbumArtist = "";
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // Right Pane: Minimal Queue Inspector
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#73191928"
                            border.color: "#14ffffff"
                            border.width: 1
                            radius: 16

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: qsTr("Current Queue List")
                                        color: "#ffffff"
                                        font.pixelSize: 20
                                        font.weight: Font.Bold
                                    }
                                    Item { Layout.fillWidth: true }
                                    Button {
                                        text: qsTr("Clear Queue")
                                        flat: true
                                        contentItem: Text { text: qsTr("Clear Queue"); color: "#ff5555"; font.weight: Font.Bold }
                                        onClicked: player.clearQueue()
                                    }
                                }

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    ListView {
                                        id: queueListView
                                        model: player.queue
                                        spacing: 4

                                        delegate: Rectangle {
                                            width: queueListView.width
                                            height: 48
                                            color: index === player.queueIndex ? "#1a00f2fe" : (queueMouse.containsMouse ? "#0dffffff" : "transparent")
                                            border.color: index === player.queueIndex ? "#4000f2fe" : "transparent"
                                            radius: 8

                                            MouseArea {
                                                id: queueMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onDoubleClicked: {
                                                    player.setQueue(player.queue, index);
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 12

                                                Text {
                                                    text: (index + 1).toString()
                                                    color: index === player.queueIndex ? "#00f2fe" : "#666a8a"
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    Layout.preferredWidth: 20
                                                }

                                                Rectangle {
                                                    width: 32
                                                    height: 32
                                                    radius: 4
                                                    color: "#111111"
                                                    clip: true

                                                    Image {
                                                        source: modelData.coverPath || ""
                                                        anchors.fill: parent
                                                        fillMode: Image.PreserveAspectCrop
                                                        visible: source !== ""
                                                    }

                                                    Image {
                                                        anchors.centerIn: parent
                                                        source: "image://theme/media-optical"
                                                        width: 16
                                                        height: 16
                                                        visible: !modelData.coverPath
                                                        opacity: 0.4
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text {
                                                        text: modelData.title || qsTr("Unknown Track")
                                                        color: index === player.queueIndex ? "#00f2fe" : "#ffffff"
                                                        font.pixelSize: 13
                                                        font.weight: Font.Medium
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: modelData.artist || qsTr("Unknown Artist")
                                                        color: index === player.queueIndex ? "#7ae6ff" : "#9ea2c0"
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Text {
                                                    text: playerBar.formatTime(modelData.duration)
                                                    color: index === player.queueIndex ? "#00f2fe" : "#666a8a"
                                                    font.pixelSize: 12
                                                }

                                                Button {
                                                    flat: true
                                                    Layout.preferredWidth: 32
                                                    Layout.preferredHeight: 32
                                                    onClicked: player.removeQueueIndex(index)
                                                    contentItem: Text {
                                                        text: "✕"
                                                        color: "#ff5555"
                                                        font.bold: true
                                                        font.pixelSize: 14
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Settings View
                    ScrollView {
                        id: settingsScrollView
                        anchors.fill: parent
                        anchors.margins: 30
                        visible: window.activePage === "settings"
                        clip: true

                        ColumnLayout {
                            width: settingsScrollView.availableWidth
                            spacing: 20

                            Text {
                                text: qsTr("Settings")
                                color: "#ffffff"
                                font.pixelSize: 28
                                font.weight: Font.Bold
                            }

                            // Folders Card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: cardLayout.implicitHeight + 40
                                color: "#73191928"
                                border.color: "#14ffffff"
                                border.width: 1
                                radius: 16

                                ColumnLayout {
                                    id: cardLayout
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 16

                                    Text {
                                        text: qsTr("Music Library Folders")
                                        color: "#ffffff"
                                        font.pixelSize: 18
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        text: qsTr("Add folders containing your audio files. Aether will index them and parse their metadata.")
                                        color: "#9ea2c0"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                    }

                                    // Add Folder Row
                                    RowLayout {
                                        spacing: 12
                                        Layout.fillWidth: true

                                        TextField {
                                            id: folderInput
                                            placeholderText: qsTr("e.g. /home/user/Music")
                                            Layout.fillWidth: true
                                            color: "#ffffff"
                                            background: Rectangle {
                                                color: "#33000000"
                                                border.color: "#14ffffff"
                                                radius: 8
                                            }
                                        }

                                        Button {
                                            text: qsTr("Add Folder")
                                            onClicked: {
                                                if (folderInput.text.trim()) {
                                                    database.addMusicDir(folderInput.text.trim());
                                                    folderInput.text = "";
                                                }
                                            }
                                        }
                                    }

                                    // Directories list (using Column + Repeater to allow natural expanding height)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: database.musicDirs
                                            delegate: Rectangle {
                                                Layout.fillWidth: true
                                                height: 44
                                                color: "#05ffffff"
                                                border.color: "#14ffffff"
                                                border.width: 1
                                                radius: 8

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12

                                                    Text {
                                                        text: modelData
                                                        color: "#9ea2c0"
                                                        font.family: "monospace"
                                                        font.pixelSize: 13
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideMiddle
                                                    }

                                                    Button {
                                                        icon.name: "edit-delete"
                                                        flat: true
                                                        icon.color: "#ff5555"
                                                        onClicked: database.removeMusicDir(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Action line separator
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#14ffffff"
                                    }

                                    // Action controls
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Text {
                                            text: scanner.scanning ? qsTr("Scanner is actively indexing tracks...") : qsTr("Library up to date.")
                                            color: scanner.scanning ? "#00f2fe" : "#666a8a"
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            Layout.fillWidth: true
                                        }

                                        Button {
                                            text: qsTr("Scan Library Now")
                                            onClicked: scanner.startScan()
                                        }
                                    }
                                }
                            }

                            // Preferences & Version Info Card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: prefLayout.implicitHeight + 40
                                color: "#73191928"
                                border.color: "#14ffffff"
                                border.width: 1
                                radius: 16

                                ColumnLayout {
                                    id: prefLayout
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 16

                                    Text {
                                        text: qsTr("Preferences")
                                        color: "#ffffff"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                    }

                                    // Switch for Auto-Theater Mode
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Switch {
                                            id: autoTheaterSwitch
                                            checked: window.autoTheaterEnabled
                                            onCheckedChanged: window.autoTheaterEnabled = checked
                                        }

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: qsTr("Auto Theater Mode on Inactivity")
                                                color: "#ffffff"
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                            }
                                            Text {
                                                text: qsTr("Automatically switch to Theater Mode if the player is inactive for 1 minute.")
                                                color: "#666a8a"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }

                                    // Action line separator
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#14ffffff"
                                    }

                                    // Version Info
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: qsTr("Aether Player — Version 1.1.0")
                                                color: "#00f2fe"
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                            }
                                            Text {
                                                text: qsTr("Copyright © 2026 Aether Development Team. All rights reserved.")
                                                color: "#666a8a"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Player Controller
        PlayerBar {
            id: playerBar
            Layout.fillWidth: true
            Layout.preferredHeight: window.isCompactMode ? 130 : 90
        }
    }

    // Global Album Details Modal Overlay
    AlbumModal {
        id: albumModal
        anchors.fill: parent
    }

    // Global Artist Details Modal Overlay
    ArtistModal {
        id: artistModal
        anchors.fill: parent
    }
    
    // Method to trigger album modal opening from child views
    function openAlbum(albumObj) {
        albumModal.openAlbum(albumObj);
    }

    // Method to trigger artist modal opening from child views
    function openArtist(artistName) {
        artistModal.loadArtistCatalog(artistName);
        artistModal.visible = true;
    }

    // Shortcut to exit Theater or Compact Mode using Escape
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (window.isTheaterMode) window.isTheaterMode = false;
            if (window.isCompactMode) window.isCompactMode = false;
        }
    }

    // Theater Mode Overlay
    Rectangle {
        id: theaterOverlay
        anchors.fill: parent
        color: "#12121c"
        visible: window.isTheaterMode
        z: 999 // Overlays everything!

        property bool showControls: true

        Timer {
            id: controlsTimer
            interval: 3000
            running: window.isTheaterMode
            repeat: false
            onTriggered: theaterOverlay.showControls = false
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: theaterOverlay.showControls ? Qt.ArrowCursor : Qt.BlankCursor
            onPositionChanged: {
                theaterOverlay.showControls = true;
                controlsTimer.restart();
            }
            onClicked: {
                theaterOverlay.showControls = true;
                controlsTimer.restart();
            }
        }

        // Ambient Background (low opacity album art over gradient)
        Image {
            id: theaterAmbientBg
            source: player.currentTrack.coverPath || ""
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0.15
            visible: source !== ""
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#cc000000" }
            }
        }

        // Close Button
        Button {
            visible: theaterOverlay.showControls
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 24
            flat: true
            onClicked: window.isTheaterMode = false
            contentItem: Item {
                width: 16
                height: 16
                Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: 45; radius: 1 }
                Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: -45; radius: 1 }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 500)
            spacing: 24
            Layout.alignment: Qt.AlignCenter

            // Album Art
            Rectangle {
                Layout.preferredWidth: 260
                Layout.preferredHeight: 260
                color: "#111111"
                radius: 16
                Layout.alignment: Qt.AlignHCenter
                clip: true

                Image {
                    source: player.currentTrack.coverPath || ""
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                }

                Image {
                    anchors.centerIn: parent
                    source: "image://theme/media-optical"
                    width: 80
                    height: 80
                    visible: !player.currentTrack.coverPath
                    opacity: 0.4
                }
            }

            // Track details
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Layout.alignment: Qt.AlignHCenter

                Text {
                    text: player.currentTrack.title || qsTr("Not Playing")
                    color: "#ffffff"
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: (player.currentTrack.artist || "") + ((player.currentTrack.album) ? " — " + player.currentTrack.album : "")
                    color: "#a0a4c5"
                    font.pixelSize: 16
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Scrubber
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Slider {
                    id: theaterScrubber
                    Layout.fillWidth: true
                    from: 0
                    to: player.duration > 0 ? player.duration : 1
                    value: player.position
                    onMoved: player.setPosition(value)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: playerBar.formatTime(player.position)
                        color: "#9ea2c0"
                        font.pixelSize: 12
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: playerBar.formatTime(player.duration)
                        color: "#9ea2c0"
                        font.pixelSize: 12
                    }
                }
            }

            // Playback buttons
            RowLayout {
                spacing: 24
                Layout.alignment: Qt.AlignHCenter

                Button {
                    flat: true
                    onClicked: player.previous()
                    contentItem: Item {
                        width: 24
                        height: 24
                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            Rectangle { width: 3; height: 12; color: "#ffffff"; radius: 1 }
                            Canvas {
                                width: 9; height: 12
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset(); ctx.fillStyle = "#ffffff";
                                    ctx.beginPath(); ctx.moveTo(width, 0); ctx.lineTo(0, height/2); ctx.lineTo(width, height); ctx.closePath(); ctx.fill();
                                }
                            }
                        }
                    }
                }

                Button {
                    width: 54
                    height: 54
                    flat: true
                    background: Rectangle {
                        color: "#ffffff"
                        radius: width / 2
                    }
                    contentItem: Item {
                        anchors.fill: parent
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: player.playbackStatus === "Playing"
                            Rectangle { width: 5; height: 20; color: "#1a1a2a"; radius: 1 }
                            Rectangle { width: 5; height: 20; color: "#1a1a2a"; radius: 1 }
                        }
                        Canvas {
                            anchors.centerIn: parent
                            width: 16
                            height: 18
                            visible: player.playbackStatus !== "Playing"
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.fillStyle = "#1a1a2a";
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                ctx.lineTo(width, height / 2);
                                ctx.lineTo(0, height);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }
                    onClicked: player.togglePlay()
                }

                Button {
                    flat: true
                    onClicked: player.next()
                    contentItem: Item {
                        width: 24
                        height: 24
                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            Canvas {
                                width: 9; height: 12
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset(); ctx.fillStyle = "#ffffff";
                                    ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(width, height/2); ctx.lineTo(0, height); ctx.closePath(); ctx.fill();
                                }
                            }
                            Rectangle { width: 3; height: 12; color: "#ffffff"; radius: 1 }
                        }
                    }
                }
            }
        }
    }
}
