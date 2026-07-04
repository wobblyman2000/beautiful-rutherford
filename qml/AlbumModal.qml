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
    property var groupedTracks: []

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
                    icon.name: "window-close"
                    flat: true
                    onClicked: root.visible = false
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

                        contentItem: Image {
                            source: "image://theme/media-playback-start"
                            anchors.centerIn: parent
                            width: 20
                            height: 20
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
                        text: root.activeAlbum ? root.activeAlbum.artist : ""
                        color: "#9ea2c0"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
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

                                        property bool isPlaying: player.currentTrack.id === modelData.id

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12

                                            Text {
                                                text: modelData.trackNo > 0 ? modelData.trackNo : (index + 1)
                                                color: isPlaying ? "#00f2fe" : "#666a8a"
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                Layout.preferredWidth: 30
                                            }

                                            Text {
                                                text: modelData.title
                                                color: isPlaying ? "#00f2fe" : "#ffffff"
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: formatTime(modelData.duration)
                                                color: isPlaying ? "#00f2fe" : "#666a8a"
                                                font.pixelSize: 13
                                            }
                                        }

                                        MouseArea {
                                            id: trackMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                // Play album tracks starting from this specific track filepath
                                                player.setQueue(root.activeAlbum.tracks, root.activeAlbum.tracks.indexOf(modelData));
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

    // Opens and populates the modal
    function openAlbum(albumObj) {
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
        root.visible = true;
    }
}
