import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#bf0f0f19"
    border.color: "#0dffffff"
    border.width: 1

    // Helper to format position/duration (e.g. 240 -> "4:00")
    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "0:00";
        var mins = Math.floor(seconds / 60);
        var secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 30
        anchors.rightMargin: 30
        spacing: 20

        // 1. Left Section: Track Info
        RowLayout {
            Layout.preferredWidth: parent.width * 0.3
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                id: coverWrapper
                width: 56
                height: 56
                color: "#111111"
                radius: 8
                clip: true
                border.color: "#14ffffff"
                
                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: player.currentTrack.coverPath || ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source != ""
                }

                // Fallback icon
                Image {
                    anchors.centerIn: parent
                    source: "image://theme/audio-x-generic"
                    width: 28
                    height: 28
                    visible: coverImage.source == ""
                    opacity: 0.5
                }
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: player.currentTrack.title || qsTr("Not Playing")
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: player.currentTrack.artist || ""
                    color: "#9ea2c0"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // 2. Center Section: Playback Controls & Progress Bar
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            Layout.alignment: Qt.AlignCenter

            // Controls buttons
            RowLayout {
                spacing: 16
                Layout.alignment: Qt.AlignHCenter

                // Shuffle
                Button {
                    icon.name: "media-playlist-shuffle"
                    flat: true
                    opacity: player.shuffle ? 1.0 : 0.5
                    icon.color: player.shuffle ? "#00f2fe" : "#ffffff"
                    onClicked: player.shuffle = !player.shuffle
                }

                // Previous
                Button {
                    icon.name: "media-skip-backward"
                    flat: true
                    onClicked: player.previous()
                }

                // Play / Pause
                Button {
                    id: playBtn
                    width: 44
                    height: 44
                    flat: true
                    
                    background: Rectangle {
                        color: "#ffffff"
                        radius: width / 2
                    }
                    
                    contentItem: Image {
                        source: player.playbackStatus === "Playing" ? "image://theme/media-playback-pause" : "image://theme/media-playback-start"
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                    }
                    
                    onClicked: player.togglePlay()
                }

                // Next
                Button {
                    icon.name: "media-skip-forward"
                    flat: true
                    onClicked: player.next()
                }

                // Repeat
                Button {
                    icon.name: player.loopStatus === "Track" ? "media-playlist-repeat-song" : "media-playlist-repeat"
                    flat: true
                    opacity: player.loopStatus !== "None" ? 1.0 : 0.5
                    icon.color: player.loopStatus !== "None" ? "#00f2fe" : "#ffffff"
                    onClicked: {
                        if (player.loopStatus === "None") player.loopStatus = "Playlist";
                        else if (player.loopStatus === "Playlist") player.loopStatus = "Track";
                        else player.loopStatus = "None";
                    }
                }
            }

            // Progress Slider row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: formatTime(player.position)
                    color: "#666a8a"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Slider {
                    id: progressSlider
                    Layout.fillWidth: true
                    from: 0
                    to: player.duration > 0 ? player.duration : 100
                    value: player.position
                    
                    background: Rectangle {
                        x: progressSlider.leftPadding
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: progressSlider.availableWidth
                        height: 4
                        radius: 2
                        color: "#1affffff"

                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#00f2fe"
                            radius: 2
                        }
                    }
                    
                    handle: Rectangle {
                        x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: "#ffffff"
                    }

                    // Seek on release to avoid constant jumping
                    onMoved: player.position = value
                }

                Text {
                    text: formatTime(player.duration)
                    color: "#666a8a"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }
        }

        // 3. Right Section: Volume controls
        RowLayout {
            Layout.preferredWidth: parent.width * 0.3
            Layout.fillHeight: true
            spacing: 8
            Layout.alignment: Qt.AlignRight

            Button {
                id: muteBtn
                icon.name: player.volume === 0 ? "audio-volume-muted" : "audio-volume-high"
                flat: true
                onClicked: {
                    if (player.volume > 0) {
                        muteBtn.propertyVar = player.volume;
                        player.volume = 0;
                    } else {
                        player.volume = muteBtn.propertyVar || 0.8;
                    }
                }
                property double propertyVar: 0.8
            }

            Slider {
                id: volumeSlider
                Layout.preferredWidth: 100
                from: 0
                to: 1
                value: player.volume
                onMoved: player.volume = value

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#1affffff"

                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#00f2fe"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 12
                    height: 12
                    radius: 6
                    color: "#ffffff"
                }
            }
        }
    }
}
