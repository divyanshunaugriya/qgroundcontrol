import QtQuick

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:                 root
    height:             warningsCol.height + (ScreenTools.defaultFontPixelHeight * 1.2)
    width:              warningsCol.width + (ScreenTools.defaultFontPixelWidth * 2.4)
    color:              Qt.rgba(0.09, 0.11, 0.16, 0.92)
    border.color:       "#E53935"
    border.width:       1.5
    radius:             ScreenTools.defaultFontPixelWidth * 0.4
    visible:            _noGPSLockVisible || _prearmErrorVisible

    property var  _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property bool _noGPSLockVisible:    _activeVehicle && _activeVehicle.requiresGpsFix && !_activeVehicle.coordinate.isValid
    property bool _prearmErrorVisible:  _activeVehicle && !_activeVehicle.armed && _activeVehicle.prearmError && !_activeVehicle.healthAndArmingCheckReport.supported

    Column {
        id:                         warningsCol
        anchors.centerIn:           parent
        spacing:                    ScreenTools.defaultFontPixelHeight * 0.4

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing:                  ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel {
                text:           "⚠️"
                font.pointSize: ScreenTools.mediumFontPointSize
                visible:        _noGPSLockVisible || _prearmErrorVisible
            }

            QGCLabel {
                visible:                    _noGPSLockVisible
                color:                      "#FF5252"
                font.bold:                  true
                font.pointSize:             ScreenTools.mediumFontPointSize
                text:                       qsTr("No GPS Lock for Vehicle")
            }

            QGCLabel {
                visible:                    _prearmErrorVisible
                color:                      "#FF5252"
                font.bold:                  true
                font.pointSize:             ScreenTools.mediumFontPointSize
                text:                       _activeVehicle ? _activeVehicle.prearmError : ""
            }
        }

        QGCLabel {
            anchors.horizontalCenter:   parent.horizontalCenter
            visible:                    _prearmErrorVisible
            width:                      ScreenTools.defaultFontPixelWidth * 42
            horizontalAlignment:        Text.AlignHCenter
            wrapMode:                   Text.WordWrap
            color:                      "#EEEEEE"
            font.pointSize:             ScreenTools.smallFontPointSize
            text:                       qsTr("The vehicle has failed a pre-arm check. In order to arm the vehicle, resolve the failure.")
        }
    }
}
