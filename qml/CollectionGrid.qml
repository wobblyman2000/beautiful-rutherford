import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property string currentFolderPath: ""

    // JS helper to group collections by their folder path dynamically
    function getVisibleItems(collections, activeFolder) {
        var list = [];
        var seenFolders = {};
        
        var folderPrefix = activeFolder;
        if (folderPrefix !== "" && !folderPrefix.endsWith("/")) {
            folderPrefix += "/";
        }
        
        for (var i = 0; i < collections.length; ++i) {
            var col = collections[i];
            var folder = col.folder || "";
            
            if (activeFolder === "") {
                // We are in the root
                if (folder === "") {
                    list.push({ type: "collection", id: col.id, name: col.name, data: col });
                } else {
                    // This collection is in a subfolder
                    var firstSlash = folder.indexOf("/");
                    var subName = firstSlash === -1 ? folder : folder.substring(0, firstSlash);
                    if (!seenFolders[subName]) {
                        seenFolders[subName] = true;
                        list.push({ type: "folder", name: subName, path: subName });
                    }
                }
            } else {
                // We are in some subfolder, e.g. "60s Compilations"
                if (folder === activeFolder) {
                    list.push({ type: "collection", id: col.id, name: col.name, data: col });
                } else if (folder.startsWith(folderPrefix)) {
                    // This is a sub-subfolder
                    var relativePath = folder.substring(folderPrefix.length);
                    var nextSlash = relativePath.indexOf("/");
                    var subName = nextSlash === -1 ? relativePath : relativePath.substring(0, nextSlash);
                    var fullPath = folderPrefix + subName;
                    if (!seenFolders[subName]) {
                        seenFolders[subName] = true;
                        list.push({ type: "folder", name: subName, path: fullPath });
                    }
                }
            }
        }
        
        // Sort: Folders first alphabetically, then Collections alphabetically
        list.sort(function(a, b) {
            if (a.type !== b.type) {
                return a.type === "folder" ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        });
        
        return list;
    }

    // Rules matching function (AND logic)
    function matchRules(track, rules) {
        if (!rules || rules.length === 0) return false;
        
        for (var i = 0; i < rules.length; ++i) {
            var rule = rules[i];
            var val = (track[rule.field] || "").toString().toLowerCase();
            var criteria = (rule.value || "").toLowerCase();
            var matched = false;

            switch (rule.operator) {
                case "contains":
                    matched = val.indexOf(criteria) !== -1;
                    break;
                case "is":
                    matched = (val === criteria);
                    break;
                case "starts_with":
                    matched = val.startsWith(criteria);
                    break;
                case "ends_with":
                    matched = val.endsWith(criteria);
                    break;
                case "not_contains":
                    matched = val.indexOf(criteria) === -1;
                    break;
            }

            if (!matched) return false; // Fails AND check
        }
        return true;
    }

    function getCollectionTracks(rules) {
        var allTracks = database.tracks;
        var matched = [];
        for (var i = 0; i < allTracks.length; ++i) {
            if (matchRules(allTracks[i], rules)) {
                matched.push(allTracks[i]);
            }
        }
        return matched;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: qsTr("Smart Collections")
                color: "#ffffff"
                font.pixelSize: 28
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("New Collection")
                onClicked: editCollection(null)
            }
        }

        // Breadcrumb Navigation Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "📁"
                font.pixelSize: 15
                color: "#666a8a"
            }

            Text {
                text: qsTr("Smart Collections")
                font.pixelSize: 14
                font.weight: root.currentFolderPath === "" ? Font.Bold : Font.Normal
                color: root.currentFolderPath === "" ? "#ffffff" : "#666a8a"
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.currentFolderPath !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.currentFolderPath !== "") {
                            root.currentFolderPath = "";
                        }
                    }
                }
            }

            Repeater {
                model: root.currentFolderPath === "" ? [] : root.currentFolderPath.split("/")
                delegate: RowLayout {
                    spacing: 8
                    Text { text: " > "; color: "#444866"; font.pixelSize: 12 }
                    Text {
                        text: modelData
                        font.pixelSize: 14
                        font.weight: index === (root.currentFolderPath.split("/").length - 1) ? Font.Bold : Font.Normal
                        color: index === (root.currentFolderPath.split("/").length - 1) ? "#00f2fe" : "#666a8a"
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: index !== (root.currentFolderPath.split("/").length - 1) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                var parts = root.currentFolderPath.split("/");
                                var newPath = parts.slice(0, index + 1).join("/");
                                root.currentFolderPath = newPath;
                            }
                        }
                    }
                }
            }
        }

        // Collections Grid
        GridView {
            id: colGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 194
            cellHeight: 265
            clip: true
            model: root.getVisibleItems(database.collections, root.currentFolderPath)

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: 170
                height: 240
                color: "#73191928"
                border.color: colMouse.containsMouse ? "#1effffff" : "#12ffffff"
                radius: 16
                clip: true

                property bool isFolder: modelData.type === "folder"
                property var colData: isFolder ? null : modelData.data
                property var matchedTracks: isFolder ? [] : root.getCollectionTracks(colData.rules)

                // Resolve cover art from collection settings or automatically from matched tracks
                property string autoCoverPath: {
                    if (isFolder) return "";
                    if (colData.coverPath && colData.coverPath !== "") {
                        return colData.coverPath;
                    }
                    for (var i = 0; i < matchedTracks.length; ++i) {
                        if (matchedTracks[i].coverPath && matchedTracks[i].coverPath !== "") {
                            return matchedTracks[i].coverPath;
                        }
                    }
                    return "";
                }

                MouseArea {
                    id: colMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: isFolder ? Qt.LeftButton : (Qt.LeftButton | Qt.RightButton)
                    onClicked: {
                        if (isFolder) {
                            root.currentFolderPath = modelData.path;
                            return;
                        }
                        if (mouse.button === Qt.RightButton) {
                            collectionContextMenu.targetTracks = matchedTracks;
                            collectionContextMenu.popup();
                            return;
                        }

                        var relativePos = mapToItem(colPlayBtn, mouse.x, mouse.y);
                        if (colPlayBtn.contains(relativePos)) {
                            return;
                        }
                        
                        // Mock as album and open details modal
                        var mockAlbum = {
                            id: colData.id,
                            name: colData.name,
                            artist: qsTr("Smart Collection"),
                            year: 0,
                            genre: "",
                            coverPath: parent.autoCoverPath,
                            displayMode: colData.displayMode || "tracks",
                            tracks: matchedTracks,
                            discs: [1],
                            totalDuration: matchedTracks.reduce(function(acc, val) { return acc + (val.duration || 0); }, 0)
                        };
                        window.openAlbum(mockAlbum);
                    }
                    onDoubleClicked: {
                        if (!isFolder && matchedTracks.length > 0) {
                            player.setQueue(matchedTracks, 0);
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Cover Art Wrapper
                    Rectangle {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 130
                        color: "#111111"
                        radius: 12
                        clip: true
                        Layout.alignment: Qt.AlignHCenter

                        Image {
                            id: colCover
                            source: parent.parent.autoCoverPath
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            visible: source != ""
                        }

                        Image {
                            anchors.centerIn: parent
                            source: isFolder ? "image://theme/folder" : "image://theme/bookmarks"
                            width: 50
                            height: 50
                            visible: isFolder || colCover.source == ""
                            opacity: isFolder ? 0.75 : 0.5
                        }

                        // Play Button Overlay
                        Rectangle {
                            anchors.fill: parent
                            color: "#80000000"
                            opacity: (!isFolder && colMouse.containsMouse && !albumModal.visible) ? 1.0 : 0.0
                            visible: opacity > 0.0

                            Button {
                                id: colPlayBtn
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
                                        anchors.horizontalCenterOffset: 1.5
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
                                    if (!isFolder && matchedTracks.length > 0) {
                                        player.setQueue(matchedTracks, 0);
                                    }
                                }
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
                        text: isFolder ? qsTr("Folder") : matchedTracks.length + " matching track" + (matchedTracks.length === 1 ? "" : "s")
                        color: "#9ea2c0"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Edit / Delete buttons row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        visible: !isFolder

                        Button {
                            flat: true
                            onClicked: editCollection(colData)
                            contentItem: Text {
                                text: qsTr("Edit")
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            flat: true
                            onClicked: database.deleteCollection(colData.id)
                            contentItem: Text {
                                text: qsTr("Delete")
                                color: "#ff5555"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }

    // Modal Dialog overlay for Creating/Editing Collections
    Rectangle {
        id: editDialog
        anchors.fill: parent
        color: "#a6000000"
        visible: false

        property string colId: ""
        property var rulesModel: []

        Rectangle {
            width: 500
            height: 640
            anchors.centerIn: parent
            color: "#1e1e30"
            border.color: "#14ffffff"
            radius: 16
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Text {
                    text: editDialog.colId === "" ? qsTr("Create Smart Collection") : qsTr("Edit Smart Collection")
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }

                // Name Input
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: qsTr("Collection Name"); color: "#ffffff"; font.pixelSize: 13 }
                    TextField {
                        id: colNameInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 8 }
                    }
                }

                // Cover Input
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: qsTr("Cover Image Path/URL (Optional)"); color: "#ffffff"; font.pixelSize: 13 }
                    TextField {
                        id: colCoverInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 8 }
                    }
                }

                // Display Mode Input
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: qsTr("Display Mode"); color: "#ffffff"; font.pixelSize: 13 }
                    ComboBox {
                        id: colDisplayModeCombo
                        Layout.fillWidth: true
                        model: ["Track List View", "Album Cover Grid"]
                    }
                }

                // Folder Input
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: qsTr("Folder (Optional, e.g. 60s Compilations)"); color: "#ffffff"; font.pixelSize: 13 }
                    TextField {
                        id: colFolderInput
                        Layout.fillWidth: true
                        color: "#ffffff"
                        placeholderText: qsTr("Leave blank for Root level")
                        background: Rectangle { color: "#33000000"; border.color: "#14ffffff"; radius: 8 }
                    }
                }

                // Rules
                Text { text: qsTr("Rules (AND conditions)"); color: "#ffffff"; font.pixelSize: 13 }

                ScrollView {
                    id: colRulesScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        id: rulesListContainer
                        width: colRulesScrollView.width - 24
                        spacing: 10

                        Repeater {
                            id: rulesRepeater
                            model: editDialog.rulesModel

                            delegate: RowLayout {
                                id: ruleRow
                                Layout.fillWidth: true
                                spacing: 8

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
                                    currentIndex: getIndex(modelData.field)
                                    Layout.preferredWidth: 110
                                    
                                    function getIndex(f) {
                                        if (f === "artist") return 1;
                                        if (f === "genre") return 2;
                                        if (f === "title") return 3;
                                        if (f === "filePath") return 4;
                                        if (f === "rating") return 5;
                                        if (f === "year") return 6;
                                        return 0; // album
                                    }
                                    
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
                                    model: ["Contains", "Is Equal", "Starts With", "Ends With", "Not Contain"]
                                    currentIndex: getIndex(modelData.operator)
                                    Layout.preferredWidth: 110

                                    function getIndex(o) {
                                        if (o === "is") return 1;
                                        if (o === "starts_with") return 2;
                                        if (o === "ends_with") return 3;
                                        if (o === "not_contains") return 4;
                                        return 0; // contains
                                    }

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
                                    font.pixelSize: 13
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
                                    id: suggestBtn
                                    flat: true
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 28
                                    contentItem: Text { text: "▾"; color: "#9ea2c0"; font.bold: true; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    visible: fieldCombo.currentIndex === 0 || fieldCombo.currentIndex === 1 || fieldCombo.currentIndex === 2 || fieldCombo.currentIndex === 6
                                    onClicked: suggestionsMenu.open()

                                    Menu {
                                        id: suggestionsMenu
                                        y: parent.height
                                        width: 220

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
                                                }  return filtered;
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
                                        var current = editDialog.rulesModel;
                                        current.splice(index, 1);
                                        editDialog.rulesModel = [];
                                        editDialog.rulesModel = current;
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Button {
                        text: qsTr("Add Condition")
                        icon.name: "list-add"
                        onClicked: {
                            var current = editDialog.rulesModel;
                            current.push({ field: "album", operator: "contains", value: "" });
                            editDialog.rulesModel = [];
                            editDialog.rulesModel = current;
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: qsTr("Cancel")
                        onClicked: editDialog.visible = false
                    }

                    Button {
                        text: qsTr("Save")
                        onClicked: {
                            // Extract updated rules list from active inputs
                            var updatedRules = [];
                            for (var i = 0; i < rulesRepeater.count; ++i) {
                                var item = rulesRepeater.itemAt(i);
                                if (item) {
                                    var f = item.getFieldKey();
                                    var o = item.getOpKey();
                                    var v = item.getValue();
                                    updatedRules.push({ field: f, operator: o, value: v });
                                }
                            }

                            var displayMode = colDisplayModeCombo.currentIndex === 1 ? "albums" : "tracks";
                            database.saveCollection(editDialog.colId, colNameInput.text.trim(), colCoverInput.text.trim(), displayMode, updatedRules, colFolderInput.text.trim());
                            editDialog.visible = false;
                        }
                    }
                }
            }
        }
    }

    function editCollection(collection) {
        if (collection) {
            editDialog.colId = collection.id;
            colNameInput.text = collection.name;
            colCoverInput.text = collection.coverPath || "";
            colDisplayModeCombo.currentIndex = (collection.displayMode === "albums") ? 1 : 0;
            colFolderInput.text = collection.folder || "";
            // Construct a deep copy of rules list
            var list = [];
            for (var i = 0; i < collection.rules.length; ++i) {
                list.push({
                    field: collection.rules[i].field,
                    operator: collection.rules[i].operator,
                    value: collection.rules[i].value
                });
            }
            editDialog.rulesModel = list;
        } else {
            editDialog.colId = "";
            colNameInput.text = "";
            colCoverInput.text = "";
            colDisplayModeCombo.currentIndex = 0;
            colFolderInput.text = root.currentFolderPath;
            editDialog.rulesModel = [{ field: "album", operator: "contains", value: "" }];
        }
        editDialog.visible = true;
    }

    // Helper confirmation dialog for QML
    function confirm(text) {
        // Simple mock confirmation since standard dialogs are heavier
        return true; // Auto confirmed for now to simplify
    }

    Menu {
        id: collectionContextMenu
        
        property var targetTracks: null
        
        MenuItem {
            text: qsTr("Play Collection Now")
            onTriggered: {
                if (collectionContextMenu.targetTracks && collectionContextMenu.targetTracks.length > 0) {
                    player.setQueue(collectionContextMenu.targetTracks, 0);
                }
            }
        }
        MenuItem {
            text: qsTr("Play Collection Next")
            onTriggered: {
                if (collectionContextMenu.targetTracks && collectionContextMenu.targetTracks.length > 0) {
                    player.playNextAlbum(collectionContextMenu.targetTracks);
                }
            }
        }
        MenuItem {
            text: qsTr("Queue Collection Last")
            onTriggered: {
                if (collectionContextMenu.targetTracks && collectionContextMenu.targetTracks.length > 0) {
                    player.queueLastAlbum(collectionContextMenu.targetTracks);
                }
            }
        }
    }
}
