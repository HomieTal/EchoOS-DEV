/* SPDX-FileCopyrightText: no
 * SPDX-License-Identifier: CC0-1.0
 *
 * MAD Installer — creative looping slideshow.
 * Conservative QML only (no QtGraphicalEffects, no ScriptAction): three
 * scenes cross-fade on a simple timer and loop forever. Proven pattern
 * from the previously-working slideshow, with new animated art.
 */

import QtQuick 2.7

Rectangle {
    id: root
    color: "#16181C"
    property int scene: 0

    Timer {
        interval: 6000; running: true; repeat: true
        onTriggered: root.scene = (root.scene + 1) % 3
    }

    // ambient blobs
    Rectangle { width: 320; height: 320; radius: 160; x: -60; y: -80; color: "#1B2233"; opacity: 0.8 }
    Rectangle { width: 260; height: 260; radius: 130; x: parent.width - 180; y: parent.height - 160; color: "#141B2B"; opacity: 0.9 }

    // ===== SCENE 0 — Welcome =====
    Item {
        anchors.fill: parent
        opacity: root.scene === 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }

        Rectangle { width: 300; height: 300; radius: 150; anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            color: "transparent"; border.color: "#2C3654"; border.width: 2 }
        Rectangle { width: 220; height: 220; radius: 110; anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            color: "transparent"; border.color: "#3D4A6E"; border.width: 2 }
        Rectangle {
            width: 120; height: 138; radius: 14
            color: "#6952E8"; opacity: 0.95
            anchors.centerIn: parent; anchors.verticalCenterOffset: -20
            Rectangle { width: 70; height: 70; radius: 8; color: "#927DFF"; opacity: 0.8
                anchors.centerIn: parent }
        }
        Rectangle {
            width: 90; height: 104; radius: 11
            color: "#8A76FF"; opacity: 0.55
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 120; anchors.verticalCenterOffset: -60
            SequentialAnimation on rotation {
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 360; duration: 20000 }
            }
        }
        Image { source: "file:/" + Branding.imagePath(Branding.ProductLogo)
            width: 64; height: 64; fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 36 }
        Text { anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 46
            text: qsTr("Welcome to %1").arg(Branding.string(Branding.ProductName))
            color: "#FFFFFF"; font.pixelSize: 26; font.weight: Font.Bold }
        Text { anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 22
            text: "Meet MAD Installer"
            color: "#8A93FF"; font.pixelSize: 14; font.weight: Font.DemiBold }
    }

    // ===== SCENE 1 — Installing =====
    Item {
        anchors.fill: parent
        opacity: root.scene === 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }

        Item { anchors.centerIn: parent; anchors.verticalCenterOffset: -30
            width: 170; height: 170
            Rectangle { width: 14; height: 14; radius: 7; color: "#6952E8"
                anchors.horizontalCenter: parent.horizontalCenter; y: 0 }
            Rectangle { width: 14; height: 14; radius: 7; color: "#927DFF"
                anchors.horizontalCenter: parent.horizontalCenter; y: 156 }
            Rectangle { width: 14; height: 14; radius: 7; color: "#20C987"
                x: 0; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 14; height: 14; radius: 7; color: "#3D4A6E"
                x: 156; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 120; height: 120; radius: 60; anchors.centerIn: parent
                color: "transparent"; border.color: "#2C3654"; border.width: 2 }
            RotationAnimation on rotation { loops: Animation.Infinite
                from: 0; to: 360; duration: 6000 }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 44
            text: qsTr("Installing %1").arg(Branding.string(Branding.ProductName))
            color: "#FFFFFF"; font.pixelSize: 24; font.weight: Font.Bold }
        Text { anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 80
            text: qsTr("Your system is being built — offline, secure, yours.")
            color: "#8A93FF"; font.pixelSize: 13 }
        Text { anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            text: "MAD Installer — Powered by Echo OS"
            color: "#5A6480"; font.pixelSize: 12 }
    }

    // ===== SCENE 2 — Waves =====
    Item {
        anchors.fill: parent
        opacity: root.scene === 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }

        Rectangle { width: parent.width * 1.4; height: 220; radius: 110
            color: "#1B2440"; opacity: 0.85
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
            anchors.bottomMargin: -80 }
        Rectangle { width: parent.width * 1.4; height: 160; radius: 80
            color: "#232C4E"; opacity: 0.8
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
            anchors.bottomMargin: -50
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { from: -40; to: 40; duration: 5000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 40; to: -40; duration: 5000; easing.type: Easing.InOutSine }
            } }
        Image { source: "file:/" + Branding.imagePath(Branding.ProductWelcome)
            width: 200; height: 100; fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent; anchors.verticalCenterOffset: -50 }
        Text { anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 40
            text: "MAD Installer — Powered by Echo OS"
            color: "#FFFFFF"; font.pixelSize: 16; font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 70
            text: qsTr("Simple · Flexible · Intelligent")
            color: "#8A93FF"; font.pixelSize: 12 }
    }
}
