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
            Layout.preferredHeight: 90
        }
    }

    // Global Album Details Modal Overlay
    AlbumModal {
        id: albumModal
        anchors.fill: parent
    }
    
    // Method to trigger album modal opening from child views
    function openAlbum(albumObj) {
        albumModal.openAlbum(albumObj);
    }
}
