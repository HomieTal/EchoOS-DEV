// Echo OS installer slideshow
import QtQuick 2.15;

Rectangle {
    id: slide;
    color: "#1a1a2e";

    Image {
        id: mark;
        source: "productWelcome.png";
        anchors.centerIn: parent;
        width: 400;
        fillMode: Image.PreserveAspectFit;
    }

    Text {
        id: headline;
        anchors.horizontalCenter: parent.horizontalCenter;
        anchors.bottom: mark.top;
        anchors.bottomMargin: 32;
        text: qsTr("Welcome to Echo OS");
        color: "#ffffff";
        font.pixelSize: 32;
        font.bold: true;
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter;
        anchors.top: mark.bottom;
        anchors.topMargin: 32;
        text: qsTr("Echo OS is being installed. This will take a few minutes.");
        color: "#c9d1d9";
        font.pixelSize: 16;
    }
}
