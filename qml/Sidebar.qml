import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#990d0d15"
    border.color: "#0dffffff"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // Brand Logo
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60

            Text {
                text: "Aether"
                color: "#00f2fe"
                font.pixelSize: 28
                font.weight: Font.Bold
                anchors.centerIn: parent
                font.letterSpacing: 1
                
                // Cyan neon glow effect
                layer.enabled: true
            }
        }

        // Navigation Items
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Layout.alignment: Qt.AlignTop

            // Button helper
            component NavButton : Button {
                property string pageKey: ""
                property string iconName: ""
                
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                flat: true
                focusPolicy: Qt.NoFocus
                
                contentItem: RowLayout {
                    spacing: 12
                    anchors.fill: parent
                    anchors.leftMargin: 12

                    Image {
                        source: "image://theme/" + iconName
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        opacity: window.activePage === pageKey ? 1.0 : 0.6
                    }

                    Text {
                        text: parent.parent.text
                        color: window.activePage === pageKey ? "#00f2fe" : "#9ea2c0"
                        font.pixelSize: 15
                        font.weight: window.activePage === pageKey ? Font.DemiBold : Font.Normal
                    }
                }

                background: Rectangle {
                    color: window.activePage === pageKey ? "#1a00f2fe" : (parent.hovered ? "#08ffffff" : "transparent")
                    radius: 8
                }

                onClicked: window.activePage = pageKey
            }

            NavButton {
                text: qsTr("Albums")
                pageKey: "albums"
                iconName: "media-optical"
            }

            NavButton {
                text: qsTr("Artists")
                pageKey: "artists"
                iconName: "user-identity"
            }

            NavButton {
                text: qsTr("Genres")
                pageKey: "genres"
                iconName: "label"
            }

            NavButton {
                text: qsTr("Collections")
                pageKey: "collections"
                iconName: "bookmarks"
            }

            NavButton {
                text: qsTr("Auto-DJ")
                pageKey: "autodj"
                iconName: "media-playlist-shuffle"
            }

            NavButton {
                text: qsTr("Settings")
                pageKey: "settings"
                iconName: "settings-configure"
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#14ffffff"
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }

            Button {
                id: quitSidebarBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                flat: true
                focusPolicy: Qt.NoFocus
                
                contentItem: RowLayout {
                    spacing: 12
                    anchors.fill: parent
                    anchors.leftMargin: 12

                    Image {
                        source: "image://theme/system-log-out"
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        opacity: 0.6
                    }

                    Text {
                        text: qsTr("Quit")
                        color: "#ff5555"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }

                background: Rectangle {
                    color: quitSidebarBtn.hovered ? "#1aff5555" : "transparent"
                    radius: 8
                }

                onClicked: Qt.quit()
            }
        }
    }
}
