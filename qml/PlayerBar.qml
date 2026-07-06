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
                    
                    contentItem: Item {
                        anchors.fill: parent
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: player.playbackStatus === "Playing"
                            Rectangle { width: 4; height: 16; color: "#1a1a2a"; radius: 1 }
                            Rectangle { width: 4; height: 16; color: "#1a1a2a"; radius: 1 }
                        }
                        Canvas {
                            anchors.centerIn: parent
                            width: 14
                            height: 16
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

                // Next
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

                    background: Rectangle {
                        width: parent.width
                        height: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#1affffff"
                        radius: 2

                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#00f2fe"
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: progressSlider.visualPosition * (progressSlider.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: "#ffffff"
                    }

                    // Seek on release to avoid constant jumping
                    onMoved: player.position = value

                    Connections {
                        target: player
                        function onPositionChanged() {
                            if (!progressSlider.pressed) {
                                progressSlider.value = player.position;
                            }
                        }
                        function onDurationChanged() {
                            if (!progressSlider.pressed) {
                                progressSlider.value = player.position;
                            }
                        }
                    }

                    Component.onCompleted: {
                        value = player.position;
                    }
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
                flat: true
                text: qsTr("Auto-DJ")
                font.pixelSize: 10
                font.weight: Font.Bold
                opacity: player.autoDJ ? 1.0 : 0.5
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: player.autoDJ ? "#00f2fe" : "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: player.autoDJ = !player.autoDJ
            }

            Button {
                flat: true
                text: qsTr("EQ")
                font.pixelSize: 10
                font.weight: Font.Bold
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: eqPopup.visible ? "#00f2fe" : "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: eqPopup.visible = !eqPopup.visible
            }

            Button {
                flat: true
                text: qsTr("Mini")
                font.pixelSize: 10
                font.weight: Font.Bold
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: window.isCompactMode ? "#00f2fe" : "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: window.isCompactMode = !window.isCompactMode
            }

            Button {
                flat: true
                text: qsTr("Theater")
                font.pixelSize: 10
                font.weight: Font.Bold
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: window.isTheaterMode ? "#00f2fe" : "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: window.isTheaterMode = !window.isTheaterMode
            }

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

                background: Rectangle {
                    width: parent.width
                    height: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#1affffff"
                    radius: 2

                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#00f2fe"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.visualPosition * (volumeSlider.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: "#ffffff"
                }

                onMoved: player.volume = value

                Connections {
                    target: player
                    function onVolumeChanged() {
                        if (!volumeSlider.pressed) {
                            volumeSlider.value = player.volume;
                        }
                    }
                }

                Component.onCompleted: {
                    value = player.volume;
                }
            }
        }
    }

    Popup {
        id: eqPopup
        x: muteBtn.x - width/2
        y: -height - 10
        width: 320
        height: 220
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#1e1e30"
            border.color: "#14ffffff"
            radius: 12
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTr("Graphic Equalizer")
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
                Item { Layout.fillWidth: true }
                ComboBox {
                    id: eqPresetCombo
                    model: ["Flat", "Rock", "Pop", "Classical", "Bass Boost"]
                    Layout.preferredWidth: 120
                    onCurrentIndexChanged: {
                        var flat = [50, 50, 50, 50, 50, 50, 50, 50, 50, 50];
                        var rock = [75, 68, 55, 45, 42, 45, 52, 60, 68, 75];
                        var pop = [42, 48, 55, 65, 70, 68, 60, 52, 48, 42];
                        var classical = [70, 60, 55, 52, 45, 48, 52, 58, 62, 68];
                        var bass = [85, 80, 70, 55, 50, 48, 48, 48, 48, 48];
                        var current = flat;
                        if (currentIndex === 1) current = rock;
                        else if (currentIndex === 2) current = pop;
                        else if (currentIndex === 3) current = classical;
                        else if (currentIndex === 4) current = bass;

                        for (var i = 0; i < current.length; ++i) {
                            eqSlidersRepeater.itemAt(i).sliderValue = current[i];
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Repeater {
                    id: eqSlidersRepeater
                    model: 10

                    delegate: ColumnLayout {
                        id: eqCol
                        Layout.fillHeight: true
                        spacing: 4
                        property alias sliderValue: bandSlider.value

                        Slider {
                            id: bandSlider
                            Layout.fillHeight: true
                            orientation: Qt.Vertical
                            from: 0
                            to: 100
                            value: 50
                        }

                        Text {
                            text: {
                                var bands = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"];
                                return bands[index];
                            }
                            color: "#9ea2c0"
                            font.pixelSize: 8
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
