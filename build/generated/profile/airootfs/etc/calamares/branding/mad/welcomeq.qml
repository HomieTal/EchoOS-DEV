/* SPDX-FileCopyrightText: no
 * SPDX-License-Identifier: CC0-1.0
 *
 * MAD Installer — full prototype flow as one QML view-step.
 * Strictly structured: one Item per page state, absolute geometry inside
 * the card (no anchor-driven Columns), clamped to the card size.
 * States: 0 intro · 1 language · 2 keyboard · 3 mode · 4 packages
 * Real effects: language (config.localeIndex), keyboard (Global
 * keyboardLayout/keyboardVariant → contextualprocess), mode/packages
 * (Global inserts — prototype-level on the offline backend).
 */

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick 2.7
import QtQuick.Controls 2.2

Rectangle {
    id: root
    color: "#F5F6FA"
    property int page: 0
    onPageChanged: if (typeof Global !== "undefined") Global.insert("madStage", page === 0 ? 1 : 2)
    property string selMode: "Recommended"
    property string selLayout: "us"

    function nextStep() {
        if (typeof ViewManager !== "undefined") ViewManager.next()
    }


    component MadButton: Button {
        hoverEnabled: true
        font.pixelSize: 14
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
    }
    // card geometry (clamped)
    readonly property int cw: Math.min(parent.width - 40, 960)
    readonly property int ch: Math.min(parent.height - 40, 560)
    readonly property int cx: (parent.width - cw) / 2
    readonly property int cy: (parent.height - ch) / 2
    // left column width (content), right panel fixed
    readonly property int colW: cw - 380
    readonly property int panelW: 330

    // ---- the card --------------------------------------------------------
    Rectangle {
        x: root.cx; y: root.cy
        width: root.cw; height: root.ch
        radius: 22
        color: "#FFFFFF"
        border.color: "#E8EAF0"

        // ======== PAGE 0 — INTRO ========
        Item {
            visible: root.page === 0
            anchors.fill: parent

            Image { x: 44; y: 44; width: 46; height: 46
                fillMode: Image.PreserveAspectFit
                source: "file:/" + Branding.imagePath(Branding.ProductLogo) }
            Text { x: 44; y: 120; text: qsTr("Welcome to %1").arg(Branding.string(Branding.ProductName))
                color: "#171923"; font.pixelSize: 28; font.weight: Font.Bold }
            Text { x: 44; y: 162; text: "Meet MAD Installer"
                color: "#6952E8"; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { x: 44; y: 194; width: Math.min(400, root.colW - 60)
                text: qsTr("Your system, your choices. Install %1 with a simple, flexible and intelligent installation experience.").arg(Branding.string(Branding.ProductName))
                color: "#737987"; font.pixelSize: 14; wrapMode: Text.WordWrap }
            MadButton {
                x: 44; y: Math.min(258, parent.height - 110)
                width: Math.min(320, root.colW - 60); height: 48
                text: qsTr("Let's get started")
                onClicked: root.page = 1
            }
            Text { x: 44; y: Math.min(322, parent.height - 52)
                text: qsTr("Skip introduction"); color: "#737987"; font.pixelSize: 13
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextStep() } }
        }

        // ======== PAGE 1 — LANGUAGE ========
        Item {
            visible: root.page === 1
            anchors.fill: parent

            Text { x: 44; y: 34; text: "CONFIGURE YOUR SYSTEM"
                color: "#6952E8"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1 }
            Text { x: 44; y: 54; text: qsTr("Choose Your Language")
                color: "#171923"; font.pixelSize: 23; font.weight: Font.Bold }
            Text { x: 44; y: 88; text: qsTr("Select the language you want to use during installation.")
                color: "#737987"; font.pixelSize: 13 }
            TextField {
                x: 44; y: 116
                width: root.colW - 60; height: 40
                placeholderText: qsTr("Search languages...")
                font.pixelSize: 13
                background: Rectangle { radius: 10; color: "#FFFFFF"
                    border.color: parent.activeFocus ? "#927DFF" : "#E8EAF0"
                    border.width: parent.activeFocus ? 2 : 1 }
            }
            Rectangle {
                x: 44; y: 168
                width: root.colW - 60
                height: Math.max(140, parent.height - 250)
                radius: 12; color: "#FFFFFF"; border.color: "#E8EAF0"; clip: true
                ListView {
                    id: langList
                    anchors.fill: parent
                    model: config.languagesModel
                    currentIndex: config.localeIndex
                    onCurrentIndexChanged: if (root.page === 1) config.localeIndex = currentIndex
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        width: langList.width; height: 42
                        color: ListView.isCurrentItem ? "#F0EDFF" : "transparent"
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top
                            anchors.bottom: parent.bottom; width: 3
                            color: ListView.isCurrentItem ? "#6952E8" : "transparent" }
                        Text { anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 14
                            text: label; color: "#171923"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 14
                            text: englishLabel; color: "#737987"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent
                            onClicked: langList.currentIndex = index }
                    }
                }
            }
            Button {
                x: 44; y: parent.height - 64
                flat: true; text: "← Back"
                onClicked: root.page = 0
            }
            Rectangle { x: 150; y: parent.height - 46; width: 110; height: 5; radius: 3
                color: "#E8EAF0"
                Rectangle { width: 46; height: 5; radius: 3; color: "#6952E8" } }
            MadButton {
                x: parent.width - root.panelW - 40 - 150; y: parent.height - 72
                width: 150; height: 48
                text: qsTr("Continue")
                onClicked: root.page = 2
            }
        }

        // ======== PAGE 2 — KEYBOARD ========
        Item {
            visible: root.page === 2
            anchors.fill: parent

            Text { x: 44; y: 34; text: "CONFIGURE YOUR SYSTEM"
                color: "#6952E8"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1 }
            Text { x: 44; y: 54; text: qsTr("Set Up Your Keyboard")
                color: "#171923"; font.pixelSize: 23; font.weight: Font.Bold }
            Text { x: 44; y: 88; text: qsTr("Pick a layout and test it below.")
                color: "#737987"; font.pixelSize: 13 }
            TextField {
                x: 44; y: 112
                width: root.colW - 60; height: 34
                placeholderText: qsTr("Search layouts...")
                font.pixelSize: 13
                background: Rectangle { radius: 10; color: "#FFFFFF"
                    border.color: parent.activeFocus ? "#927DFF" : "#E8EAF0"
                    border.width: parent.activeFocus ? 2 : 1 }
            }
            Rectangle {
                x: 44; y: 154
                width: root.colW - 60
                height: Math.max(84, parent.height - 278)
                radius: 12; color: "#FFFFFF"; border.color: "#E8EAF0"; clip: true
                Flickable {
                    anchors.fill: parent
                    contentHeight: kbdCol.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                Column {
                    id: kbdCol
                    width: parent.width
                    Repeater {
                        model: ListModel {
                            ListElement { name: "English (US)"; layout: "us"; region: "Default" }
                            ListElement { name: "English (UK)"; layout: "gb"; region: "United Kingdom" }
                            ListElement { name: "German — QWERTZ"; layout: "de"; region: "Germany" }
                            ListElement { name: "French — AZERTY"; layout: "fr"; region: "France" }
                            ListElement { name: "Spanish"; layout: "es"; region: "Spain" }
                        }
                        delegate: Rectangle {
                            width: parent.width; height: 36
                            color: root.selLayout === layout ? "#F0EDFF" : "transparent"
                            Rectangle { anchors.left: parent.left; anchors.top: parent.top
                                anchors.bottom: parent.bottom; width: 3
                                color: root.selLayout === layout ? "#6952E8" : "transparent" }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: 14
                                text: name; color: "#171923"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right; anchors.rightMargin: 14
                                text: region; color: "#737987"; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent
                                onClicked: {
                                    root.selLayout = layout
                                    if (typeof Global !== "undefined") {
                                        Global.insert("keyboardLayout", layout)
                                        Global.insert("keyboardVariant", "")
                                    }
                                } }
                        }
                    }
                    }
                }
            }
            Text { x: 44; y: parent.height - 116; text: qsTr("Test your keyboard")
                color: "#171923"; font.pixelSize: 12; font.weight: Font.DemiBold }
            TextField {
                x: 44; y: parent.height - 96
                width: root.colW - 60; height: 34
                placeholderText: qsTr("Type here to try the layout...")
                font.pixelSize: 13
                background: Rectangle { radius: 10; color: "#FFFFFF"
                    border.color: parent.activeFocus ? "#927DFF" : "#E8EAF0"
                    border.width: parent.activeFocus ? 2 : 1 }
            }
            Button {
                x: 44; y: parent.height - 52
                flat: true; text: "← Back"
                onClicked: root.page = 1
            }
            Rectangle { x: 150; y: parent.height - 40; width: 110; height: 5; radius: 3
                color: "#E8EAF0"
                Rectangle { width: 62; height: 5; radius: 3; color: "#6952E8" } }
            MadButton {
                x: parent.width - root.panelW - 40 - 150; y: parent.height - 56
                width: 150; height: 40
                text: qsTr("Continue")
                onClicked: root.page = 3
            }
        }

        // ======== PAGE 3 — INSTALL MODE ========
        Item {
            visible: root.page === 3
            anchors.fill: parent

            Text { x: 44; y: 34; text: "CONFIGURE YOUR SYSTEM"
                color: "#6952E8"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1 }
            Text { x: 44; y: 54
                text: qsTr("How would you like to install %1?").arg(Branding.string(Branding.ProductName))
                color: "#171923"; font.pixelSize: 23; font.weight: Font.Bold }
            Text { x: 44; y: 88; text: qsTr("Pick the installation profile that fits you.")
                color: "#737987"; font.pixelSize: 13 }

            Repeater {
                model: ListModel {
                    ListElement { name: "Recommended"; desc: "A balanced installation with recommended applications and settings." }
                    ListElement { name: "Minimal"; desc: "A lightweight installation with essential components only." }
                    ListElement { name: "Custom"; desc: "Choose the components and applications you want." }
                    ListElement { name: "Expert"; desc: "Advanced configuration for experienced users." }
                }
                delegate: Rectangle {
                    x: 44 + (index % 2) * ((root.colW - 74) / 2 + 14)
                    y: 112 + Math.floor(index / 2) * 82
                    width: (root.colW - 74) / 2; height: 72
                    radius: 14
                    color: root.selMode === name ? "#F0EDFF" : "#FFFFFF"
                    border.color: root.selMode === name ? "#6952E8" : "#E8EAF0"
                    border.width: root.selMode === name ? 2 : 1
                    Text { x: 14; y: 10; text: name; color: "#171923"
                        font.pixelSize: 13; font.weight: Font.Bold }
                    Text { x: 14; y: 32; width: parent.width - 28; text: desc
                        color: "#737987"; font.pixelSize: 11; wrapMode: Text.WordWrap
                        elide: Text.ElideRight; maximumLineCount: 2 }
                    Rectangle { width: 20; height: 20; radius: 10
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 12
                        color: root.selMode === name ? "#6952E8" : "transparent"
                        border.color: root.selMode === name ? "transparent" : "#E8EAF0"
                        border.width: root.selMode === name ? 0 : 2
                        Text { anchors.centerIn: parent; text: "✓"; color: "#FFF"
                            font.pixelSize: 11; visible: root.selMode === name } }
                    MouseArea { anchors.fill: parent
                        onClicked: {
                            root.selMode = name
                            if (typeof Global !== "undefined") Global.insert("installationMode", name)
                        } }
                }
            }
            Text { x: 44; y: parent.height - 84
                text: qsTr("Selection is stored with the installation — package profiles apply with the offline payload roadmap.")
                color: "#9AA3AD"; font.pixelSize: 11 }
            Button {
                x: 44; y: parent.height - 52
                flat: true; text: "← Back"
                onClicked: root.page = 2
            }
            Rectangle { x: 150; y: parent.height - 40; width: 110; height: 5; radius: 3
                color: "#E8EAF0"
                Rectangle { width: 78; height: 5; radius: 3; color: "#6952E8" } }
            MadButton {
                x: parent.width - root.panelW - 40 - 150; y: parent.height - 56
                width: 150; height: 40
                text: qsTr("Continue")
                onClicked: root.page = 4
            }
        }

        // ======== PAGE 4 — PACKAGES ========
        Item {
            id: pkgPage
            visible: root.page === 4
            anchors.fill: parent

            // selected package groups; recommended ones start chosen
            property var chosen: ({
                "Desktop Environment": true,
                "Web Browsers": true,
                "Multimedia Support": true
            })
            function toggle(name) {
                var c = {}
                for (var k in chosen) c[k] = chosen[k]
                c[name] = !chosen[name]
                chosen = c
                if (typeof Global !== "undefined") {
                    var sel = []
                    for (var k in c) if (c[k]) sel.push(k)
                    Global.insert("packageGroups", sel.join(","))
                }
            }

            Text { x: 44; y: 34; text: "CONFIGURE YOUR SYSTEM"
                color: "#6952E8"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1 }
            Text { x: 44; y: 54; text: qsTr("Make %1 Yours").arg(Branding.string(Branding.ProductName))
                color: "#171923"; font.pixelSize: 23; font.weight: Font.Bold }
            Text { x: 44; y: 88; text: qsTr("Select what matters to you.")
                color: "#737987"; font.pixelSize: 13 }

            Repeater {
                model: ListModel {
                    ListElement { name: "Desktop Environment"; sub: "KDE Plasma"; rec: true }
                    ListElement { name: "Web Browsers"; sub: "Firefox, Falkon"; rec: true }
                    ListElement { name: "Development Tools"; sub: "git, gcc, python"; rec: false }
                    ListElement { name: "Multimedia Support"; sub: "codecs, VLC"; rec: true }
                    ListElement { name: "Gaming Support"; sub: "Steam, drivers"; rec: false }
                    ListElement { name: "Creative Applications"; sub: "GIMP, Krita"; rec: false }
                }
                delegate: Rectangle {
                    x: 44 + (index % 2) * ((root.colW - 74) / 2 + 14)
                    y: 112 + Math.floor(index / 2) * 48
                    width: (root.colW - 74) / 2; height: 40
                    radius: 10
                    color: pkgPage.chosen[name] ? "#F0EDFF" : "#FFFFFF"
                    border.color: pkgPage.chosen[name] ? "#6952E8" : "#E8EAF0"
                    border.width: pkgPage.chosen[name] ? 2 : 1
                    Row { anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        Text { text: name; color: "#171923"; font.pixelSize: 12; font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter } }
                    Rectangle { width: 74; height: 15; radius: 8
                        color: "#FFFFFF"; border.color: "#20C987"; visible: rec
                        anchors.top: parent.top; anchors.topMargin: -7
                        anchors.right: parent.right; anchors.rightMargin: 10
                        Text { anchors.centerIn: parent; text: "Recommended"
                            color: "#0e9c66"; font.pixelSize: 8; font.weight: Font.Bold } }
                    MouseArea { anchors.fill: parent
                        onClicked: pkgPage.toggle(name) }
                    Text { anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 12
                        text: sub; color: "#737987"; font.pixelSize: 11 }
                }
            }
            Text { x: 44; y: parent.height - 84
                text: qsTr("Selection is stored with the installation — package profiles apply with the offline payload roadmap.")
                color: "#9AA3AD"; font.pixelSize: 11 }
            Button {
                x: 44; y: parent.height - 52
                flat: true; text: "← Back"
                onClicked: root.page = 3
            }
            Rectangle { x: 150; y: parent.height - 40; width: 110; height: 5; radius: 3
                color: "#E8EAF0"
                Rectangle { width: 94; height: 5; radius: 3; color: "#6952E8" } }
            MadButton {
                x: parent.width - root.panelW - 40 - 150; y: parent.height - 56
                width: 150; height: 40
                text: qsTr("Continue")
                onClicked: root.nextStep()
            }
        }

        // ---- right illustration panel ------------------------------------
        Rectangle {
            x: parent.width - root.panelW - 28; y: 24
            width: root.panelW; height: parent.height - 48
            radius: 18; color: "#EFEAFF"

            Rectangle { width: 140; height: 140; radius: 70; x: 14; y: 14; color: "#C9BEFF"; opacity: 0.5 }
            Rectangle { width: 120; height: 120; radius: 60; x: parent.width - 110; y: parent.height - 110; color: "#D9D2FF"; opacity: 0.6 }

            Item {
                anchors.centerIn: parent
                visible: root.page === 0 || root.page === 4
                Rectangle { width: 240; height: 240; radius: 120; anchors.centerIn: parent
                    color: "transparent"; border.color: "#B9ACFF"; border.width: 1 }
                Rectangle { width: 110; height: 126; radius: 12; color: "#6952E8"; opacity: 0.92
                    rotation: -14; anchors.centerIn: parent; anchors.verticalCenterOffset: 6 }
                Rectangle { width: 110; height: 126; radius: 12; color: "#927DFF"; opacity: 0.55
                    rotation: -14; anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -22; anchors.verticalCenterOffset: -12 }
            }
            Item {
                anchors.centerIn: parent
                visible: root.page === 1
                Rectangle { width: 140; height: 140; radius: 70; anchors.centerIn: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#A78BFF" }
                        GradientStop { position: 1.0; color: "#7C63F0" } } }
                Rectangle { width: 30; height: 24; radius: 12; color: "#6952E8"; x: -6; y: 48
                    Text { anchors.centerIn: parent; text: "A"; color: "#FFF"; font.pixelSize: 12; font.weight: Font.Bold } }
                Rectangle { width: 24; height: 24; radius: 12; color: "#8A76FF"; x: 138; y: 70
                    Text { anchors.centerIn: parent; text: "文"; color: "#FFF"; font.pixelSize: 11; font.weight: Font.Bold } }
                Rectangle { width: 26; height: 20; radius: 10; color: "#6952E8"; x: 30; y: 112
                    Text { anchors.centerIn: parent; text: "Я"; color: "#FFF"; font.pixelSize: 11; font.weight: Font.Bold } }
            }
            Item {
                anchors.centerIn: parent
                visible: root.page === 2 || root.page === 3
                Grid { columns: 3; spacing: 6; anchors.centerIn: parent
                    Repeater { model: 12
                        Rectangle { width: 26; height: 20; radius: 4; color: "#DAD2FF"
                            border.color: "#C4BAFF"; border.width: 1 } } }
                Rectangle { width: 86; height: 20; radius: 4; color: "#C9BEFF"
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 108 }
            }
        }

        // nav hint (fallback)
        Text {
            id: navHint
            visible: false
            x: root.cx + 40; y: root.cy + root.ch - 12
            text: "Press Continue in the bottom bar to proceed."
            color: "#6952E8"; font.pixelSize: 12
        }
    }

    // ---- blocking requirements banner ------------------------------------
    Rectangle {
        visible: !config.requirementsModel.satisfiedMandatory
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: Math.min(parent.width - 70, 700)
        height: 60
        radius: 12
        color: "#FFF6F5"
        border.color: "#FFD9D6"
        z: 10
        Text {
            anchors.centerIn: parent
            width: parent.width - 30
            text: qsTr("<b>This computer does not satisfy the minimum requirements for installing %1.</b>").arg(Branding.string(Branding.VersionedName))
            color: "#B3261E"; font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
