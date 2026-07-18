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
                color: window.themeAccentColor
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
            component NavButton : Item {
                property string text: ""
                property string pageKey: ""
                property string iconName: ""
                
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                
                Rectangle {
                    anchors.fill: parent
                    color: window.activePage === pageKey ? Qt.rgba(window.themeAccentColor.r, window.themeAccentColor.g, window.themeAccentColor.b, 0.15) : (navMouse.containsMouse ? "#08ffffff" : "transparent")
                    radius: 8
                    
                    RowLayout {
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
                            text: parent.parent.parent.text
                            color: window.activePage === pageKey ? window.themeAccentColor : "#9ea2c0"
                            font.pixelSize: 15
                            font.weight: window.activePage === pageKey ? Font.DemiBold : Font.Normal
                        }
                    }
                }

                MouseArea {
                    id: navMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.activePage = pageKey
                }
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

            Item {
                id: quitSidebarBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                
                Rectangle {
                    anchors.fill: parent
                    color: quitMouse.containsMouse ? "#1aff5555" : "transparent"
                    radius: 8
                    
                    RowLayout {
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
                }

                MouseArea {
                    id: quitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }
        }
    }
}
