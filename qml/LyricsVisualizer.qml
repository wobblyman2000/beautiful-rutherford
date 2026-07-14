import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: visualizer

    property string filePath: player.currentTrack.filePath || ""
    property string rawLyrics: ""
    property var parsedLyrics: []
    property bool isSynced: false
    property int currentLineIndex: -1

    property bool isDownloading: false

    function downloadLrc(track) {
        if (!track || !track.title || !track.artist) {
            rawLyrics = qsTr("No lyrics available.");
            return;
        }
        isDownloading = true;
        
        var xhr = new XMLHttpRequest();
        var url = "https://lrclib.net/api/get?" + 
            "artist=" + encodeURIComponent(track.artist) + 
            "&track_name=" + encodeURIComponent(track.title);
            
        if (track.album) {
            url += "&album_name=" + encodeURIComponent(track.album);
        }
        if (track.duration) {
            url += "&duration=" + Math.round(track.duration);
        }
        
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isDownloading = false;
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        var lyrics = res.syncedLyrics || res.plainLyrics || "";
                        if (lyrics !== "") {
                            var saved = database.saveLrcFile(track.filePath, lyrics);
                            if (saved) {
                                console.log("LRC lyrics saved next to track:", track.filePath);
                                rawLyrics = lyrics;
                            }
                        } else {
                            rawLyrics = qsTr("Lyrics not found.");
                        }
                    } catch (e) {
                        rawLyrics = qsTr("Lyrics not found.");
                    }
                } else {
                    rawLyrics = qsTr("Lyrics not found.");
                }
            }
        }
        xhr.send();
    }

    onFilePathChanged: {
        if (filePath !== "") {
            var loaded = player.getLyricsForTrack(filePath);
            if (loaded && loaded.trim() !== "") {
                rawLyrics = loaded;
            } else {
                rawLyrics = qsTr("Searching online for lyrics...");
                downloadLrc(player.currentTrack);
            }
        } else {
            rawLyrics = "";
        }
    }

    onRawLyricsChanged: {
        var lines = rawLyrics.split('\n');
        var parsed = [];
        var synced = false;
        var regex = /\[(\d+):(\d+)(?:\.(\d+))?\](.*)/;

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            var match = regex.exec(line);
            if (match) {
                synced = true;
                var mins = parseInt(match[1]);
                var secs = parseInt(match[2]);
                var ms = match[3] ? parseInt(match[3]) * 10 : 0;
                var timeMs = (mins * 60 + secs) * 1000 + ms;
                var text = match[4].trim();
                parsed.push({ timeMs: timeMs, text: text });
            } else {
                if (line.startsWith("[") && line.endsWith("]")) {
                    continue;
                }
                parsed.push({ timeMs: -1, text: line });
            }
        }

        if (synced) {
            parsed.sort(function(a, b) { return a.timeMs - b.timeMs; });
        }

        parsedLyrics = parsed;
        isSynced = synced;
        currentLineIndex = -1;
    }

    property real currentPosMs: player.position * 1000

    onCurrentPosMsChanged: {
        if (!isSynced || parsedLyrics.length === 0) return;
        
        var index = -1;
        for (var i = 0; i < parsedLyrics.length; ++i) {
            if (currentPosMs >= parsedLyrics[i].timeMs) {
                index = i;
            } else {
                break;
            }
        }
        if (index !== currentLineIndex) {
            currentLineIndex = index;
            if (index >= 0 && lyricsListView.visible) {
                lyricsListView.positionViewAtIndex(index, ListView.Center);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: qsTr("Lyrics")
                color: "#ffffff"
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: isSynced ? qsTr("Synced") : qsTr("Text")
                color: "#666a8a"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                visible: rawLyrics !== ""
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#0dffffff"
        }

        // Empty state
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: qsTr("No lyrics found.\nUse the metadata editor to add lyrics or place a .lrc file in the track folder.")
            color: "#666a8a"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: rawLyrics === ""
        }

        // Synced Lyrics List View
        ListView {
            id: lyricsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: isSynced ? parsedLyrics : null
            visible: rawLyrics !== "" && isSynced
            spacing: 12
            preferredHighlightBegin: parent.height / 3
            preferredHighlightEnd: parent.height / 3
            highlightRangeMode: ListView.ApplyRange

            delegate: Item {
                width: lyricsListView.width
                height: lyricText.implicitHeight + 10
                
                property bool isActive: index === currentLineIndex

                Text {
                    id: lyricText
                    width: parent.width
                    text: modelData.text || " "
                    color: isActive ? "#00f2fe" : "#9ea2c0"
                    font.pixelSize: isActive ? 18 : 14
                    font.weight: isActive ? Font.Bold : Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    
                    Behavior on font.pixelSize { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        // Unsynced Plain Text Scroll View
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: rawLyrics !== "" && !isSynced

            Text {
                width: parent.width
                text: {
                    var out = "";
                    for (var i = 0; i < parsedLyrics.length; ++i) {
                        out += parsedLyrics[i].text + "\n";
                    }
                    return out;
                }
                color: "#ffffff"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                lineHeight: 1.5
            }
        }
    }
}
