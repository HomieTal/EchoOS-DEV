// SPDX-FileCopyrightText: no
// SPDX-License-Identifier: CC0-1.0
//
// Minimal, resolution-independent Echo OS SDDM greeter.
//
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#070b14"

    Image {
        anchors.fill: parent
        source: "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#a6070b14"
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width * 0.46, 440)
        spacing: 14

        Image {
            source: "logo.jpeg"
            fillMode: Image.PreserveAspectFit
            Layout.preferredWidth: 132
            Layout.preferredHeight: 132
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "Echo OS"
            color: "#f4f7ff"
            font.family: "DejaVu Sans"
            font.pixelSize: 40
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: qsTr("Sign in to continue")
            color: "#a9b7d0"
            font.family: "DejaVu Sans"
            font.pixelSize: 15
            Layout.alignment: Qt.AlignHCenter
        }

        ComboBox {
            id: user
            model: userModel
            textRole: "name"
            currentIndex: userModel.lastIndex
            Layout.fillWidth: true
            font.family: "DejaVu Sans"
        }

        TextField {
            id: password
            echoMode: TextInput.Password
            placeholderText: qsTr("Password")
            font.family: "DejaVu Sans"
            Layout.fillWidth: true
            onAccepted: sddm.login(user.currentText, password.text, session.currentIndex)
        }

        ComboBox {
            id: session
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex
            Layout.fillWidth: true
            font.family: "DejaVu Sans"
        }

        Button {
            id: loginButton
            text: qsTr("Log In")
            enabled: password.text.length > 0
            Layout.fillWidth: true
            font.family: "DejaVu Sans"
            onClicked: sddm.login(user.currentText, password.text, session.currentIndex)
        }

        Text {
            id: message
            text: ""
            color: "#ff8a8a"
            font.family: "DejaVu Sans"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
        }
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            message.text = qsTr("Login failed. Please try again.")
            password.text = ""
            password.forceActiveFocus()
        }

        function onInformationMessage(text) {
            message.text = text
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
