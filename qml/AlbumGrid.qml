import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // Recompute grouped albums when tracks change or search query changes
    property var groupedAlbums: computeGroups(database.tracks, window.searchQuery)

    // JS helper to group albums alphabetically
    function computeGroups(tracks, query) {
        var queryLower = query.toLowerCase().trim();
        var albumsMap = {};

        // 1. Group tracks by Album + Artist
        for (var i = 0; i < tracks.length; ++i) {
            var track = tracks[i];
            var albumName = track.album || "Unknown Album";
            var artist = track.artist || "Unknown Artist";
            var key = (albumName + "::" + artist).toLowerCase();

            // Search filter
            var matchesSearch = queryLower === "" ||
                                albumName.toLowerCase().indexOf(queryLower) !== -1 ||
                                artist.toLowerCase().indexOf(queryLower) !== -1 ||
                                (track.title && track.title.toLowerCase().indexOf(queryLower) !== -1);

            if (!matchesSearch) continue;

            if (!albumsMap[key]) {
                albumsMap[key] = {
                    name: albumName,
                    artist: artist,
                    year: track.year,
                    genre: track.genre,
                    coverPath: track.coverPath || "",
                    tracks: []
                };
            }

            if (albumsMap[key].coverPath === "" && track.coverPath) {
                albumsMap[key].coverPath = track.coverPath;
            }
            if (albumsMap[key].year === 0 && track.year > 0) {
                albumsMap[key].year = track.year;
            }

            albumsMap[key].tracks.push(track);
        }

        // 2. Sort tracks inside albums and compute CD list
        var albumsList = [];
        for (var k in albumsMap) {
            var album = albumsMap[k];
            // Sort tracks by disc, track number, title
            album.tracks.sort(function(a, b) {
                if (a.discNo !== b.discNo) return a.discNo - b.discNo;
                if (a.trackNo !== b.trackNo) return a.trackNo - b.trackNo;
                return (a.title || "").localeCompare(b.title || "");
            });

            var discsSet = {};
            for (var t = 0; t < album.tracks.length; ++t) {
                discsSet[album.tracks[t].discNo] = true;
            }
            album.discs = Object.keys(discsSet).map(Number).sort(function(a, b){ return a - b; });
            album.totalDuration = album.tracks.reduce(function(acc, val) { return acc + (val.duration || 0); }, 0);
            
            albumsList.push(album);
        }

        // 3. Group albums alphabetically by starting letter
        var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#".split("");
        var letterGroups = {};
        for (var l = 0; l < alphabet.length; ++l) {
            letterGroups[alphabet[l]] = [];
        }

        for (var a = 0; a < albumsList.length; ++a) {
            var alb = albumsList[a];
            var firstChar = (alb.name || "").trim().charAt(0).toUpperCase();
            var letter = /[A-Z]/.test(firstChar) ? firstChar : '#';
            if (letterGroups[letter]) {
                letterGroups[letter].push(alb);
            } else {
                letterGroups['#'].push(alb);
            }
        }

        // 4. Convert to list model format (only keep letters with items to prevent scroll jitter)
        var resultModel = [];
        for (var idx = 0; idx < alphabet.length; ++idx) {
            var char = alphabet[idx];
            var list = letterGroups[char];
            if (list.length === 0) continue;
            
            // Sort albums alphabetically
            list.sort(function(x, y) { return x.name.localeCompare(y.name); });
            
            resultModel.push({
                letter: char,
                albums: list,
                hasItems: true
            });
        }
        return resultModel;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 16

        // Page title
        Text {
            text: qsTr("Albums")
            color: "#ffffff"
            font.pixelSize: 28
            font.weight: Font.Bold
        }

        // A-Z Alphabetical Index Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "#05ffffff"
            border.color: "#0dffffff"
            border.width: 1
            radius: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 2

                // "All" button
                Button {
                    text: "All"
                    flat: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 28
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#00f2fe"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        color: "#1e00f2fe"
                        border.color: "#4000f2fe"
                        radius: 6
                    }
                    
                    onClicked: albumsListView.positionViewAtBeginning()
                }

                // A-Z Letters
                Repeater {
                    model: root.groupedAlbums

                    delegate: Button {
                        text: modelData.letter
                        flat: true
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        enabled: modelData.hasItems

                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "#9ea2c0" : "#44465a"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: parent.hovered ? "#0dffffff" : "transparent"
                            radius: 6
                        }

                        onClicked: {
                            // Find index of this letter's group in ListView
                            for (var idx = 0; idx < root.groupedAlbums.length; ++idx) {
                                if (root.groupedAlbums[idx].letter === modelData.letter) {
                                    albumsListView.positionViewAtIndex(idx, ListView.Beginning);
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // List of groups (A-Z)
        ListView {
            id: albumsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 24
            model: root.groupedAlbums

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: ColumnLayout {
                width: albumsListView.width
                spacing: 12
                visible: modelData.hasItems
                // Ensure height collapses to 0 if no items to prevent layout gaps
                height: modelData.hasItems ? implicitHeight : 0

                // Group Section Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: modelData.letter
                        color: "#00f2fe"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        
                        layer.enabled: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#0dffffff"
                    }
                }

                // Grid of Albums inside the letter group
                Flow {
                    Layout.fillWidth: true
                    spacing: 24

                    Repeater {
                        model: modelData.albums

                        delegate: Rectangle {
                            width: 170
                            height: 230
                            color: "#73191928"
                            border.color: cardMouseArea.containsMouse ? "#1effffff" : "#12ffffff"
                            radius: 16
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Cover art wrapper
                                Rectangle {
                                    Layout.preferredWidth: 150
                                    Layout.preferredHeight: 150
                                    color: "#111111"
                                    radius: 12
                                    clip: true
                                    Layout.alignment: Qt.AlignHCenter

                                    Image {
                                        id: albumCover
                                        source: modelData.coverPath
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.coverPath !== ""
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        source: "image://theme/media-optical"
                                        width: 50
                                        height: 50
                                        visible: albumCover.source == ""
                                        opacity: 0.5
                                    }

                                    // Multi-CD badge
                                    Rectangle {
                                        visible: modelData.discs.length > 1
                                        color: "#a6000000"
                                        border.color: "#1affffff"
                                        radius: 10
                                        width: 48
                                        height: 20
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8

                                        Text {
                                            text: modelData.discs.length + " CDs"
                                            color: "#00f2fe"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            anchors.centerIn: parent
                                        }
                                    }

                                    // Quick play overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#80000000"
                                        opacity: cardMouseArea.containsMouse ? 1.0 : 0.0
                                        visible: opacity > 0.0
                                        
                                        Behavior on opacity { NumberAnimation { duration: 200 } }

                                        Button {
                                            id: quickPlayBtn
                                            width: 44
                                            height: 44
                                            anchors.centerIn: parent
                                            flat: true
                                            
                                            background: Rectangle {
                                                color: "#00f2fe"
                                                radius: width / 2
                                            }

                                            contentItem: Item {
                                                anchors.fill: parent
                                                Canvas {
                                                    anchors.centerIn: parent
                                                    width: 11
                                                    height: 13
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

                                            onClicked: {
                                                // Convert variant array to QVariantList to set queue
                                                player.setQueue(modelData.tracks, 0);
                                            }
                                        }
                                    }
                                }

                                // Text details
                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.artist
                                    color: "#9ea2c0"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                
                                onClicked: {
                                    // Make sure we didn't click the quick play overlay button
                                    var relativePos = mapToItem(quickPlayBtn, mouse.x, mouse.y);
                                    if (quickPlayBtn.contains(relativePos)) {
                                        return;
                                    }
                                    window.openAlbum(modelData);
                                }

                                onDoubleClicked: {
                                    player.setQueue(modelData.tracks, 0);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
