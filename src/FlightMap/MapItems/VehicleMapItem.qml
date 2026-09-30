import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Marker for displaying a vehicle location on the map
MapQuickItem {
    id: _root

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    property var    vehicle                                                         /// Vehicle object
    property var    map
    property double heading:        vehicle ? vehicle.heading.value : Number.NaN    ///< Vehicle heading, NAN for none
    property real   size:           ScreenTools.defaultFontPixelHeight * 3          /// Default size for icon, most usage overrides this

    anchorPoint.x:  vehicleItem.width  / 2
    anchorPoint.y:  vehicleItem.height / 2
    visible:        coordinate.isValid

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var    _map:           map
    property bool   _multiVehicle:  QGroundControl.multiVehicleManager.vehicles.count > 1

    sourceItem: Item {
        id:         vehicleItem
        width:      vehicleIcon.width
        height:     vehicleIcon.height
        opacity:    vehicle === _activeVehicle ? 1.0 : 0.5

        Repeater {
            model: vehicle ? vehicle.gimbalController.gimbals : []

            Item {
                id:                           canvasItem
                anchors.centerIn:             vehicleItem
                width:                        vehicleItem.width * 2
                height:                       vehicleItem.height * 2
                property var gimbalYaw:       object.absoluteYaw.rawValue
                rotation:                     gimbalYaw + 180
                onGimbalYawChanged:           canvas.requestPaint()
                visible:                      vehicle && !isNaN(gimbalYaw) && QGroundControl.settingsManager.gimbalControllerSettings.showAzimuthIndicatorOnMap.rawValue
                opacity:                      object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

                Canvas {
                    id:                           canvas
                    anchors.centerIn:             canvasItem
                    anchors.verticalCenterOffset: vehicleItem.width
                    width:                        vehicleItem.width
                    height:                       vehicleItem.height

                    onPaint:                      paintHeading()

                    function paintHeading() {
                        var context = getContext("2d")
                        // console.log("painting heading " + object.param1Raw + " " + opacity + " " + visible + " " + _index)
                        context.clearRect(0, 0, vehicleIcon.width, vehicleIcon.height);

                        var centerX = canvas.width / 2;
                        var centerY = canvas.height / 2;
                        var length = canvas.height * 1.3
                        var width = canvas.width * 0.6

                        var point1 = [centerX - width , centerY + canvas.height * 0.6]
                        var point2 = [centerX, centerY - canvas.height * 0.5]
                        var point3 = [centerX + width , centerY + canvas.height * 0.6]
                        var point4 = [centerX, centerY + canvas.height * 0.2]

                        // Draw the arrow
                        context.save();
                        context.globalAlpha = 0.9;
                        context.beginPath();
                        context.moveTo(centerX, centerY + canvas.height * 0.2);
                        context.lineTo(point1[0], point1[1]);
                        context.lineTo(point2[0], point2[1]);
                        context.lineTo(point3[0], point3[1]);
                        context.lineTo(point4[0], point4[1]);
                        context.closePath();

                        const gradient = context.createLinearGradient(canvas.width / 2, canvas.height , canvas.width / 2, 0);
                        gradient.addColorStop(0.3, Qt.rgba(255,255,255,0));
                        gradient.addColorStop(0.5, Qt.rgba(255,255,255,0.5));
                        gradient.addColorStop(1, qgcPal.mapIndicator);

                        context.fillStyle = gradient;
                        context.fill();
                        context.restore();
                    }
                }
            }
        }

        Image {
            id:                 vehicleIcon
            source:             vehicle ? vehicle.vehicleImageOpaque : ""
            mipmap:             true
            width:              _root.size
            sourceSize.width:   _root.size
            fillMode:           Image.PreserveAspectFit
            transform: Rotation {
                origin.x:       vehicleIcon.width  / 2
                origin.y:       vehicleIcon.height / 2
                angle:          isNaN(heading) ? 0 : heading
            }
        }

        QGCMapLabel {
            id:                         vehicleLabel
            anchors.top:                parent.bottom
            anchors.horizontalCenter:   parent.horizontalCenter
            map:                        _map
            text:                       visible && vehicle ? qsTr("Vehicle %1").arg(vehicle.id) : ""
            font.pointSize:             ScreenTools.smallFontPointSize
            visible:                    _multiVehicle
        }

        Rectangle {
            id:                         vehicleCoordBadge
            anchors.top:                vehicleLabel.visible ? vehicleLabel.bottom : vehicleIcon.bottom
            anchors.topMargin:          2
            anchors.horizontalCenter:   parent.horizontalCenter
            width:                      vehicleCoordCol.width + (ScreenTools.defaultFontPixelWidth * 1.4)
            height:                     vehicleCoordCol.height + (ScreenTools.defaultFontPixelHeight * 0.5)
            radius:                     ScreenTools.defaultFontPixelWidth * 0.3
            color:                      "#E60B0E14"
            border.color:               "#00E5FF"
            border.width:               1
            visible:                    vehicle && vehicle.coordinate && vehicle.coordinate.isValid

            Column {
                id:                     vehicleCoordCol
                anchors.centerIn:       parent
                spacing:                1

                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           vehicle && vehicle.coordinate.isValid ? QGroundControl.coordinateToFormattedLatLon(vehicle.coordinate, 5) : ""
                    font.family:    ScreenTools.fixedPitchFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize * 0.8
                    font.bold:      true
                    color:          "#FFFFFF"
                    visible:        QGroundControl.coordinateDisplayMode === 0 || QGroundControl.coordinateDisplayMode === 2
                }

                QGCLabel {
                    readonly property string _mgrs: vehicle && vehicle.coordinate.isValid ? QGroundControl.coordinateToMGRS(vehicle.coordinate) : ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           qsTr("GR: %1").arg(_mgrs)
                    font.family:    ScreenTools.fixedPitchFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize * 0.8
                    font.bold:      true
                    color:          "#00E5FF"
                    visible:        (QGroundControl.coordinateDisplayMode === 1 || QGroundControl.coordinateDisplayMode === 2) && _mgrs.length > 0
                }
            }
        }
    }
}
