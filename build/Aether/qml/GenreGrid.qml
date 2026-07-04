import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var groupedGenres: computeGroups(database.tracks, window.searchQuery)

    function computeGroups(tracks, query) {
        var queryLower = query.toLowerCase().trim();
        var genresMap = {};

        // 1. Group tracks by genre (split by comma)
        for (var i = 0; i < tracks.length; ++i) {
            var track = tracks[i];
            if (!track.genre) continue;

            var genres = track.genre.split(",");
            for (var g = 0; g < genres.length; ++g) {
                var genreName = genres[g].trim();
                if (genreName === "") continue;
                
                var key = genreName.toLowerCase();
                var matchesSearch = queryLower === "" || key.indexOf(queryLower) !== -1;

                if (!matchesSearch) continue;

                if (!genresMap[key]) {
                    genresMap[key] = {
                        name: genreName,
                        tracks: []
                    };
                }

                genresMap[key].tracks.push(track);
            }
        }

        // 2. Compute list of genres
        var genresList = [];
        for (var k in genresMap) {
            var gen = genresMap[k];
            // Sort tracks
            gen.tracks.sort(function(a, b) {
                return (a.title || "").localeCompare(b.title || "");
            });
            // Try to find a cover image for the genre card
            gen.coverPath = "";
            for (var t = 0; t < gen.tracks.length; ++t) {
                if (gen.tracks[t].coverPath) {
                    gen.coverPath = gen.tracks[t].coverPath;
                    break;
                }
            }
            genresList.push(gen);
        }

        // 3. Group alphabetically
        var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#".split("");
        var letterGroups = {};
        for (var l = 0; l < alphabet.length; ++l) {
            letterGroups[alphabet[l]] = [];
        }

        for (var idx = 0; idx < genresList.length; ++idx) {
            var genreObj = genresList[idx];
            var firstChar = (genreObj.name || "").trim().charAt(0).toUpperCase();
            var letter = /[A-Z]/.test(firstChar) ? firstChar : '#';
            if (letterGroups[letter]) {
                letterGroups[letter].push(genreObj);
            } else {
                letterGroups['#'].push(genreObj);
            }
        }

        // 4. Final model list
        var resultModel = [];
        for (var j = 0; j < alphabet.length; ++j) {
            var char = alphabet[j];
            var list = letterGroups[char];
            list.sort(function(x, y) { return x.name.localeCompare(y.name); });
            
            resultModel.push({
                letter: char,
                genres: list,
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
            text: qsTr("Genres")
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
                    
                    onClicked: genresListView.positionViewAtBeginning()
                }

                Repeater {
                    model: root.groupedGenres

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
                            for (var idx = 0; idx < root.groupedGenres.length; ++idx) {
                                if (root.groupedGenres[idx].letter === modelData.letter) {
                                    genresListView.positionViewAtIndex(idx, ListView.Beginning);
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ListView of A-Z groups of genres
        ListView {
            id: genresListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 24
            model: root.groupedGenres

            delegate: ColumnLayout {
                width: genresListView.width
                spacing: 12
                visible: modelData.hasItems
                height: modelData.hasItems ? implicitHeight : 0

                // Header
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

                // Grid of Genres
                Flow {
                    Layout.fillWidth: true
                    spacing: 24

                    Repeater {
                        model: modelData.genres

                        delegate: Rectangle {
                            width: 170
                            height: 220
                            color: "#73191928"
                            border.color: genreMouse.containsMouse ? "#1effffff" : "#12ffffff"
                            radius: 16
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Cover
                                Rectangle {
                                    Layout.preferredWidth: 150
                                    Layout.preferredHeight: 150
                                    color: "#111111"
                                    radius: 12
                                    clip: true
                                    Layout.alignment: Qt.AlignHCenter

                                    Image {
                                        id: genreCover
                                        source: modelData.coverPath
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.coverPath !== ""
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        source: "image://theme/tag"
                                        width: 50
                                        height: 50
                                        visible: genreCover.source == ""
                                        opacity: 0.5
                                    }

                                    // Quick play overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#80000000"
                                        opacity: genreMouse.containsMouse ? 1.0 : 0.0
                                        visible: opacity > 0.0

                                        Button {
                                            id: genrePlayBtn
                                            width: 44
                                            height: 44
                                            anchors.centerIn: parent
                                            flat: true
                                            
                                            background: Rectangle {
                                                color: "#00f2fe"
                                                radius: width / 2
                                            }

                                            contentItem: Image {
                                                source: "image://theme/media-playback-start"
                                                anchors.centerIn: parent
                                                width: 18
                                                height: 18
                                            }

                                            onClicked: player.setQueue(modelData.tracks, 0)
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.tracks.length + " track" + (modelData.tracks.length === 1 ? "" : "s")
                                    color: "#9ea2c0"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: genreMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var relativePos = mapToItem(genrePlayBtn, mouse.x, mouse.y);
                                    if (genrePlayBtn.contains(relativePos)) {
                                        return;
                                    }
                                    
                                    // Open in Details Modal (mock as an album)
                                    var mockAlbum = {
                                        id: "genre-" + modelData.name.toLowerCase(),
                                        name: modelData.name,
                                        artist: qsTr("Genre View"),
                                        year: 0,
                                        genre: "",
                                        coverPath: modelData.coverPath,
                                        tracks: modelData.tracks,
                                        discs: [1],
                                        totalDuration: modelData.tracks.reduce(function(acc, val) { return acc + (val.duration || 0); }, 0)
                                    };
                                    window.openAlbum(mockAlbum);
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
