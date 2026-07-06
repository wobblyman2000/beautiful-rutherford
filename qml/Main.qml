import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: window
    width: 1100
    height: 720
    visible: true
    title: qsTr("Aether Player")
    
    // Global properties
    property string activePage: "albums"
    property string searchQuery: ""
    property bool isCompactMode: false
    property bool isTheaterMode: false

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
