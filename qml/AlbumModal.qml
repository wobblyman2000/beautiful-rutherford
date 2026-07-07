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

    property var activeAlbum: null
    property var parentAlbum: null
    property var groupedTracks: []
    property var uniqueAlbums: []
    property bool isAlbumView: root.activeAlbum && root.activeAlbum.displayMode === "albums"

    // Helper to format track duration
    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "0:00";
        var mins = Math.floor(seconds / 60);
        var secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // Modal Content Panel
    Rectangle {
        id: modalContent
        width: 800
        height: parent.height * 0.85
        anchors.centerIn: parent
        color: "#1a1a2a"
        border.color: "#14ffffff"
        radius: 16
        clip: true

        // Custom slide-up animation mapping
        y: root.visible ? (parent.height - height) / 2 : parent.height
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 24

            // Top Header: Close Button
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    flat: true
                    onClicked: {
                        if (root.parentAlbum) {
                            root.openAlbum(root.parentAlbum);
                            root.parentAlbum = null;
                        } else {
                            root.visible = false;
                        }
                    }
                    contentItem: Item {
                        width: 16
                        height: 16
                        Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: 45; radius: 1 }
                        Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: -45; radius: 1 }
                    }
                }
            }

            // Album Metadata Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 24

                Rectangle {
                    width: 160
                    height: 160
                    color: "#111111"
                    radius: 12
                    clip: true
                    Layout.alignment: Qt.AlignTop

                    Image {
                        id: detailCover
                        source: root.activeAlbum ? root.activeAlbum.coverPath : ""
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: source != ""
                    }

                    Image {
                        anchors.centerIn: parent
                        source: "image://theme/media-optical"
                        width: 60
                        height: 60
                        visible: detailCover.source == ""
                        opacity: 0.5
                    }

                    // Play album overlay button
                    Button {
                        width: 48
                        height: 48
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 10
                        flat: true
                        
                        background: Rectangle {
                            color: "#00f2fe"
                            radius: width / 2
                        }

                        contentItem: Item {
                            anchors.fill: parent
                            Canvas {
                                anchors.centerIn: parent
                                width: 12
                                height: 14
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
                            if (root.activeAlbum && root.activeAlbum.tracks.length > 0) {
                                player.setQueue(root.activeAlbum.tracks, 0);
                            }
                        }
                    }
                }

                // Details Text
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.activeAlbum ? (root.activeAlbum.artist === "Smart Collection" ? "Smart Collection" : qsTr("Album")) : ""
                        color: "#00f2fe"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: root.activeAlbum ? root.activeAlbum.name : ""
                        color: "#ffffff"
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        id: artistLabel
                        text: root.activeAlbum ? root.activeAlbum.artist : ""
                        color: artistMouse.containsMouse ? "#00f2fe" : "#9ea2c0"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true

                        MouseArea {
                            id: artistMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activeAlbum && root.activeAlbum.artist && root.activeAlbum.artist !== "Smart Collection" && root.activeAlbum.artist !== "Various Artists") {
                                    root.visible = false;
                                    window.openArtist(root.activeAlbum.artist);
                                }
                            }
                        }
                    }

                    // Sub-metadata row
                    RowLayout {
                        spacing: 6
                        Text {
                            text: root.activeAlbum && root.activeAlbum.year > 0 ? root.activeAlbum.year : ""
                            color: "#666a8a"
                            font.pixelSize: 13
                            visible: text !== ""
                        }
                        Text { text: "•"; color: "#666a8a"; visible: parent.children[0].visible }
                        Text {
                            text: root.activeAlbum ? root.activeAlbum.genre : ""
                            color: "#666a8a"
                            font.pixelSize: 13
                            visible: text !== ""
                        }
                        Text { text: "•"; color: "#666a8a"; visible: parent.children[2].visible }
                        Text {
                            text: root.activeAlbum ? root.activeAlbum.tracks.length + " track" + (root.activeAlbum.tracks.length === 1 ? "" : "s") : ""
                            color: "#666a8a"
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // Scrollable Tracklist
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                visible: !root.isAlbumView

                ColumnLayout {
                    id: tracklistContainer
                    width: parent.width
                    spacing: 20

                    Repeater {
                        model: root.groupedTracks

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // CD section header (CD 1, CD 2)
                            Text {
                                text: qsTr("CD %1").arg(modelData.discNo)
                                color: "#666a8a"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                visible: root.groupedTracks.length > 1
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#0dffffff"
                                visible: root.groupedTracks.length > 1
                            }

                            // Tracks list
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Repeater {
                                    model: modelData.tracks

                                    delegate: Rectangle {
                                        id: trackRow
                                        Layout.fillWidth: true
                                        height: 38
                                        color: isPlaying ? "#0d00f2fe" : (trackMouse.containsMouse ? "#08ffffff" : "transparent")
                                        radius: 6

                                        property var trackObj: modelData
                                        property bool isPlaying: player.currentTrack.id === trackObj.id

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12

                                            Text {
                                                text: trackObj.trackNo > 0 ? trackObj.trackNo : (index + 1)
                                                color: isPlaying ? "#00f2fe" : "#666a8a"
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                Layout.preferredWidth: 30
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    text: trackObj.title
                                                    color: isPlaying ? "#00f2fe" : "#ffffff"
                                                    font.pixelSize: 14
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    id: trackArtistLabel
                                                    text: trackObj.artist || ""
                                                    color: trackArtistMouse.containsMouse ? "#00f2fe" : (isPlaying ? "#7ae6ff" : "#9ea2c0")
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    visible: root.activeAlbum && (root.activeAlbum.artist === "Various Artists" || root.activeAlbum.artist === "Smart Collection")

                                                    MouseArea {
                                                        id: trackArtistMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (trackObj.artist) {
                                                                root.visible = false;
                                                                window.openArtist(trackObj.artist);
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Row {
                                                spacing: 2
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredWidth: 80
                                                visible: (trackObj.rating > 0) || trackMouse.containsMouse

                                                Repeater {
                                                    model: 5
                                                    delegate: MouseArea {
                                                        width: 14
                                                        height: 14
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: index < trackObj.rating ? "★" : "☆"
                                                            color: index < trackObj.rating ? "#ffd700" : (trackMouse.containsMouse ? "#33ffffff" : "transparent")
                                                            font.pixelSize: 13
                                                        }

                                                        onClicked: {
                                                            var nextRating = index + 1;
                                                            if (trackObj.rating === nextRating) {
                                                                database.setTrackRating(trackObj.id, 0);
                                                            } else {
                                                                database.setTrackRating(trackObj.id, nextRating);
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Button {
                                                id: editTagBtn
                                                text: qsTr("Edit")
                                                flat: true
                                                Layout.preferredHeight: 24
                                                visible: trackMouse.containsMouse
                                                contentItem: Text {
                                                    text: editTagBtn.text
                                                    font.pixelSize: 11
                                                    color: "#00f2fe"
                                                }
                                                onClicked: {
                                                    root.openTagEditor(trackObj);
                                                }
                                            }

                                            Text {
                                                text: formatTime(trackObj.duration)
                                                color: isPlaying ? "#00f2fe" : "#666a8a"
                                                font.pixelSize: 13
                                            }
                                        }

                                        MouseArea {
                                            id: trackMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: {
                                                if (mouse.button === Qt.RightButton) {
                                                    tracksContextMenu.targetTrack = trackObj;
                                                    tracksContextMenu.popup();
                                                } else {
                                                    player.setQueue(root.activeAlbum.tracks, root.activeAlbum.tracks.indexOf(trackObj));
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

            // Scrollable Album Cover Grid
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                visible: root.isAlbumView

                Flow {
                    id: albumCoversContainer
                    width: parent.width
                    spacing: 20

                    Repeater {
                        model: root.uniqueAlbums

                        delegate: Item {
                            width: 120
                            height: 170

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 6

                                // Card Image
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 120
                                    color: "#111111"
                                    radius: 12
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
                                        width: 40
                                        height: 40
                                        visible: !modelData.coverPath
                                        opacity: 0.5
                                    }
                                }

                                // Album Name
                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // Artist Name
                                Text {
                                    text: modelData.artist
                                    color: "#9ea2c0"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.openAlbum(modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Opens and populates the modal
    function openAlbum(albumObj) {
        if (root.activeAlbum && root.activeAlbum.displayMode === "albums" && albumObj.displayMode !== "albums") {
            root.parentAlbum = root.activeAlbum;
        } else if (albumObj.displayMode === "albums") {
            root.parentAlbum = null;
        }
        root.activeAlbum = albumObj;
        
        // Group tracks by CD
        var grouped = {};
        for (var i = 0; i < albumObj.tracks.length; ++i) {
            var track = albumObj.tracks[i];
            var disc = track.discNo || 1;
            if (!grouped[disc]) grouped[disc] = [];
            grouped[disc].push(track);
        }

        var sortedDiscs = Object.keys(grouped).map(Number).sort(function(a, b) { return a - b; });
        var res = [];
        for (var d = 0; d < sortedDiscs.length; ++d) {
            res.push({
                discNo: sortedDiscs[d],
                tracks: grouped[sortedDiscs[d]]
            });
        }
        root.groupedTracks = res;

        // Group tracks into unique album objects for album cover view
        var albumsMap = {};
        var uniqueList = [];
        for (var j = 0; j < albumObj.tracks.length; ++j) {
            var t = albumObj.tracks[j];
            var albName = t.album || "Unknown Album";
            if (!albumsMap[albName]) {
                albumsMap[albName] = {
                    name: albName,
                    artist: t.artist || "Unknown Artist",
                    coverPath: t.coverPath || "",
                    year: t.year || 0,
                    tracks: []
                };
                uniqueList.push(albumsMap[albName]);
            }
            albumsMap[albName].tracks.push(t);
        }
        
        for (var k = 0; k < uniqueList.length; ++k) {
            var alb = uniqueList[k];
            alb.id = alb.artist + "_" + alb.name;
            alb.discs = [1];
            alb.totalDuration = alb.tracks.reduce(function(acc, val) { return acc + (val.duration || 0); }, 0);
        }
        root.uniqueAlbums = uniqueList;
        
        root.visible = true;
    }

    // Tag Editor Modal Overlay
    Rectangle {
        id: tagEditorDialog
        anchors.fill: parent
        color: "#d0000000"
        visible: false
        z: 9999 // Overlays everything including the modal details!

        property var activeTrack: null

        Rectangle {
            width: 440
            height: 490
            anchors.centerIn: parent
            color: "#1e1e30"
            border.color: "#14ffffff"
            radius: 16
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Text {
                    text: qsTr("Edit File Metadata (TagLib)")
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                // File Path (Read Only)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: qsTr("File Path"); color: "#666a8a"; font.pixelSize: 11 }
                    Text {
                        id: pathLabel
                        text: tagEditorDialog.activeTrack ? tagEditorDialog.activeTrack.filePath : ""
                        color: "#9ea2c0"
                        font.pixelSize: 12
                        elide: Text.ElideLeft
                        Layout.fillWidth: true
                    }
                }

                // Title
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: qsTr("Title"); color: "#ffffff"; font.pixelSize: 12 }
                    TextField {
                        id: titleInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                    }
                }

                // Artist
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: qsTr("Artist"); color: "#ffffff"; font.pixelSize: 12 }
                    TextField {
                        id: artistInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                    }
                }

                // Album
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: qsTr("Album"); color: "#ffffff"; font.pixelSize: 12 }
                    TextField {
                        id: albumInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                    }
                }

                // Genre & Year Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: qsTr("Genre"); color: "#ffffff"; font.pixelSize: 12 }
                        TextField {
                            id: genreInput
                            Layout.fillWidth: true
                            color: "#ffffff"
                            background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 100
                        spacing: 2
                        Text { text: qsTr("Year"); color: "#ffffff"; font.pixelSize: 12 }
                        TextField {
                            id: yearInput
                            Layout.fillWidth: true
                            color: "#ffffff"
                            background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                        }
                    }
                }

                // Album Type
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: qsTr("Album Type"); color: "#ffffff"; font.pixelSize: 12 }
                    ComboBox {
                        id: albumTypeCombo
                        Layout.fillWidth: true
                        model: ["Studio Albums", "Singles", "Live Albums", "Compilations"]
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    Button {
                        text: qsTr("Cancel")
                        onClicked: tagEditorDialog.visible = false
                    }

                    Button {
                        text: qsTr("Save Tags")
                        highlighted: true
                        onClicked: {
                            var yearVal = parseInt(yearInput.text) || 0;
                            var ok = database.writeTrackTags(
                                tagEditorDialog.activeTrack.filePath,
                                titleInput.text.trim(),
                                artistInput.text.trim(),
                                albumInput.text.trim(),
                                genreInput.text.trim(),
                                yearVal,
                                albumTypeCombo.currentText
                            );
                            if (ok) {
                                for (var i = 0; i < root.activeAlbum.tracks.length; ++i) {
                                    if (root.activeAlbum.tracks[i].filePath === tagEditorDialog.activeTrack.filePath) {
                                        root.activeAlbum.tracks[i].title = titleInput.text.trim();
                                        root.activeAlbum.tracks[i].artist = artistInput.text.trim();
                                        root.activeAlbum.tracks[i].album = albumInput.text.trim();
                                        root.activeAlbum.tracks[i].genre = genreInput.text.trim();
                                        root.activeAlbum.tracks[i].year = yearVal;
                                        root.activeAlbum.tracks[i].albumType = albumTypeCombo.currentText;
                                        break;
                                    }
                                }
                                root.openAlbum(root.activeAlbum);
                            }
                            tagEditorDialog.visible = false;
                        }
                    }
                }
            }
        }
    }

    function openTagEditor(trackObj) {
        tagEditorDialog.activeTrack = trackObj;
        titleInput.text = trackObj.title || "";
        artistInput.text = trackObj.artist || "";
        albumInput.text = trackObj.album || "";
        genreInput.text = trackObj.genre || "";
        yearInput.text = trackObj.year ? trackObj.year.toString() : "0";
        
        var types = ["Studio Albums", "Singles", "Live Albums", "Compilations"];
        var idx = types.indexOf(trackObj.albumType || "Studio Albums");
        albumTypeCombo.currentIndex = idx >= 0 ? idx : 0;

        tagEditorDialog.visible = true;
    }

    Menu {
        id: tracksContextMenu
        
        property var targetTrack: null
        
        MenuItem {
            text: qsTr("Play Now")
            onTriggered: {
                if (tracksContextMenu.targetTrack) {
                    player.setQueue([tracksContextMenu.targetTrack], 0);
                }
            }
        }
        MenuItem {
            text: qsTr("Play Next")
            onTriggered: {
                if (tracksContextMenu.targetTrack) {
                    player.playNext(tracksContextMenu.targetTrack);
                }
            }
        }
        MenuItem {
            text: qsTr("Queue Last")
            onTriggered: {
                if (tracksContextMenu.targetTrack) {
                    player.queueLast(tracksContextMenu.targetTrack);
                }
            }
        }
    }
}
