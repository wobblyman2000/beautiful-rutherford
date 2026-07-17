import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform

ApplicationWindow {
    id: window
    width: 1100
    height: 720
    visible: true
    visibility: ApplicationWindow.FullScreen
    title: qsTr("Aether Player")
    
    // Global properties
    property string activePage: "albums"
    property string searchQuery: ""
    property bool isCompactMode: false
    property bool isTheaterMode: false
    property bool autoTheaterEnabled: false
    property bool autoTheaterOnlyWhenPlaying: false
    property bool showLyricsPanel: false
    property bool showRightQueuePanel: true
    property var djRulesModel: [{ field: "album", operator: "contains", value: "" }]
    property int preTheaterVisibility: ApplicationWindow.FullScreen

    onAutoTheaterEnabledChanged: {
        if (!autoTheaterEnabled) {
            inactivityTimer.stop();
        } else {
            inactivityTimer.restart();
        }
    }

    onAutoTheaterOnlyWhenPlayingChanged: {
        inactivityTimer.restart();
    }

    onIsTheaterModeChanged: {
        if (isTheaterMode) {
            if (window.visibility !== ApplicationWindow.FullScreen) {
                window.preTheaterVisibility = window.visibility;
            }
            window.visibility = ApplicationWindow.FullScreen;
        } else {
            window.visibility = window.isCompactMode ? ApplicationWindow.Windowed : window.preTheaterVisibility;
            window.raise();
            window.requestActivate();
        }
    }
    onClosing: (close) => {
        // HUMAN-READABLE COMMENT:
        // Intercept the close event to keep the application running in the system tray.
        // Hiding the main window allows background playback to continue uninterrupted.
        if (systemTray.visible) {
            close.accepted = false;
            window.hide();
        }
    }

    Platform.SystemTrayIcon {
        id: systemTray
        visible: true
        icon.name: "media-optical"
        tooltip: qsTr("Aether Player")

        onActivated: (reason) => {
            if (reason === Platform.SystemTrayIcon.Trigger || reason === Platform.SystemTrayIcon.DoubleClick) {
                window.show();
                window.raise();
                window.requestActivate();
            }
        }

        menu: Platform.Menu {
            Platform.MenuItem {
                text: qsTr("Play / Pause")
                onTriggered: player.togglePlay()
            }
            Platform.MenuItem {
                text: qsTr("Next Track")
                onTriggered: player.next()
            }
            Platform.MenuItem {
                text: qsTr("Previous Track")
                onTriggered: player.previous()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: qsTr("Show Aether")
                onTriggered: {
                    window.show();
                    window.raise();
                    window.requestActivate();
                }
            }
            Platform.MenuItem {
                text: qsTr("Quit")
                onTriggered: {
                    systemTray.visible = false;
                    Qt.quit();
                }
            }
        }
    }
    onIsCompactModeChanged: {
        if (isCompactMode) {
            window.isTheaterMode = false;
            window.visibility = ApplicationWindow.Windowed;
            window.width = 360;
            window.height = 130;
        } else {
            window.visibility = ApplicationWindow.Maximized;
            window.width = 1100;
            window.height = 720;
        }
    }

    // Global User Inactivity Monitor (1-minute timer)
    Timer {
        id: inactivityTimer
        interval: 60000 // 1 minute inactivity
        running: {
            var enabled = window.autoTheaterEnabled && !window.isTheaterMode && !window.isCompactMode;
            if (enabled && window.autoTheaterOnlyWhenPlaying) {
                return player.playbackStatus === "Playing";
            }
            return enabled;
        }
        repeat: false
        onTriggered: {
            // HUMAN-READABLE COMMENT:
            // When the inactivity timer expires, automatically transition the application
            // into Theater Mode to display full-screen ambient visuals.
            window.isTheaterMode = true;
        }
    }

    function applyDJRules() {
        // HUMAN-READABLE COMMENT:
        // Reads the active visual rules repeater configurations, maps drop-down choices
        // to fields/operators, and saves them to the C++ player.autoDJRules property.
        var list = [];
        for (var i = 0; i < djRulesRepeater.count; ++i) {
            var item = djRulesRepeater.itemAt(i);
            if (item) {
                list.push({
                    field: item.getFieldKey(),
                    operator: item.getOpKey(),
                    value: item.getValue()
                });
            }
        }
        window.djRulesModel = list;
        player.autoDJRules = list;

        // Fetch matching tracks, shuffle, and fill the playback queue
        var matching = player.getAutoDJMatchingTracks();
        if (matching.length > 0) {
            var shuffled = matching.slice();
            for (var j = shuffled.length - 1; j > 0; j--) {
                var k = Math.floor(Math.random() * (j + 1));
                var temp = shuffled[j];
                shuffled[j] = shuffled[k];
                shuffled[k] = temp;
            }
            var limit = Math.min(shuffled.length, 50);
            player.setQueue(shuffled.slice(0, limit), 0);
        } else {
            player.clearQueue();
        }
    }

    // Transparent event listener covering the window to detect interactions and reset the inactivity timer
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        hoverEnabled: true
        // Position on top of normal controls, but let everything propagate down
        z: 9999
        // Do not block actual mouse clicks on other components
        onPressed: (mouse) => {
            if (window.autoTheaterEnabled) inactivityTimer.restart();
            mouse.accepted = false;
        }
        onReleased: (mouse) => {
            if (window.autoTheaterEnabled) inactivityTimer.restart();
            mouse.accepted = false;
        }
        onPositionChanged: (mouse) => {
            if (window.autoTheaterEnabled) inactivityTimer.restart();
            mouse.accepted = false;
        }
    }

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

        // Custom Window Control Bar for FullScreen Mode
        RowLayout {
            id: windowControlsBar
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            visible: window.visibility === ApplicationWindow.FullScreen
            spacing: 0
            
            Rectangle {
                anchors.fill: parent
                color: "#161625"
                border.color: "#14ffffff"
                border.width: 1
            }

            Text {
                text: qsTr("Aether Player")
                color: "#666a8a"
                font.pixelSize: 11
                font.weight: Font.Medium
                Layout.leftMargin: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Button {
                id: minWindowBtn
                flat: true
                Layout.preferredWidth: 46
                Layout.preferredHeight: 32
                contentItem: Text {
                    text: "—"
                    color: minWindowBtn.hovered ? "#00f2fe" : "#88ffffff"
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: minWindowBtn.hovered ? "#14ffffff" : "transparent"
                }
                onClicked: window.showMinimized()
            }

            Button {
                id: maxWindowBtn
                flat: true
                Layout.preferredWidth: 46
                Layout.preferredHeight: 32
                contentItem: Text {
                    text: "❐"
                    color: maxWindowBtn.hovered ? "#00f2fe" : "#88ffffff"
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: maxWindowBtn.hovered ? "#14ffffff" : "transparent"
                }
                onClicked: {
                    window.visibility = ApplicationWindow.Maximized;
                    window.preTheaterVisibility = ApplicationWindow.Maximized;
                }
            }

            Button {
                id: closeWindowBtn
                flat: true
                Layout.preferredWidth: 46
                Layout.preferredHeight: 32
                contentItem: Text {
                    text: "✕"
                    color: closeWindowBtn.hovered ? "#ffffff" : "#88ffffff"
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: closeWindowBtn.hovered ? "#e81123" : "transparent"
                }
                onClicked: Qt.quit()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            visible: !window.isCompactMode

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

                        // Toggle Right Queue Panel Button
                        Button {
                            id: toggleQueueBtn
                            flat: true
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            
                            background: Rectangle {
                                color: window.showRightQueuePanel ? "#1a00f2fe" : (toggleQueueBtn.hovered ? "#0affffff" : "transparent")
                                border.color: window.showRightQueuePanel ? "#4000f2fe" : "transparent"
                                border.width: 1
                                radius: 8
                            }
                            
                            contentItem: Image {
                                source: "image://theme/media-playlist-normal"
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                opacity: window.showRightQueuePanel ? 1.0 : 0.6
                            }
                            
                            onClicked: window.showRightQueuePanel = !window.showRightQueuePanel
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
                        id: collectionGrid
                        anchors.fill: parent
                        visible: window.activePage === "collections"
                    }

                    // Auto-DJ Dashboard Page
                    Item {
                        anchors.fill: parent
                        anchors.margins: 30
                        visible: window.activePage === "autodj"

                        // Left Pane: Filters & Configuration
                        Rectangle {
                            id: rulesCardLeftDJ
                            anchors.fill: parent
                            color: "#73191928"
                            border.color: "#14ffffff"
                            border.width: 1
                            radius: 16

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                Text {
                                    text: qsTr("Auto-DJ Settings")
                                    color: "#ffffff"
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#14ffffff"
                                }

                                // Load existing rules from collections
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: qsTr("Preset:"); color: "#9ea2c0"; font.pixelSize: 11 }
                                    ComboBox {
                                        id: loadCollectionCombo
                                        Layout.fillWidth: true
                                        model: {
                                            var list = [qsTr("Load from Saved Collection...")];
                                            var collections = database.collections;
                                            if (collections) {
                                                for (var i = 0; i < collections.length; ++i) {
                                                    list.push(collections[i].name);
                                                }
                                            }
                                            return list;
                                        }
                                        currentIndex: 0
                                        onActivated: (index) => {
                                            if (index === 0) return;
                                            var colName = model[index];
                                            var collections = database.collections;
                                            for (var i = 0; i < collections.length; ++i) {
                                                if (collections[i].name === colName) {
                                                    var list = [];
                                                    for (var j = 0; j < collections[i].rules.length; ++j) {
                                                        list.push({
                                                            field: collections[i].rules[j].field,
                                                            operator: collections[i].rules[j].operator,
                                                            value: collections[i].rules[j].value
                                                        });
                                                    }
                                                    window.djRulesModel = list;
                                                    applyDJRules();
                                                    break;
                                                }
                                            }
                                            currentIndex = 0;
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: qsTr("Rules (AND conditions)")
                                        color: "#00f2fe"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    Item { Layout.fillWidth: true }
                                    Button {
                                        id: addRuleBtnBtn
                                        flat: true
                                        contentItem: Text { text: qsTr("+ Add Rule"); color: "#00f2fe"; font.bold: true; font.pixelSize: 12 }
                                        onClicked: {
                                            var current = window.djRulesModel;
                                            current.push({ field: "album", operator: "contains", value: "" });
                                            window.djRulesModel = [];
                                            window.djRulesModel = current;
                                        }
                                    }
                                }

                                ScrollView {
                                    id: djRulesScrollView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                    ColumnLayout {
                                        id: djRulesListContainer
                                        width: djRulesScrollView.width - 24
                                        spacing: 10

                                        Repeater {
                                            id: djRulesRepeater
                                            model: window.djRulesModel

                                            delegate: RowLayout {
                                                id: ruleRow
                                                Layout.fillWidth: true
                                                spacing: 6

                                                function getFieldKey() { return fieldCombo.getFieldKey(); }
                                                function getOpKey() { return opCombo.getOpKey(); }
                                                function getValue() { return ruleValueInput.text.trim(); }
                                                function getAllYears() {
                                                    var years = {};
                                                    var tracks = database.tracks;
                                                    for (var i = 0; i < tracks.length; ++i) {
                                                        if (tracks[i].year > 0) {
                                                            years[tracks[i].year] = true;
                                                        }
                                                    }
                                                    var list = Object.keys(years);
                                                    list.sort(function(a, b) { return b - a; });
                                                    return list;
                                                }

                                                ComboBox {
                                                    id: fieldCombo
                                                    model: ["Album", "Artist", "Genre", "Title", "FilePath", "Rating", "Year"]
                                                    currentIndex: {
                                                        var f = modelData.field || "album";
                                                        if (f === "artist") return 1;
                                                        if (f === "genre") return 2;
                                                        if (f === "title") return 3;
                                                        if (f === "filePath") return 4;
                                                        if (f === "rating") return 5;
                                                        if (f === "year") return 6;
                                                        return 0;
                                                    }
                                                    Layout.preferredWidth: 105
                                                    
                                                    function getFieldKey() {
                                                        var idx = currentIndex;
                                                        if (idx === 1) return "artist";
                                                        if (idx === 2) return "genre";
                                                        if (idx === 3) return "title";
                                                        if (idx === 4) return "filePath";
                                                        if (idx === 5) return "rating";
                                                        if (idx === 6) return "year";
                                                        return "album";
                                                    }
                                                }

                                                ComboBox {
                                                    id: opCombo
                                                    model: ["Contains", "Is", "Starts", "Ends", "Not Contain"]
                                                    currentIndex: {
                                                        var o = modelData.operator || "contains";
                                                        if (o === "is") return 1;
                                                        if (o === "starts_with") return 2;
                                                        if (o === "ends_with") return 3;
                                                        if (o === "not_contains") return 4;
                                                        return 0;
                                                    }
                                                    Layout.preferredWidth: 105

                                                    function getOpKey() {
                                                        var idx = currentIndex;
                                                        if (idx === 1) return "is";
                                                        if (idx === 2) return "starts_with";
                                                        if (idx === 3) return "ends_with";
                                                        if (idx === 4) return "not_contains";
                                                        return "contains";
                                                    }
                                                }

                                                TextField {
                                                    id: ruleValueInput
                                                    text: modelData.value || ""
                                                    Layout.fillWidth: true
                                                    color: "#ffffff"
                                                    font.pixelSize: 12
                                                    placeholderText: qsTr("Value")
                                                    background: Rectangle {
                                                        color: "#33000000"
                                                        border.color: "#14ffffff"
                                                        radius: 6
                                                    }
                                                    onTextChanged: {
                                                        if (activeFocus && text.trim() !== "") {
                                                            var f = fieldCombo.currentIndex;
                                                            if (f === 0 || f === 1 || f === 2 || f === 6) {
                                                                suggestionsMenu.open();
                                                            }
                                                        }
                                                    }
                                                }

                                                Button {
                                                    id: suggestBtnBtn
                                                    flat: true
                                                    Layout.preferredWidth: 20
                                                    Layout.preferredHeight: 28
                                                    contentItem: Text { text: "▾"; color: "#9ea2c0"; font.bold: true; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    visible: fieldCombo.currentIndex === 0 || fieldCombo.currentIndex === 1 || fieldCombo.currentIndex === 2 || fieldCombo.currentIndex === 6
                                                    onClicked: suggestionsMenu.open()

                                                    Menu {
                                                        id: suggestionsMenu
                                                        y: parent.height
                                                        width: Math.max(200, ruleValueInput.width)

                                                        Repeater {
                                                            model: {
                                                                var f = fieldCombo.currentIndex;
                                                                var rawList = [];
                                                                if (f === 1) rawList = database.allArtists;
                                                                else if (f === 2) rawList = database.allGenres;
                                                                else if (f === 0) rawList = database.allAlbums;
                                                                else if (f === 6) rawList = ruleRow.getAllYears();
                                                                
                                                                var typed = ruleValueInput.text.toLowerCase().trim();
                                                                if (typed === "") return rawList;
                                                                
                                                                var filtered = [];
                                                                for (var i = 0; i < rawList.length; ++i) {
                                                                    var strVal = rawList[i].toString();
                                                                    if (strVal.toLowerCase().indexOf(typed) !== -1) {
                                                                        filtered.push(strVal);
                                                                    }
                                                                }
                                                                return filtered;
                                                            }
                                                            delegate: MenuItem {
                                                                text: modelData
                                                                onTriggered: {
                                                                    ruleValueInput.text = modelData;
                                                                    suggestionsMenu.close();
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Button {
                                                    flat: true
                                                    Layout.preferredWidth: 20
                                                    Layout.preferredHeight: 28
                                                    contentItem: Text { text: "✕"; color: "#ff5555"; font.bold: true; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    onClicked: {
                                                        var current = window.djRulesModel;
                                                        current.splice(index, 1);
                                                        window.djRulesModel = [];
                                                        window.djRulesModel = current;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Button {
                                        id: applyDjRulesBtn
                                        Layout.fillWidth: true
                                        contentItem: Text {
                                            text: qsTr("Apply Filters")
                                            color: "#00f2fe"
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            color: applyDjRulesBtn.pressed ? "#2200f2fe" : (applyDjRulesBtn.hovered ? "#1100f2fe" : "#14ffffff")
                                            border.color: "#00f2fe"
                                            border.width: 1
                                            radius: 6
                                        }
                                        onClicked: applyDJRules()
                                    }

                                    Button {
                                        id: resetDjFiltersBtn
                                        Layout.preferredWidth: 70
                                        contentItem: Text { text: qsTr("Reset"); color: "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                                        onClicked: {
                                            window.djRulesModel = [{ field: "album", operator: "contains", value: "" }];
                                            applyDJRules();
                                        }
                                    }
                                }

                                Button {
                                    id: saveAsPlaylistBtn
                                    Layout.fillWidth: true
                                    contentItem: Text { text: qsTr("Save Filters as Collection..."); color: "#ffffff"; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                                    onClicked: {
                                        saveColDialog.open();
                                    }
                                }
                            }
                        }

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

                            // Preferences & Version Info Card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: prefLayout.implicitHeight + 40
                                color: "#73191928"
                                border.color: "#14ffffff"
                                border.width: 1
                                radius: 16

                                ColumnLayout {
                                    id: prefLayout
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 16

                                    Text {
                                        text: qsTr("Preferences")
                                        color: "#ffffff"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                    }

                                    // Switch for Auto-Theater Mode
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Switch {
                                            id: autoTheaterSwitch
                                            checked: window.autoTheaterEnabled
                                            onCheckedChanged: window.autoTheaterEnabled = checked
                                        }

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: qsTr("Auto Theater Mode on Inactivity")
                                                color: "#ffffff"
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                            }
                                            Text {
                                                text: qsTr("Automatically switch to Theater Mode if the player is inactive for 1 minute.")
                                                color: "#666a8a"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }

                                    // Switch for Auto-Theater Mode only when playing
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        opacity: window.autoTheaterEnabled ? 1.0 : 0.4
                                        enabled: window.autoTheaterEnabled

                                        Switch {
                                            id: autoTheaterOnlyWhenPlayingSwitch
                                            checked: window.autoTheaterOnlyWhenPlaying
                                            onCheckedChanged: window.autoTheaterOnlyWhenPlaying = checked
                                        }

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: qsTr("Only Switch to Theater Mode if Music is Playing")
                                                color: "#ffffff"
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                            }
                                            Text {
                                                text: qsTr("Prevent transitioning to Theater Mode if playback is paused or stopped.")
                                                color: "#666a8a"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }

                                    // Action line separator
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#14ffffff"
                                    }

                                    // Version Info
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: qsTr("Aether Player — Version 1.2.1")
                                                color: "#00f2fe"
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                            }
                                            Text {
                                                text: qsTr("Copyright © 2026 Aether Development Team. All rights reserved.")
                                                color: "#666a8a"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Collapsible Synced Lyrics Panel
            Rectangle {
                id: lyricsSidePanel
                Layout.fillHeight: true
                Layout.preferredWidth: window.showLyricsPanel ? 300 : 0
                visible: Layout.preferredWidth > 0
                clip: true
                color: "#73191928"
                border.color: "#14ffffff"
                border.width: 1

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                }

                LyricsVisualizer {
                    anchors.fill: parent
                    anchors.margins: 20
                }
            }

            // Collapsible Right Sidebar Queue Panel (MusicBee Style!)
            Rectangle {
                id: rightQueuePanel
                Layout.fillHeight: true
                Layout.preferredWidth: window.showRightQueuePanel ? 300 : 0
                visible: Layout.preferredWidth > 0
                clip: true
                color: "#990d0d15" // glassmorphism dark overlay matching sidebar
                border.color: "#14ffffff"
                border.width: 1

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Playing Queue")
                            color: "#ffffff"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            text: player.queue.length + " " + (player.queue.length === 1 ? qsTr("track") : qsTr("tracks"))
                            color: "#666a8a"
                            font.pixelSize: 11
                            Layout.rightMargin: 8
                        }

                        Button {
                            id: globalClearQueueBtn
                            flat: true
                            contentItem: Text {
                                text: qsTr("Clear")
                                color: "#ff5555"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            onClicked: player.clearQueue()
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#14ffffff"
                    }

                    // Queue List
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: globalQueueListView
                            model: player.queue
                            spacing: 4

                            delegate: Rectangle {
                                width: globalQueueListView.width
                                height: 48
                                color: index === player.queueIndex ? "#1a00f2fe" : (gQueueMouse.containsMouse ? "#0dffffff" : "transparent")
                                border.color: index === player.queueIndex ? "#4000f2fe" : "transparent"
                                radius: 8

                                MouseArea {
                                    id: gQueueMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onDoubleClicked: {
                                        player.setQueue(player.queue, index);
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    // Thumbnail
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 4
                                        color: "#111111"
                                        clip: true
                                        Layout.alignment: Qt.AlignVCenter

                                        Image {
                                            source: modelData.coverPath || ""
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            visible: source !== ""
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            source: "image://theme/media-optical"
                                            width: 14
                                            height: 14
                                            visible: !modelData.coverPath
                                            opacity: 0.4
                                        }
                                    }

                                    // Track Info Column
                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            text: modelData.title || qsTr("Unknown Track")
                                            color: index === player.queueIndex ? "#00f2fe" : "#ffffff"
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: (modelData.artist || qsTr("Unknown Artist")) + " • " + (modelData.album || qsTr("Unknown Album")) + (modelData.discNo > 0 ? " — CD " + modelData.discNo : "")
                                            color: index === player.queueIndex ? "#7ae6ff" : "#666a8a"
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Time
                                    Text {
                                        text: {
                                            var mins = Math.floor((modelData.duration || 0) / 60);
                                            var secs = Math.floor((modelData.duration || 0) % 60);
                                            return mins + ":" + (secs < 10 ? "0" : "") + secs;
                                        }
                                        color: index === player.queueIndex ? "#00f2fe" : "#666a8a"
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Remove button
                                    Button {
                                        id: gQueueDelBtn
                                        flat: true
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: player.removeQueueIndex(index)
                                        contentItem: Text {
                                            text: "✕"
                                            color: "#ff5555"
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
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
            Layout.preferredHeight: window.isCompactMode ? 130 : 90
        }
    }

    // Global Album Details Modal Overlay
    AlbumModal {
        id: albumModal
        anchors.fill: parent
    }

    // Global Artist Details Modal Overlay
    ArtistModal {
        id: artistModal
        anchors.fill: parent
    }
    
    // Method to trigger album modal opening from child views
    function openAlbum(albumObj) {
        albumModal.openAlbum(albumObj);
    }

    // Method to trigger artist modal opening from child views
    function openArtist(artistName) {
        artistModal.loadArtistCatalog(artistName);
        artistModal.visible = true;
    }

    // Shortcut to exit Theater or Compact Mode using Escape
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (window.isTheaterMode) window.isTheaterMode = false;
            if (window.isCompactMode) window.isCompactMode = false;
        }
    }

    // Theater Mode Overlay
    Rectangle {
        id: theaterOverlay
        anchors.fill: parent
        color: "#12121c"
        visible: window.isTheaterMode
        z: 999 // Overlays everything!

        property bool showControls: true

        Timer {
            id: controlsTimer
            interval: 3000
            running: window.isTheaterMode
            repeat: false
            onTriggered: theaterOverlay.showControls = false
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: theaterOverlay.showControls ? Qt.ArrowCursor : Qt.BlankCursor
            onPositionChanged: {
                theaterOverlay.showControls = true;
                controlsTimer.restart();
            }
            onClicked: {
                theaterOverlay.showControls = true;
                controlsTimer.restart();
            }
        }

        // Ambient Background (low opacity album art over gradient)
        Image {
            id: theaterAmbientBg
            source: player.currentTrack.coverPath || ""
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0.15
            visible: source !== ""
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#cc000000" }
            }
        }

        // Close Button
        Button {
            visible: theaterOverlay.showControls
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 24
            flat: true
            onClicked: window.isTheaterMode = false
            contentItem: Item {
                width: 16
                height: 16
                Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: 45; radius: 1 }
                Rectangle { anchors.centerIn: parent; width: 16; height: 2; color: "#ffffff"; rotation: -45; radius: 1 }
            }
        }

        RowLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1000)
            height: Math.min(parent.height - 120, 600)
            spacing: 80

            // Left Pane (Visuals & Info)
            ColumnLayout {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                spacing: 20
                Layout.alignment: Qt.AlignVCenter

                // Album Art
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 260
                    color: "#111111"
                    radius: 16
                    Layout.alignment: Qt.AlignHCenter
                    clip: true

                    Image {
                        source: player.currentTrack.coverPath || ""
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: source !== ""
                    }

                    Image {
                        anchors.centerIn: parent
                        source: "image://theme/media-optical"
                        width: 80
                        height: 80
                        visible: !player.currentTrack.coverPath
                        opacity: 0.4
                    }
                }

                // Track details
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        text: player.currentTrack.title || qsTr("Not Playing")
                        color: "#ffffff"
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: (player.currentTrack.artist || "") + ((player.currentTrack.album) ? " — " + player.currentTrack.album : "")
                        color: "#a0a4c5"
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Scrubber
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Slider {
                        id: theaterScrubber
                        Layout.fillWidth: true
                        from: 0
                        to: player.duration > 0 ? player.duration : 1
                        value: player.position
                        onMoved: player.setPosition(value)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: playerBar.formatTime(player.position)
                            color: "#9ea2c0"
                            font.pixelSize: 12
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: playerBar.formatTime(player.duration)
                            color: "#9ea2c0"
                            font.pixelSize: 12
                        }
                    }
                }

                // Playback buttons
                RowLayout {
                    spacing: 24
                    Layout.alignment: Qt.AlignHCenter

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

                    Button {
                        width: 54
                        height: 54
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
                                Rectangle { width: 5; height: 20; color: "#1a1a2a"; radius: 1 }
                                Rectangle { width: 5; height: 20; color: "#1a1a2a"; radius: 1 }
                            }
                            Canvas {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 1.5
                                width: 16
                                height: 18
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
                }
            }

            // Right Pane: Synced Scrolling Lyrics visualizer (takes half of display in theater mode)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                clip: true

                LyricsVisualizer {
                    anchors.fill: parent
                }
            }
        }
    }

    Popup {
        id: saveColDialog
        x: (window.width - width) / 2
        y: (window.height - height) / 2
        width: 320
        height: 240
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
            anchors.margins: 20
            spacing: 12

            Text {
                text: qsTr("Save as Smart Collection")
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.Bold
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: qsTr("Collection Name"); color: "#9ea2c0"; font.pixelSize: 11 }
                TextField {
                    id: saveColNameInput
                    Layout.fillWidth: true
                    color: "#ffffff"
                    background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 6 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: qsTr("Display Mode"); color: "#9ea2c0"; font.pixelSize: 11 }
                ComboBox {
                    id: saveColDisplayCombo
                    Layout.fillWidth: true
                    model: ["Track List View", "Album Cover Grid"]
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Cancel")
                    onClicked: saveColDialog.close()
                }
                Button {
                    text: qsTr("Save")
                    highlighted: true
                    onClicked: {
                        var name = saveColNameInput.text.trim();
                        if (name === "") return;
                        var colId = "col_" + Date.now();
                        var activeRules = [];
                        for (var i = 0; i < window.djRulesModel.length; ++i) {
                            activeRules.push({
                                field: window.djRulesModel[i].field,
                                operator: window.djRulesModel[i].operator,
                                value: window.djRulesModel[i].value
                            });
                        }
                        database.saveCollection(colId, name, "", saveColDisplayCombo.currentText, activeRules);
                        saveColDialog.close();
                        saveColNameInput.text = "";
                    }
                }
            }
        }
    }
}
