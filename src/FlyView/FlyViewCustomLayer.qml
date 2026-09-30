import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

// To implement a custom overlay copy this code to your own control in your custom code source. Then override the
// FlyViewCustomLayer.qml resource with your own qml. See the custom example and documentation for details.
Item {
    id: _root

    property var parentToolInsets               // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var totalToolInsets:   _toolInsets // These are the insets for your custom overlay additions
    property var mapControl

    // since this file is a placeholder for the custom layer in a standard build, we will just pass through the parent insets
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }

    // Dynamic Hot-Reload Live Overlay Loader
    Item {
        id: dynamicLiveUiContainer
        anchors.fill: parent

        readonly property string uiDir: "/sdcard/Android/data/com.irs.irsgcs/files/live_ui/"
        property bool useSlotB: false

        Loader {
            id: dynamicLoader
            anchors.fill: parent
            asynchronous: false

            function reload() {
                useSlotB = !useSlotB
                var target = "file://" + uiDir + (useSlotB ? "LiveFlyOverlay_B.qml" : "LiveFlyOverlay_A.qml")
                dynamicLoader.source = ""
                dynamicLoader.source = target
            }
        }

        // Tap-to-reload discrete pill in top-right corner
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: dynamicLoader.status === Loader.Ready ? "#3300E676" : "#22FFFFFF"
            border.color: "#44FFFFFF"
            border.width: 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            opacity: 0.4
            z: 9999

            Text {
                anchors.centerIn: parent
                text: "⚡"
                font.pixelSize: 12
            }

            MouseArea {
                anchors.fill: parent
                onClicked: dynamicLoader.reload()
            }
        }

        Component.onCompleted: {
            var target = "file://" + uiDir + "LiveFlyOverlay_A.qml"
            dynamicLoader.source = target
        }
    }
    // standard placeholder custom overlay
}
