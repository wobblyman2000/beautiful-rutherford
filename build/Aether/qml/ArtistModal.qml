import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#a6000000"
    visible: false
    
    // Slide up/down entry animation
    opacity: visible ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property string activeArtist: ""
    property var primaryAlbums: []
    property var appearsOnAlbums: []

    // Helper functions to filter albums by type
    function getAlbumsByType(type) {
        return primaryAlbums.filter(function(a) {
            return a.albumType === type;
        });
    }

    function loadArtistCatalog(artist) {
        root.activeArtist = artist;
        if (!artist) return;

        var allTracks = database.tracks;
        
        // Group all tracks in the database by album
        var albums = {};
        for (var i = 0; i < allTracks.length; ++i) {
            var t = allTracks[i];
            var albName = t.album || "Unknown Album";
            if (!albums[albName]) {
                albums[albName] = {
                    name: albName,
                    tracks: [],
                    coverPath: "",
                    year: 0,
                    albumType: "Studio Albums",
                    artists: {}
                };
            }
            albums[albName].tracks.push(t);
            if (t.coverPath) albums[albName].coverPath = t.coverPath;
            if (t.year > 0) albums[albName].year = t.year;
            if (t.albumType) albums[albName].albumType = t.albumType;
            
            if (t.artist) {
                albums[albName].artists[t.artist] = true;
            }
        }
        
        // Filter albums for the selected artist
        var primaryList = [];
        var appearsOnList = [];
        
        for (var albName in albums) {
            var alb = albums[albName];
            
            // Check if target artist is in the album's artist list
            var hasTargetArtist = false;
            for (var art in alb.artists) {
                if (art.toLowerCase() === artist.toLowerCase()) {
                    hasTargetArtist = true;
                    break;
                }
            }
            
            if (!hasTargetArtist) continue;
            
            // Count tracks featuring this artist
            var targetTrackCount = 0;
            var totalTrackCount = alb.tracks.length;
            for (var j = 0; j < totalTrackCount; ++j) {
                if ((alb.tracks[j].artist || "").toLowerCase() === artist.toLowerCase()) {
                    targetTrackCount++;
                }
            }
            
            var artistNames = Object.keys(alb.artists);
            var isVarious = (albName.toLowerCase().indexOf("various") !== -1) || 
                             (alb.tracks[0] && (alb.tracks[0].filePath.toLowerCase().indexOf("various") !== -1));
            var isCompilation = (artistNames.length > 2) || (albName.toLowerCase().indexOf("compilation") !== -1) || isVarious;
            
            // Primary if artist has >= 40% of tracks, is the exclusive artist, or it's tagged as a non-compilation
            var isPrimary = (targetTrackCount >= totalTrackCount * 0.4) && (!isCompilation || artistNames.length === 1);
            
            var formattedAlbum = {
                id: artist + "_" + albName,
                name: albName,
                artist: isPrimary ? artist : "Various Artists",
                year: alb.year,
                genre: alb.tracks[0] ? alb.tracks[0].genre : "",
                coverPath: alb.coverPath,
                albumType: alb.albumType,
                tracks: alb.tracks.sort(function(a, b) {
                    if (a.discNo !== b.discNo) return a.discNo - b.discNo;
                    return a.trackNo - b.trackNo;
                }),
                discs: getUniqueDiscs(alb.tracks),
                totalDuration: alb.tracks.reduce(function(acc, val) { return acc + (val.duration || 0); }, 0)
            };
            
            if (isPrimary) {
                primaryList.push(formattedAlbum);
            } else {
                appearsOnList.push(formattedAlbum);
            }
        }
        
        // Sort albums by year (newest first)
        primaryList.sort(function(a, b) { return b.year - a.year; });
        appearsOnList.sort(function(a, b) { return b.year - a.year; });

        root.primaryAlbums = primaryList;
        root.appearsOnAlbums = appearsOnList;
    }
    
    function getUniqueDiscs(tracks) {
        var discs = {};
        for (var i = 0; i < tracks.length; ++i) {
            discs[tracks[i].discNo || 1] = true;
        }
        return Object.keys(discs).map(Number).sort();
    }

    // Modal Content Panel
    Rectangle {
        id: modalContent
        width: 850
        height: parent.height * 0.88
        anchors.centerIn: parent
        color: "#1a1a2a"
        border.color: "#14ffffff"
        radius: 16
        clip: true

        y: root.visible ? (parent.height - height) / 2 : parent.height
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 16

            // Top Header
            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: root.activeArtist
                    color: "#ffffff"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Button {
                    flat: true
                    onClicked: root.visible = false
                    contentItem: Item {
                        width: 16
                        height: 16
                        Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: 45; radius: 1 }
                        Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: -45; radius: 1 }
                    }
                }
            }

            // Scrollable catalog area
            ScrollView {
                id: catalogScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    width: catalogScroll.availableWidth
                    spacing: 24

                    // Primary Album Types Loop
                    Repeater {
                        model: ["Studio Albums", "Singles", "Live Albums", "Compilations"]
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            property var albumsOfThisType: root.getAlbumsByType(modelData)
                            visible: albumsOfThisType.length > 0

                            Text {
                                text: modelData
                                color: "#ffffff"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 16

                                Repeater {
                                    model: parent.parent.albumsOfThisType
                                    delegate: Rectangle {
                                        width: 130
                                        height: 180
                                        color: "transparent"

                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 6

                                            // Album Art
                                            Rectangle {
                                                Layout.preferredWidth: 120
                                                Layout.preferredHeight: 120
                                                color: "#111111"
                                                radius: 8
                                                clip: true
                                                Layout.alignment: Qt.AlignHCenter

                                                Image {
                                                    id: art
                                                    source: modelData.coverPath || ""
                                                    anchors.fill: parent
                                                    fillMode: Image.PreserveAspectCrop
                                                    visible: source != ""
                                                }

                                                Image {
                                                    anchors.centerIn: parent
                                                    source: "image://theme/media-optical"
                                                    width: 40
                                                    height: 40
                                                    visible: art.source == ""
                                                    opacity: 0.3
                                                }
                                            }

                                            // Album Title
                                            Text {
                                                text: modelData.name
                                                color: "#ffffff"
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            // Album Year
                                            Text {
                                                text: modelData.year > 0 ? modelData.year : ""
                                                color: "#9ea2c0"
                                                font.pixelSize: 11
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.visible = false;
                                                window.openAlbum(modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Appears On (Guest / Various Artists Compilation features)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: root.appearsOnAlbums.length > 0

                        Text {
                            text: qsTr("Appears On")
                            color: "#ffffff"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 16

                            Repeater {
                                model: root.appearsOnAlbums
                                delegate: Rectangle {
                                    width: 130
                                    height: 180
                                    color: "transparent"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 6

                                        Rectangle {
                                            Layout.preferredWidth: 120
                                            Layout.preferredHeight: 120
                                            color: "#111111"
                                            radius: 8
                                            clip: true
                                            Layout.alignment: Qt.AlignHCenter

                                            Image {
                                                id: appearsArt
                                                source: modelData.coverPath || ""
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectCrop
                                                visible: source != ""
                                            }

                                            Image {
                                                anchors.centerIn: parent
                                                source: "image://theme/media-optical"
                                                width: 40
                                                height: 40
                                                visible: appearsArt.source == ""
                                                opacity: 0.3
                                            }
                                        }

                                        Text {
                                            text: modelData.name
                                            color: "#ffffff"
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.artist
                                            color: "#9ea2c0"
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.visible = false;
                                            window.openAlbum(modelData);
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
