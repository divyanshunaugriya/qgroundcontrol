import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

Map {
    id: _map

    plugin:     Plugin { name: "QGroundControl" }
    opacity:    0.99 // https://bugreports.qt.io/browse/QTBUG-82185

    property string mapName:                        'defaultMap'
    property bool   isSatelliteMap:                 activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1
    property var    gcsPosition:                    QGroundControl.qgcPositionManger.gcsPosition
    property real   gcsHeading:                     QGroundControl.qgcPositionManger.gcsHeading
    property alias  allowGCSLocationCenter:         _positionTracker.allowGCSLocationCenter     ///< true: map will center to gcs location one time
    property alias  allowVehicleLocationCenter:     _positionTracker.allowVehicleLocationCenter ///< true: map will center/zoom to vehicle location one time
    property alias  firstVehiclePositionReceived:   _positionTracker.firstVehiclePositionReceived ///< true: first vehicle position update was responded to
    property alias  positionTracker:                _positionTracker                            ///< Auto-centering policy, for derived maps to layer follow behavior on
    property bool   planView:                       false   ///< true: map being using for Plan view, items should be draggable
    property bool   pinchZoomDisabledByVirtualJoysticks: false ///< true: disable pinch-to-zoom while virtual joystick thumbs are down

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
    property var    cursorCoordinate:           center

    function setVisibleRegion(region) {
        // This works around a bug on Qt where if you set a visibleRegion and then the user moves or zooms the map
        // and then you set the same visibleRegion the map will not move/scale appropriately since it thinks there
        // is nothing to do.
        let maxZoomLevel = 20
        _map.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(0, 0), QtPositioning.coordinate(0, 0))
        _map.visibleRegion = region
        if (_map.zoomLevel > maxZoomLevel) {
            _map.zoomLevel = maxZoomLevel
        }
    }

    function centerToSpecifiedLocation() {
        specifyMapPositionDialogFactory.open()
    }

    MapPositionTracker {
        id: _positionTracker

        active: _map.mapReady
        gcsPosition: _map.gcsPosition
        vehicleCoordinate: _map._activeVehicleCoordinate
        centerGCSWhenVehicleValid: QGroundControl.settingsManager.flyViewSettings.keepMapCenteredOnVehicle.rawValue

        onCenterMap: (coordinate, firstPosition) => {
            _map.center = coordinate
            if (firstPosition) {
                _map.zoomLevel = QGroundControl.flightMapInitialZoom
            }
        }
    }

    QGCPopupDialogFactory {
        id: specifyMapPositionDialogFactory

        dialogComponent: specifyMapPositionDialog
    }

    Component {
        id: specifyMapPositionDialog
        EditPositionDialog {
            title:                  qsTr("Specify Position")
            coordinate:             center
            onCoordinateChanged:    center = coordinate
        }
    }

    function updateActiveMapType() {
        var settings =  QGroundControl.settingsManager.flightMapSettings
        var fullMapName = settings.mapProvider.value + " " + settings.mapType.value

        for (var i = 0; i < _map.supportedMapTypes.length; i++) {
            if (fullMapName === _map.supportedMapTypes[i].name) {
                _map.activeMapType = _map.supportedMapTypes[i]
                return
            }
        }
    }

    onMapReadyChanged: {
        if (_map.mapReady) {
            updateActiveMapType()
        }
    }

    Connections {
        target: QGroundControl.settingsManager.flightMapSettings.mapType
        function onRawValueChanged() { updateActiveMapType() }
    }

    Connections {
        target: QGroundControl.settingsManager.flightMapSettings.mapProvider
        function onRawValueChanged() { updateActiveMapType() }
    }

    signal mapPanStart
    signal mapPanStop
    signal mapClicked(var position)
    signal mapRightClicked(var position)
    signal mapPressAndHold(var position)

    PinchHandler {
        id:      pinchHandler
        target:  null
        // Disabled while virtual joystick thumbs are down. The default grabPermissions include
        // CanTakeOverFromItems, which lets this handler steal touch grabs from the joystick pads'
        // MultiPointTouchAreas and zoom the map instead. The permission can't be removed since
        // pinch on the map itself must take over from the panning MultiPointTouchArea below.
        // See GitHub issue #13450.
        enabled: !_map.pinchZoomDisabledByVirtualJoysticks

        property var pinchStartGeoCoord     // geo coordinate under centroid at pinch start
        property var pinchStartScreenPoint  // screen point of centroid at pinch start

        onActiveChanged: {
            if (active) {
                // Capture both the screen point and its geo coordinate once at pinch start.
                // alignCoordinateToPoint requires a fixed screen anchor; using the live
                // centroid.position causes the map to pan as fingers drift.
                pinchStartScreenPoint = pinchHandler.centroid.position
                pinchStartGeoCoord    = _map.toCoordinate(pinchStartScreenPoint, false)
            }
        }
        onScaleChanged: (delta) => {
            _map.zoomLevel = Math.max(_map.zoomLevel + Math.log2(delta), 0)
            _map.alignCoordinateToPoint(pinchStartGeoCoord, pinchStartScreenPoint)
        }
    }

    WheelHandler {
        // WheelHandler's default acceptedDevices=Mouse silently drops trackpad scroll events on
        // multiple platforms:
        //   - Linux/Wayland (QTBUG-112394 / QTBUG-112432): the Wayland
        //     protocol exposes no way to distinguish a mouse from a trackpad, so Qt registers all
        //     pointer devices as TouchPad.
        //   - xcb / XWayland: Wayland pointer events are translated back to X11 and device-type
        //     metadata is lost — physical mouse scroll events arrive as PointerDevice.TouchPad.
        //   - macOS (cocoa): trackpad scroll events are correctly reported as PointerDevice.TouchPad
        //     but are excluded by the Mouse-only default.
        // Accepting both Mouse and TouchPad on all platforms is harmless and covers every case.
        acceptedDevices:    PointerDevice.Mouse | PointerDevice.TouchPad
        rotationScale:      1 / 120

        onWheel: (event) => {
            const zoomDelta = event.angleDelta.y * rotationScale
            const mouseGeoPos = _map.toCoordinate(Qt.point(event.x, event.y), false)
            _map.zoomLevel = Math.max(_map.zoomLevel + zoomDelta, 0)
            _map.alignCoordinateToPoint(mouseGeoPos, Qt.point(event.x, event.y))
        }
    }

    HoverHandler {
        id: mapHoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onPointChanged: {
            const coord = _map.toCoordinate(point.position, false)
            if (coord && coord.isValid) {
                _map.cursorCoordinate = coord
            }
        }
        onHoveredChanged: {
            if (!hovered) {
                _map.cursorCoordinate = _map.center
            }
        }
    }

    // We specifically do not use a DragHandler for panning. It just causes too many problems if you overlay anything else like a Flickable above it.
    // Causes all sorts of crazy problems where dragging/scrolling  no longerr works on items above in the hierarchy.
    // Since we are using a MouseArea we also can't use TapHandler for clicks. So we handle that here as well.
    MultiPointTouchArea {
        id: multiTouchArea
        anchors.fill: parent
        maximumTouchPoints: 1
        mouseEnabled: true

        property bool dragActive: false
        property real lastMouseX
        property real lastMouseY
        property bool isPressed: false
        property bool pressAndHold: false

        onPressed: (touchPoints) => {
            lastMouseX = touchPoints[0].x
            lastMouseY = touchPoints[0].y
            isPressed = true
            pressAndHold = false
            pressAndHoldTimer.start()
        }

        onGestureStarted: (gesture) => {
            dragActive = true
            gesture.grab()
            mapPanStart()
        }

        onUpdated: (touchPoints) => {
            if (dragActive) {
                let deltaX = touchPoints[0].x - lastMouseX
                let deltaY = touchPoints[0].y - lastMouseY
                if (Math.abs(deltaX) >= 1.0 || Math.abs(deltaY) >= 1.0) {
                    _map.pan(lastMouseX - touchPoints[0].x, lastMouseY - touchPoints[0].y)
                    lastMouseX = touchPoints[0].x
                    lastMouseY = touchPoints[0].y
                }
            }
        }

        onReleased: (touchPoints) => {
            isPressed = false
            pressAndHoldTimer.stop()
            if (dragActive) {
                _map.pan(lastMouseX - touchPoints[0].x, lastMouseY - touchPoints[0].y)
                dragActive = false
                mapPanStop()
            } else if (!pressAndHold) {
                mapClicked(Qt.point(touchPoints[0].x, touchPoints[0].y))
            }
            pressAndHold = false
        }

        Timer {
            id: pressAndHoldTimer
            interval: 600        // hold duration in ms
            repeat: false

            onTriggered: {
                if (multiTouchArea.isPressed && !multiTouchArea.dragActive) {
                    multiTouchArea.pressAndHold = true
                    mapPressAndHold(Qt.point(multiTouchArea.lastMouseX, multiTouchArea.lastMouseY))
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true

        onPressed: (mouseEvent) => {
            if (mouseEvent.button === Qt.RightButton) {
                mapRightClicked(Qt.point(mouseEvent.x, mouseEvent.y))
            }
        }
    }

    /// Ground Station location
    MapQuickItem {
        anchorPoint.x:  sourceItem.width / 2
        anchorPoint.y:  sourceItem.height / 2
        visible:        gcsPosition.isValid && !planView
        coordinate:     gcsPosition

        sourceItem: Image {
            id:             mapItemImage
            source:         isNaN(gcsHeading) ? "/res/QGCLogoFull.svg" : "/res/QGCLogoArrow.svg"
            mipmap:         true
            antialiasing:   true
            fillMode:       Image.PreserveAspectFit
            height:         ScreenTools.defaultFontPixelHeight * (isNaN(gcsHeading) ? 1.75 : 2.5 )
            sourceSize.height: height
            transform: Rotation {
                origin.x:       mapItemImage.width  / 2
                origin.y:       mapItemImage.height / 2
                angle:          isNaN(gcsHeading) ? 0 : gcsHeading
            }
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    property var  touchCoordinate: QtPositioning.coordinate()
    property bool showTouchPin:    false

    onPlanViewChanged: {
        if (planView) {
            showTouchPin = false
        }
    }

    onMapClicked: (position) => {
        if (!_map.planView) {
            touchCoordinate = _map.toCoordinate(position, false)
            showTouchPin = true
        }
    }

    /// On-Map Interactive Touch/Click Coordinate Badge (dropped right at touched location - disabled in Plan View)
    MapQuickItem {
        id:            touchPinMarker
        anchorPoint.x: touchPinBox.width / 2
        anchorPoint.y: touchPinBox.height + (ScreenTools.defaultFontPixelHeight * 0.4)
        coordinate:    _map.touchCoordinate
        visible:       !_map.planView && _map.showTouchPin && _map.touchCoordinate.isValid

        sourceItem: Column {
            id:                  touchPinBox
            spacing:             2

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:        touchContentLayout.width + (ScreenTools.defaultFontPixelWidth * 1.6)
                height:       touchContentLayout.height + (ScreenTools.defaultFontPixelHeight * 0.6)
                radius:       ScreenTools.defaultFontPixelWidth * 0.4
                color:        "#E60B0E14"
                border.color: "#00E5FF"
                border.width: 1

                RowLayout {
                    id:               touchContentLayout
                    anchors.centerIn: parent
                    spacing:          ScreenTools.defaultFontPixelWidth * 0.8

                    Column {
                        spacing: 2

                        QGCLabel {
                            text:           _map.touchCoordinate.isValid ? QGroundControl.coordinateToFormattedLatLon(_map.touchCoordinate, 6) : ""
                            font.family:    ScreenTools.fixedPitchFontFamily
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                            font.bold:      true
                            color:          "#FFFFFF"
                            visible:        QGroundControl.coordinateDisplayMode === 0 || QGroundControl.coordinateDisplayMode === 2
                        }

                        QGCLabel {
                            readonly property string _mgrs: _map.touchCoordinate.isValid ? QGroundControl.coordinateToMGRS(_map.touchCoordinate) : ""
                            text:           qsTr("GR: %1").arg(_mgrs)
                            font.family:    ScreenTools.fixedPitchFontFamily
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                            font.bold:      true
                            color:          "#00E5FF"
                            visible:        (QGroundControl.coordinateDisplayMode === 1 || QGroundControl.coordinateDisplayMode === 2) && _mgrs.length > 0
                        }
                    }

                    // Direct Action Button to set touched location as Drone / VIO Initial Position
                    Rectangle {
                        id:                     setVioTouchBtn
                        property bool           _sent: false
                        visible:                QGroundControl.multiVehicleManager.activeVehicle !== null && !QGroundControl.multiVehicleManager.activeVehicle.flying
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.3
                        Layout.preferredWidth:  setVioTouchText.width + (ScreenTools.defaultFontPixelWidth * 1.4)
                        radius:                 ScreenTools.defaultFontPixelWidth * 0.3
                        color:                  _sent ? "#2E7D32" : (setVioTouchMouse.containsMouse ? "#00E5FF" : "#1E293B")
                        border.color:           "#00E5FF"
                        border.width:           1

                        QGCLabel {
                            id:               setVioTouchText
                            anchors.centerIn: parent
                            text:             setVioTouchBtn._sent ? qsTr("✓ VIO SET") : qsTr("📍 Set Drone/VIO")
                            font.bold:        true
                            font.pointSize:   ScreenTools.smallFontPointSize * 0.8
                            color:            setVioTouchBtn._sent ? "#FFFFFF" : (setVioTouchMouse.containsMouse ? "#000000" : "#FFFFFF")
                        }

                        MouseArea {
                            id:              setVioTouchMouse
                            anchors.fill:    parent
                            hoverEnabled:    true
                            cursorShape:     Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                var v = QGroundControl.multiVehicleManager.activeVehicle
                                if (v && _map.touchCoordinate.isValid) {
                                    v.setEstimatorOrigin(_map.touchCoordinate)
                                    setVioTouchBtn._sent = true
                                    vioSentTimer.restart()
                                }
                            }
                        }

                        Timer {
                            id:          vioSentTimer
                            interval:    2500
                            repeat:      false
                            onTriggered: setVioTouchBtn._sent = false
                        }
                    }

                    Rectangle {
                        width:  ScreenTools.defaultFontPixelHeight * 1.0
                        height: width
                        radius: width / 2
                        color:  closeTouchMouse.pressed ? "#EF4444" : "#1E293B"

                        QGCLabel {
                            anchors.centerIn: parent
                            text:             "✕"
                            font.bold:        true
                            font.pointSize:   ScreenTools.smallFontPointSize * 0.8
                            color:            "#FFFFFF"
                        }

                        MouseArea {
                            id:              closeTouchMouse
                            anchors.fill:    parent
                            cursorShape:     Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked:       _map.showTouchPin = false
                        }
                    }
                }
            }

            // Downward pointing arrow tip pointing exactly to touched location
            Rectangle {
                width:                    ScreenTools.defaultFontPixelWidth * 0.8
                height:                   width
                rotation:                 45
                color:                    "#00E5FF"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
} // Map
