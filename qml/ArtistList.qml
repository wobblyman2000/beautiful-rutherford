import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // Recompute grouped artists when tracks or search query changes
    property var groupedArtists: computeGroups(database.tracks, window.searchQuery)

    function computeGroups(tracks, query) {
        var queryLower = query.toLowerCase().trim();
        var artistsMap = {};

        // 1. Group tracks by artist -> album
        for (var i = 0; i < tracks.length; ++i) {
            var track = tracks[i];
            var artistName = track.artist || "Unknown Artist";
            var albumName = track.album || "Unknown Album";
            
            var key = artistName.toLowerCase();
            
            var matchesSearch = queryLower === "" ||
                                artistName.toLowerCase().indexOf(queryLower) !== -1 ||
                                albumName.toLowerCase().indexOf(queryLower) !== -1;

            if (!matchesSearch) continue;

            if (!artistsMap[key]) {
                artistsMap[key] = {
                    name: artistName,
                    albums: {},
                    tracks: []
                };
            }

            var albumKey = albumName.toLowerCase();
            if (!artistsMap[key].albums[albumKey]) {
                artistsMap[key].albums[albumKey] = {
                    name: albumName,
                    artist: artistName,
                    coverPath: track.coverPath || "",
                    year: track.year,
                    tracks: []
                };
            }

            if (artistsMap[key].albums[albumKey].coverPath === "" && track.coverPath) {
                artistsMap[key].albums[albumKey].coverPath = track.coverPath;
            }

            artistsMap[key].albums[albumKey].tracks.push(track);
            artistsMap[key].tracks.push(track);
        }

        // 2. Convert albums maps to sorted lists
        var artistsList = [];
        for (var k in artistsMap) {
            var artistObj = artistsMap[k];
            var albumsArr = [];
            
            for (var ak in artistObj.albums) {
                var alb = artistObj.albums[ak];
                
                // Fetch full album details (disc lists, total duration, sorting tracks)
                var discsSet = {};
                for (var t = 0; t < alb.tracks.length; ++t) {
                    discsSet[alb.tracks[t].discNo] = true;
                }
                alb.discs = Object.keys(discsSet).map(Number).sort(function(a, b){ return a - b; });
                alb.totalDuration = alb.tracks.reduce(function(acc, val) { return acc + (val.duration || 0); }, 0);
                alb.tracks.sort(function(a, b) {
                    if (a.discNo !== b.discNo) return a.discNo - b.discNo;
                    if (a.trackNo !== b.trackNo) return a.trackNo - b.trackNo;
                    return (a.title || "").localeCompare(b.title || "");
                });

                albumsArr.push(alb);
            }
            
            albumsArr.sort(function(a, b) { return a.name.localeCompare(b.name); });
            artistObj.albumsList = albumsArr;
            artistsList.push(artistObj);
        }

        // 3. Group artists alphabetically
        var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#".split("");
        var letterGroups = {};
        for (var l = 0; l < alphabet.length; ++l) {
            letterGroups[alphabet[l]] = [];
        }

        for (var a = 0; a < artistsList.length; ++a) {
            var art = artistsList[a];
            var firstChar = (art.name || "").trim().charAt(0).toUpperCase();
            var letter = /[A-Z]/.test(firstChar) ? firstChar : '#';
            if (letterGroups[letter]) {
                letterGroups[letter].push(art);
            } else {
                letterGroups['#'].push(art);
            }
        }

        // 4. Final list model (keep empty check)
        var resultModel = [];
        for (var idx = 0; idx < alphabet.length; ++idx) {
            var char = alphabet[idx];
            var list = letterGroups[char];
            list.sort(function(x, y) { return x.name.localeCompare(y.name); });
            
            resultModel.push({
                letter: char,
                artists: list,
                hasItems: list.length > 0
            });
        }
        return resultModel;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 16

        Text {
            text: qsTr("Artists")
            color: "#ffffff"
            font.pixelSize: 28
            font.weight: Font.Bold
        }

        // Alphabet Bar
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
                    
                    onClicked: artistsListView.positionViewAtBeginning()
                }

                Repeater {
                    model: root.groupedArtists

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
                            for (var idx = 0; idx < root.groupedArtists.length; ++idx) {
                                if (root.groupedArtists[idx].letter === modelData.letter) {
                                    artistsListView.positionViewAtIndex(idx, ListView.Beginning);
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ListView showing letters -> artists -> albums
        ListView {
            id: artistsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 24
            model: root.groupedArtists

            delegate: ColumnLayout {
                width: artistsListView.width
                spacing: 16
                visible: modelData.hasItems
                height: modelData.hasItems ? implicitHeight : 0

                // Letter header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: modelData.letter
                        color: "#00f2fe"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#0dffffff"
                    }
                }

                // List of Artists in this letter group
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    Repeater {
                        model: modelData.artists

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Artist name header
                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true
                                
                                Image {
                                    source: "image://theme/user-identity"
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    opacity: 0.8
                                }

                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true

                                    MouseArea {
                                        anchors.fill: parent
                                        onDoubleClicked: {
                                            player.setQueue(modelData.tracks, 0);
                                        }
                                    }
                                }
                            }

                            // Albums by this artist
                            Flow {
                                Layout.fillWidth: true
                                spacing: 18
                                anchors.leftMargin: 26

                                Repeater {
                                    model: modelData.albumsList

                                    delegate: Rectangle {
                                        width: 150
                                        height: 200
                                        color: "#73191928"
                                        border.color: albMouse.containsMouse ? "#1effffff" : "#12ffffff"
                                        radius: 12
                                        clip: true

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            Rectangle {
                                                Layout.preferredWidth: 134
                                                Layout.preferredHeight: 134
                                                color: "#111111"
                                                radius: 8
                                                clip: true
                                                Layout.alignment: Qt.AlignHCenter

                                                Image {
                                                    id: artAlbumCover
                                                    source: modelData.coverPath
                                                    anchors.fill: parent
                                                    fillMode: Image.PreserveAspectCrop
                                                    visible: modelData.coverPath !== ""
                                                }

                                                Image {
                                                    anchors.centerIn: parent
                                                    source: "image://theme/media-optical"
                                                    width: 40
                                                    height: 40
                                                    visible: artAlbumCover.source == ""
                                                    opacity: 0.5
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: "#80000000"
                                                    opacity: albMouse.containsMouse ? 1.0 : 0.0
                                                    visible: opacity > 0.0

                                                    Button {
                                                        id: artistPlayBtn
                                                        width: 36
                                                        height: 36
                                                        anchors.centerIn: parent
                                                        flat: true
                                                        
                                                        background: Rectangle {
                                                            color: "#00f2fe"
                                                            radius: width / 2
                                                        }

                                                        contentItem: Image {
                                                            source: "image://theme/media-playback-start"
                                                            anchors.centerIn: parent
                                                            width: 14
                                                            height: 14
                                                        }

                                                        onClicked: player.setQueue(modelData.tracks, 0)
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.name
                                                color: "#ffffff"
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: (modelData.year > 0 ? modelData.year + " • " : "") + modelData.tracks.length + " track" + (modelData.tracks.length === 1 ? "" : "s")
                                                color: "#9ea2c0"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: albMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                var relativePos = mapToItem(artistPlayBtn, mouse.x, mouse.y);
                                                if (artistPlayBtn.contains(relativePos)) {
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
        }
    }
}
