import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

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

        // Collections Grid
        GridView {
            id: colGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 194
            cellHeight: 265
            clip: true
            model: database.collections

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

                property var matchedTracks: root.getCollectionTracks(modelData.rules)

                MouseArea {
                    id: colMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        var relativePos = mapToItem(colPlayBtn, mouse.x, mouse.y);
                        if (colPlayBtn.contains(relativePos)) {
                            return;
                        }
                        
                        // Mock as album and open details modal
                        var mockAlbum = {
                            id: modelData.id,
                            name: modelData.name,
                            artist: qsTr("Smart Collection"),
                            year: 0,
                            genre: "",
                            coverPath: modelData.coverPath || "",
                            displayMode: modelData.displayMode || "tracks",
                            tracks: matchedTracks,
                            discs: [1],
                            totalDuration: matchedTracks.reduce(function(acc, val) { return acc + (val.duration || 0); }, 0)
                        };
                        window.openAlbum(mockAlbum);
                    }
                    onDoubleClicked: {
                        if (matchedTracks.length > 0) {
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
                            source: modelData.coverPath || ""
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            visible: source != ""
                        }

                        Image {
                            anchors.centerIn: parent
                            source: "image://theme/bookmarks"
                            width: 50
                            height: 50
                            visible: colCover.source == ""
                            opacity: 0.5
                        }

                        // Play Button Overlay
                        Rectangle {
                            anchors.fill: parent
                            color: "#80000000"
                            opacity: colMouse.containsMouse ? 1.0 : 0.0
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
                                    if (parent.parent.parent.matchedTracks.length > 0) {
                                        player.setQueue(parent.parent.parent.matchedTracks, 0);
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
                        text: matchedTracks.length + " matching track" + (matchedTracks.length === 1 ? "" : "s")
                        color: "#9ea2c0"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Edit / Delete buttons row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24

                        Button {
                            flat: true
                            onClicked: editCollection(modelData)
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
                            onClicked: database.deleteCollection(modelData.id)
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
            height: 570
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

                // Rules
                Text { text: qsTr("Rules (AND conditions)"); color: "#ffffff"; font.pixelSize: 13 }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        id: rulesListContainer
                        width: parent.width
                        spacing: 10

                        Repeater {
                            id: rulesRepeater
                            model: editDialog.rulesModel

                            delegate: RowLayout {
                                width: parent.width
                                spacing: 8

                                property string fieldVal: modelData.field || "album"
                                property string opVal: modelData.operator || "contains"
                                property string textVal: modelData.value || ""

                                ComboBox {
                                    id: fieldCombo
                                    model: ["Album", "Artist", "Genre", "Title", "FilePath"]
                                    currentIndex: getIndex(modelData.field)
                                    Layout.preferredWidth: 100
                                    
                                    function getIndex(f) {
                                        if (f === "artist") return 1;
                                        if (f === "genre") return 2;
                                        if (f === "title") return 3;
                                        if (f === "filePath") return 4;
                                        return 0; // album
                                    }
                                    
                                    function getFieldKey() {
                                        var idx = currentIndex;
                                        if (idx === 1) return "artist";
                                        if (idx === 2) return "genre";
                                        if (idx === 3) return "title";
                                        if (idx === 4) return "filePath";
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
                                }

                                Button {
                                    id: suggestBtn
                                    icon.name: "arrow-down"
                                    flat: true
                                    icon.width: 14
                                    icon.height: 14
                                    visible: fieldCombo.currentIndex === 0 || fieldCombo.currentIndex === 1 || fieldCombo.currentIndex === 2
                                    onClicked: suggestionsMenu.open()

                                    Menu {
                                        id: suggestionsMenu
                                        y: parent.height
                                        width: 220

                                        Repeater {
                                            model: {
                                                var f = fieldCombo.currentIndex;
                                                if (f === 1) return database.allArtists;
                                                if (f === 2) return database.allGenres;
                                                if (f === 0) return database.allAlbums;
                                                return [];
                                            }
                                            delegate: MenuItem {
                                                text: modelData
                                                onTriggered: {
                                                    ruleValueInput.text = modelData;
                                                }
                                            }
                                        }
                                    }
                                }

                                Button {
                                    icon.name: "list-remove"
                                    flat: true
                                    onClicked: {
                                        // Update local model by removing this index
                                        var current = editDialog.rulesModel;
                                        current.splice(index, 1);
                                        editDialog.rulesModel = []; // trigger re-eval
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
                                    var f = item.children[0].getFieldKey();
                                    var o = item.children[1].getOpKey();
                                    var v = item.children[2].text;
                                    updatedRules.push({ field: f, operator: o, value: v });
                                }
                            }

                            var displayMode = colDisplayModeCombo.currentIndex === 1 ? "albums" : "tracks";
                            database.saveCollection(editDialog.colId, colNameInput.text.trim(), colCoverInput.text.trim(), displayMode, updatedRules);
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
            editDialog.rulesModel = [{ field: "album", operator: "contains", value: "" }];
        }
        editDialog.visible = true;
    }

    // Helper confirmation dialog for QML
    function confirm(text) {
        // Simple mock confirmation since standard dialogs are heavier
        return true; // Auto confirmed for now to simplify
    }
}
