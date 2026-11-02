/* SPDX-FileCopyrightText: no
 * SPDX-License-Identifier: CC0-1.0
 *
 * MAD Installer — custom finished view-step (finishedq override).
 *
 * Replaces the stock finished page with the Professional White completion
 * screen: success mark, "Welcome to a New Experience", Restart Now and
 * Continue Testing. Same functional contract as the stock finishedq.qml
 * (config.doRestart / ViewManager.quit).
 */

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "#F5F6FA"

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 1000)
        height: Math.min(parent.height - 56, 560)
        radius: 22
        color: "#FFFFFF"
        border.color: "#E8EAF0"

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(420, parent.width * 0.46)
            spacing: 0

            Text {
                text: qsTr("Complete")
                color: "#6952E8"; font.pixelSize: 11; font.weight: Font.Bold
                font.letterSpacing: 1.4
                font.family: "Inter"
            }
            Item { width: 1; height: 8 }
            Text {
                text: qsTr("Welcome to a<br>New Experience")
                color: "#171923"; font.pixelSize: 30; font.weight: Font.Bold
                font.family: "Inter"
                lineHeight: 1.15
            }
            Item { width: 1; height: 14 }
            Text {
                width: parent.width
                text: qsTr("%1 is ready. Your system has been successfully installed.").arg(Branding.string(Branding.VersionedName))
                color: "#737987"; font.pixelSize: 14
                wrapMode: Text.WordWrap
                font.family: "Inter"
            }
            Item { width: 1; height: 26 }

            Button {
                width: 300; height: 48
                text: qsTr("Restart Now")
                font.pixelSize: 14; font.weight: Font.DemiBold
                hoverEnabled: true
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 24
                    color: parent.hovered ? "#927DFF" : "#6952E8"
                }
                onClicked: config.doRestart(true)
            }
            Item { width: 1; height: 8 }
            Button {
                flat: true
                text: qsTr("Continue Testing")
                font.pixelSize: 13; font.weight: Font.DemiBold
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: "#737987"
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle { color: "transparent" }
                onClicked: ViewManager.quit()
            }
        }

        // right: success panel
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 24
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.55
            radius: 18
            color: "#EFEAFF"

            Rectangle { width: 150; height: 150; radius: 75; x: 10; y: 14; color: "#C9BEFF"; opacity: 0.5 }
            Rectangle { width: 120; height: 120; radius: 60; x: parent.width - 120; y: parent.height - 120; color: "#A9EFD6"; opacity: 0.55 }

            Rectangle {
                width: 96; height: 96; radius: 48
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -40
                color: "#20C987"
                Text {
                    anchors.centerIn: parent
                    text: "✓"; color: "#FFFFFF"; font.pixelSize: 44; font.weight: Font.Bold
                }
            }
            Image {
                source: "file:/" + Branding.imagePath(Branding.ProductWelcome)
                width: 84; height: 84
                fillMode: Image.PreserveAspectFit
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 62
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: qsTr("%1 · Installed with MAD Installer").arg(Branding.string(Branding.VersionedName))
                color: "#737987"; font.pixelSize: 12
                font.family: "Inter"
            }
        }
    }
}
