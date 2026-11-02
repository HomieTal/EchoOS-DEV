/* SPDX-FileCopyrightText: no
 * SPDX-License-Identifier: CC0-1.0
 *
 * MAD Installer — top stage indicator (calamares-sidebar.qml).
 * REACTIVE: binds ViewManager.currentStepIndex (real Calamares steps) and
 * polls the Global "madStage" bridge that welcomeq.qml updates for its
 * in-page states (intro/language/keyboard/mode/packages), so the highlight
 * follows the whole prototype flow.
 */

import io.calamares.core 1.0
import QtQuick 2.7

Rectangle {
    id: bar
    color: "#F5F6FA"
    implicitHeight: 74

    // 0 = stage 1 (Welcome), 1 = stage 2 (Configure), 2 = stage 3 (Ready)
    property int stage: 0
    property bool s1done: false
    property bool s2done: false

    Timer {
        interval: 400; running: true; repeat: true
        onTriggered: {
            var idx = -1
            try { idx = ViewManager.currentStepIndex } catch (e) { idx = -1 }
            var mad = 2
            try { mad = Global.value("madStage", 2) } catch (e) { mad = 2 }
            if (idx >= 3) { stage = 2; s1done = true; s2done = true }
            else if (idx >= 1) { stage = 1; s1done = true; s2done = false }
            else { s2done = false
                   stage = (mad >= 2) ? 1 : 0
                   s1done = (mad >= 2) }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 0

        Image {
            source: "mad-mark.png"
            width: 44; height: 28
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
        }
        Item { width: 46; height: 1 }

        Item {
            width: 150; height: 60
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 30; height: 30; radius: 15
                    color: stage === 0 ? "#6952E8" : (s1done ? "#20C987" : "#FFFFFF")
                    border.color: stage === 0 || s1done ? "transparent" : "#E8EAF0"
                    border.width: stage === 0 || s1done ? 0 : 2
                    Text { anchors.centerIn: parent
                        text: s1done ? "✓" : "1"
                        color: stage === 0 || s1done ? "#FFFFFF" : "#737987"
                        font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome"; color: stage === 0 ? "#171923" : "#737987"
                    font.pixelSize: 12; font.weight: Font.DemiBold }
            }
        }
        Rectangle { width: 110; height: 2; color: s1done ? "#20C987" : "#E8EAF0"
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -8 }

        Item {
            width: 190; height: 60
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 30; height: 30; radius: 15
                    color: stage === 1 ? "#6952E8" : (s2done ? "#20C987" : "#FFFFFF")
                    border.color: stage === 1 || s2done ? "transparent" : "#E8EAF0"
                    border.width: stage === 1 || s2done ? 0 : 2
                    Text { anchors.centerIn: parent
                        text: s2done ? "✓" : "2"
                        color: stage === 1 || s2done ? "#FFFFFF" : "#737987"
                        font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "Configure Your System"
                    color: stage === 1 ? "#171923" : "#737987"
                    font.pixelSize: 12; font.weight: Font.DemiBold }
            }
        }
        Rectangle { width: 110; height: 2; color: s2done ? "#20C987" : "#E8EAF0"
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -8 }

        Item {
            width: 160; height: 60
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 30; height: 30; radius: 15
                    color: stage === 2 ? "#6952E8" : "#FFFFFF"
                    border.color: stage === 2 ? "transparent" : "#E8EAF0"
                    border.width: stage === 2 ? 0 : 2
                    Text { anchors.centerIn: parent; text: "3"
                        color: stage === 2 ? "#FFFFFF" : "#737987"
                        font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                    text: "Ready to Install"
                    color: stage === 2 ? "#171923" : "#737987"
                    font.pixelSize: 12; font.weight: Font.DemiBold }
            }
        }
    }
}
