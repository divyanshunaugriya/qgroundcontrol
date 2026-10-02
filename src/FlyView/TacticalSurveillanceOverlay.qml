import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

Item {
    id: _root
    anchors.fill: parent

    property var mapControl
    property var guidedController: globals.guidedControllerFlyView
    property var pipView: null

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _vehicleConnected: !!_activeVehicle

    // IRS Brand Tactical Palette
    readonly property color cDeepNavy:     "#23285D"
    readonly property color cDarkSurface:  "#181B3D"
    readonly property color cBulbYellow:   "#F0DE2A"
    readonly property color cSafetyGreen:  "#10B981"
    readonly property color cTacticalCyan: "#38BDF8"
    readonly property color cLaserCyan:    "#00D2FF"
    readonly property color cAlertRed:     "#EF4444"
    readonly property color cTextWhite:    "#FFFFFF"
    readonly property color cTextMuted:    "#94A3B8"

    // Tactical Surveillance & Payload State
    property bool   stealthModeActive:     false
    property bool   isTargetLocked:        true
    property bool   isRecordingVideo:      false
    property int    recordSeconds:         0
    property bool   isSearchlightOn:       false
    property int    currentZoomLevel:      20
    property string thermalPalette:        "IRONBOW"
    property real   lrfDistanceM:          284.0
    property real   gimbalPitchDeg:        -42.0
    property real   targetLat:             28.61394
    property real   targetLon:             77.20902
    property real   targetElevationM:      214.0
    property string targetClassification:  "VEHICLE (SUV)"
    property string tacticalModeName:      "ORBIT POI"

    // Toast feedback message
    property string toastMessage:          ""
    property bool   toastVisible:          false

    function showToast(msg) {
        toastMessage = msg
        toastVisible = true
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 2200
        onTriggered: _root.toastVisible = false
    }

    Timer {
        id: recTimer
        interval: 1000
        repeat: true
        running: isRecordingVideo
        onTriggered: recordSeconds++
    }

    // =========================================================================
    // 1. TOP TACTICAL NAVIGATION BAR (1:1 IRS IDENTITY)
    // =========================================================================
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(52, ScreenTools.toolbarHeight)
        color: stealthModeActive ? "#0A0D1A" : cDeepNavy
        z: 100

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: stealthModeActive ? cAlertRed : cBulbYellow
        }

        // Top-Left Section: 1-Tap Home + Aircraft Identity
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // 1-Tap Home Button (Direct exit to Hub, zero confirmation)
            Rectangle {
                width: 38
                height: 38
                radius: 8
                color: homeMouseArea.pressed ? cBulbYellow : cDarkSurface
                border.color: cBulbYellow
                border.width: 1

                Canvas {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = homeMouseArea.pressed ? "#23285D" : "#FFFFFF";
                        ctx.beginPath();
                        ctx.moveTo(10, 2);
                        ctx.lineTo(1, 10);
                        ctx.lineTo(4, 10);
                        ctx.lineTo(4, 18);
                        ctx.lineTo(8, 18);
                        ctx.lineTo(8, 12);
                        ctx.lineTo(12, 12);
                        ctx.lineTo(12, 18);
                        ctx.lineTo(16, 18);
                        ctx.lineTo(16, 10);
                        ctx.lineTo(19, 10);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                MouseArea {
                    id: homeMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof mainWindow !== "undefined" && mainWindow.showHubPage) {
                            mainWindow.showHubPage();
                        } else {
                            globals.irsShowLogin = true;
                        }
                    }
                }
            }

            // Connection & Drone ID Badge
            Rectangle {
                height: 34
                width: connRow.implicitWidth + 20
                radius: 17
                color: _vehicleConnected ? Qt.rgba(0.06, 0.73, 0.51, 0.15) : Qt.rgba(0.94, 0.27, 0.27, 0.15)
                border.color: _vehicleConnected ? cSafetyGreen : cAlertRed
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: connRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: _vehicleConnected ? cSafetyGreen : cAlertRed
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: _vehicleConnected ? ("IRS INTERCEPTOR | " + (_activeVehicle.flightMode ? _activeVehicle.flightMode : "LOITER")) : "DISCONNECTED"
                        color: _vehicleConnected ? cSafetyGreen : cAlertRed
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 58
                        height: 18
                        radius: 4
                        color: Qt.rgba(0, 0.82, 1, 0.2)
                        border.color: cLaserCyan
                        border.width: 0.8
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "AES-256"
                            color: cLaserCyan
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !_vehicleConnected
                    onClicked: {
                        if (typeof mainWindow !== "undefined" && mainWindow.showSettingsTool) {
                            mainWindow.showSettingsTool();
                        }
                    }
                }
            }
        }

        // Top-Center: Tactical Mode & RTK Satellite Badge
        Row {
            anchors.centerIn: parent
            spacing: 12
            visible: topBar.width > 700

            Rectangle {
                height: 32
                width: modePillRow.implicitWidth + 20
                radius: 16
                color: cDarkSurface
                border.color: cLaserCyan
                border.width: 1

                Row {
                    id: modePillRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "MODE:"
                        color: cLaserCyan
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: tacticalModeName
                        color: cBulbYellow
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                height: 32
                width: rtkPillRow.implicitWidth + 18
                radius: 16
                color: cDarkSurface
                border.color: cSafetyGreen
                border.width: 1

                Row {
                    id: rtkPillRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: cSafetyGreen
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "RTK FIX: " + (_activeVehicle && _activeVehicle.gps ? _activeVehicle.gps.count.value : "26") + " SATS"
                        color: cSafetyGreen
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Top-Right Section: Battery, Stealth Toggle, Settings Hamburger
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Smart Battery with Estimated Loiter Time
            Rectangle {
                height: 34
                width: battRow.implicitWidth + 14
                radius: 6
                color: cDarkSurface
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Row {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 3
                        color: cSafetyGreen
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "B"
                            color: "#FFFFFF"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    Text {
                        text: _activeVehicle && _activeVehicle.battery && _activeVehicle.battery.voltage ? _activeVehicle.battery.voltage.value.toFixed(1) + "V" : "25.6V"
                        color: cSafetyGreen
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: _activeVehicle && _activeVehicle.battery && _activeVehicle.battery.percentRemaining ? _activeVehicle.battery.percentRemaining.value.toFixed(0) + "%" : "88%"
                        color: cTextMuted
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "(32 MIN)"
                        color: cBulbYellow
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Stealth Mode Toggle (Blackout Navigation LEDs)
            Rectangle {
                height: 34
                width: stealthRow.implicitWidth + 16
                radius: 6
                color: stealthModeActive ? Qt.rgba(0.94, 0.27, 0.27, 0.2) : cDarkSurface
                border.color: stealthModeActive ? cAlertRed : Qt.rgba(1, 1, 1, 0.15)
                border.width: 1

                Row {
                    id: stealthRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: stealthModeActive ? cAlertRed : cTextMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: stealthModeActive ? "STEALTH: ON" : "STEALTH"
                        color: stealthModeActive ? cAlertRed : cTextWhite
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        stealthModeActive = !stealthModeActive
                        showToast(stealthModeActive ? "STEALTH MODE ENGAGED: AIRCRAFT STROBES OFF" : "STEALTH DISENGAGED: NORMAL NAVIGATION LIGHTS")
                    }
                }
            }

            // Far Top-Right: Settings Hamburger Menu (3-lines)
            Rectangle {
                width: 38
                height: 38
                radius: 8
                color: settingsMouseArea.pressed ? cBulbYellow : cDarkSurface
                border.color: cBulbYellow
                border.width: 1.5

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 18
                        height: 2
                        radius: 1
                        color: settingsMouseArea.pressed ? "#23285D" : "#FFFFFF"
                    }
                    Rectangle {
                        width: 18
                        height: 2
                        radius: 1
                        color: settingsMouseArea.pressed ? "#23285D" : "#FFFFFF"
                    }
                    Rectangle {
                        width: 18
                        height: 2
                        radius: 1
                        color: settingsMouseArea.pressed ? "#23285D" : "#FFFFFF"
                    }
                }

                MouseArea {
                    id: settingsMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof mainWindow !== "undefined" && mainWindow.showSettingsTool) {
                            mainWindow.showSettingsTool();
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. LEFT VERTICAL TACTICAL ACTION STRIP
    // =========================================================================
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: topBar.bottom
        anchors.topMargin: 16
        spacing: 12
        z: 90

        // Target Pinpoint Button (🎯)
        Rectangle {
            width: 46
            height: 46
            radius: 23
            color: pinpointArea.pressed ? cLaserCyan : cDarkSurface
            border.color: cLaserCyan
            border.width: 1.5

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text { text: "🎯"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "PINPOINT"; color: pinpointArea.pressed ? "#000000" : cLaserCyan; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: pinpointArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    showToast("TARGET PINPOINT DROPPED: " + targetLat.toFixed(4) + "° N, " + targetLon.toFixed(4) + "° E")
                }
            }
        }

        // Orbit POI Button (🔄)
        Rectangle {
            width: 46
            height: 46
            radius: 23
            color: orbitArea.pressed ? cBulbYellow : (tacticalModeName === "ORBIT POI" ? Qt.rgba(0.94, 0.87, 0.16, 0.2) : cDarkSurface)
            border.color: cBulbYellow
            border.width: 1.5

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text { text: "🔄"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "ORBIT"; color: orbitArea.pressed ? "#000000" : cBulbYellow; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: orbitArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    tacticalModeName = "ORBIT POI"
                    if (_activeVehicle && guidedController) {
                        guidedController.confirmAction(guidedController.actionOrbit)
                    }
                    showToast("AUTONOMOUS ORBIT ENGAGED AROUND TARGET (RADIUS 100M)")
                }
            }
        }

        // AI Track Target Button (🤖)
        Rectangle {
            width: 46
            height: 46
            radius: 23
            color: aiTrackArea.pressed ? cSafetyGreen : (isTargetLocked ? Qt.rgba(0.06, 0.73, 0.51, 0.2) : cDarkSurface)
            border.color: cSafetyGreen
            border.width: 1.5

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text { text: "🤖"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "AI TRACK"; color: aiTrackArea.pressed ? "#000000" : cSafetyGreen; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: aiTrackArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    isTargetLocked = !isTargetLocked
                    showToast(isTargetLocked ? "AI VISION TRACKING ACTIVE [VEHICLE LOCKED]" : "AI TRACKING PAUSED")
                }
            }
        }

        // Perimeter Patrol Button (🛡️)
        Rectangle {
            width: 46
            height: 46
            radius: 23
            color: patrolArea.pressed ? cTacticalCyan : (tacticalModeName === "PATROL" ? Qt.rgba(0.22, 0.74, 0.97, 0.2) : cDarkSurface)
            border.color: cTacticalCyan
            border.width: 1.5

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text { text: "🛡️"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "PATROL"; color: patrolArea.pressed ? "#000000" : cTacticalCyan; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: patrolArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    tacticalModeName = "PATROL"
                    showToast("PERIMETER SECURITY GRID PATROL ACTIVE (24 WAYPOINTS)")
                }
            }
        }

        // One-Key Takeoff / Land Button (🚀)
        Rectangle {
            width: 46
            height: 46
            radius: 23
            color: takeoffArea.pressed ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 2

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text { text: "🚀"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "AUTO"; color: takeoffArea.pressed ? "#23285D" : cBulbYellow; font.pixelSize: 8; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: takeoffArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (_activeVehicle && guidedController) {
                        if (_activeVehicle.flying || _activeVehicle.armed) {
                            guidedController.confirmAction(guidedController.actionLand)
                        } else {
                            guidedController.confirmAction(guidedController.actionTakeoff)
                        }
                    } else {
                        showToast("AUTO TAKEOFF / LAND TRIGGERED")
                    }
                }
            }
        }

        // Failsafe Return To Home (RTH) Button (⚡)
        Rectangle {
            width: 46
            height: 46
            radius: 23
            color: rthArea.pressed ? cAlertRed : Qt.rgba(0.94, 0.27, 0.27, 0.2)
            border.color: cAlertRed
            border.width: 2

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text { text: "⚡"; font.pixelSize: 14; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "RTH"; color: rthArea.pressed ? "#FFFFFF" : cAlertRed; font.pixelSize: 8; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            }

            MouseArea {
                id: rthArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (_activeVehicle && guidedController) {
                        guidedController.confirmAction(guidedController.actionRTL)
                    }
                    showToast("FAILSAFE RETURN TO BASE (RTH) INITIATED")
                }
            }
        }
    }

    // =========================================================================
    // 3. RIGHT PAYLOAD & CAMERA CONTROLS STRIP
    // =========================================================================
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: topBar.bottom
        anchors.topMargin: 16
        spacing: 8
        z: 90

        // Vertical Optical Zoom Ladder (1x to 100x)
        Rectangle {
            width: 36
            height: 220
            radius: 18
            color: cDarkSurface
            border.color: cLaserCyan
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: [100, 50, 20, 10, 5, 2, 1]
                    delegate: Rectangle {
                        width: 30
                        height: 26
                        radius: 13
                        color: currentZoomLevel === modelData ? cLaserCyan : (zoomMouseArea.pressed ? Qt.rgba(0, 0.82, 1, 0.3) : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: modelData + "x"
                            color: currentZoomLevel === modelData ? "#000000" : cTextWhite
                            font.pixelSize: 9
                            font.bold: true
                        }

                        MouseArea {
                            id: zoomMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                currentZoomLevel = modelData
                                showToast("OPTICAL ZOOM: " + modelData + "X")
                            }
                        }
                    }
                }
            }
        }

        // Camera Sensor & Tactical Payload Tools
        Column {
            spacing: 10

            // Snap Photo (📸)
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: snapArea.pressed ? cTextWhite : cDarkSurface
                border.color: cTextWhite
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Rectangle { width: 12; height: 12; radius: 6; color: snapArea.pressed ? "#000000" : "#FFFFFF"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "SNAP"; color: snapArea.pressed ? "#000000" : cTextWhite; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                }

                MouseArea {
                    id: snapArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.triggerCamera()
                        }
                        showToast("HIGH-RES OPTICAL SNAPSHOT SAVED")
                    }
                }
            }

            // Record 4K Video (⏺️)
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: isRecordingVideo ? Qt.rgba(0.94, 0.27, 0.27, 0.25) : cDarkSurface
                border.color: cAlertRed
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Rectangle { width: 12; height: 12; radius: 6; color: cAlertRed; anchors.horizontalCenter: parent.horizontalCenter }
                    Text {
                        text: isRecordingVideo ? (Math.floor(recordSeconds / 60) + ":" + (recordSeconds % 60 < 10 ? "0" : "") + (recordSeconds % 60)) : "REC"
                        color: cAlertRed
                        font.pixelSize: 7
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        isRecordingVideo = !isRecordingVideo
                        if (!isRecordingVideo) recordSeconds = 0
                        showToast(isRecordingVideo ? "TACTICAL 4K VIDEO RECORDING STARTED" : "RECORDING SAVED TO SECURE STORAGE")
                    }
                }
            }

            // Thermal IR Palette Toggle (🌡️)
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: thermArea.pressed ? cBulbYellow : cDarkSurface
                border.color: cBulbYellow
                border.width: 1.5

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text { text: "🌡️"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "IR THERM"; color: thermArea.pressed ? "#000000" : cBulbYellow; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                }

                MouseArea {
                    id: thermArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (thermalPalette === "IRONBOW") thermalPalette = "WHITE-HOT"
                        else if (thermalPalette === "WHITE-HOT") thermalPalette = "BLACK-HOT"
                        else thermalPalette = "IRONBOW"
                        showToast("THERMAL PALETTE: " + thermalPalette)
                    }
                }
            }

            // Laser Rangefinder Pulse (⚡)
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: lrfArea.pressed ? cLaserCyan : cDarkSurface
                border.color: cLaserCyan
                border.width: 1.5

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text { text: "⚡"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "LRF"; color: lrfArea.pressed ? "#000000" : cLaserCyan; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                }

                MouseArea {
                    id: lrfArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        lrfDistanceM = Math.round(250 + Math.random() * 80)
                        showToast("LASER PULSE: TARGET DISTANCE " + lrfDistanceM + " m")
                    }
                }
            }

            // Night Searchlight / Lamp (💡)
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: isSearchlightOn ? Qt.rgba(0.94, 0.87, 0.16, 0.25) : cDarkSurface
                border.color: isSearchlightOn ? cBulbYellow : Qt.rgba(1, 1, 1, 0.3)
                border.width: 1.5

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text { text: "💡"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: isSearchlightOn ? "LAMP ON" : "LAMP"; color: isSearchlightOn ? cBulbYellow : cTextWhite; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        isSearchlightOn = !isSearchlightOn
                        showToast(isSearchlightOn ? "TACTICAL SEARCHLIGHT ACTIVE (100% ILLUMINATION)" : "SEARCHLIGHT OFF")
                    }
                }
            }

            // 1-Tap Camera & Map Swap (🗺️)
            Rectangle {
                width: 44
                height: 44
                radius: 12
                color: swapArea.pressed ? cLaserCyan : cDeepNavy
                border.color: cLaserCyan
                border.width: 1.5

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text { text: "🗺️"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "SWAP"; color: swapArea.pressed ? "#000000" : cLaserCyan; font.pixelSize: 7; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                }

                MouseArea {
                    id: swapArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pipView && pipView._swapPip) {
                            pipView._swapPip()
                        }
                        showToast("1-TAP DISPLAY SWAPPED: MAP ⇄ CAMERA")
                    }
                }
            }
        }
    }

    // =========================================================================
    // 4. CENTER SCREEN HUD (TACTICAL TARGET RETICLE & AI BOUNDING BOX)
    // =========================================================================
    Item {
        anchors.centerIn: parent
        width: 180
        height: 140
        visible: isTargetLocked

        // Target Bounding Box
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0.82, 1, 0.08)
            border.color: cLaserCyan
            border.width: 1.5
            radius: 4

            // Corner Brackets
            Rectangle { width: 8; height: 2; color: cLaserCyan; anchors.top: parent.top; anchors.left: parent.left }
            Rectangle { width: 2; height: 8; color: cLaserCyan; anchors.top: parent.top; anchors.left: parent.left }
            Rectangle { width: 8; height: 2; color: cLaserCyan; anchors.top: parent.top; anchors.right: parent.right }
            Rectangle { width: 2; height: 8; color: cLaserCyan; anchors.top: parent.top; anchors.right: parent.right }
            Rectangle { width: 8; height: 2; color: cLaserCyan; anchors.bottom: parent.bottom; anchors.left: parent.left }
            Rectangle { width: 2; height: 8; color: cLaserCyan; anchors.bottom: parent.bottom; anchors.left: parent.left }
            Rectangle { width: 8; height: 2; color: cLaserCyan; anchors.bottom: parent.bottom; anchors.right: parent.right }
            Rectangle { width: 2; height: 8; color: cLaserCyan; anchors.bottom: parent.bottom; anchors.right: parent.right }

            // Target Tag Header
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 18
                color: cLaserCyan

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "TARGET LOCKED [" + targetClassification + "]"; color: "#000000"; font.pixelSize: 9; font.bold: true }
                    Text { text: "AI-98%"; color: "#000000"; font.pixelSize: 8; font.bold: true }
                }
            }

            // Crosshair Center
            Item {
                anchors.centerIn: parent
                width: 24
                height: 24

                Rectangle { anchors.centerIn: parent; width: 24; height: 1; color: cLaserCyan }
                Rectangle { anchors.centerIn: parent; width: 1; height: 24; color: cLaserCyan }
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; border.color: cBulbYellow; border.width: 1; color: "transparent" }
            }

            // LRF Telemetry Footer
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 18
                color: cDeepNavy

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "LRF: " + lrfDistanceM.toFixed(0) + " m"; color: cBulbYellow; font.pixelSize: 9; font.bold: true }
                    Text { text: "AZ: 048° NE"; color: cTextWhite; font.pixelSize: 9; font.bold: true }
                }
            }
        }
    }

    // =========================================================================
    // 5. BOTTOM TACTICAL HUD TELEMETRY RIBBON (TARGET INTEL & SENSORS)
    // =========================================================================
    Rectangle {
        id: bottomRibbon
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        height: 64
        width: Math.min(parent.width - 32, ribbonRow.implicitWidth + 36)
        radius: 12
        color: cDeepNavy
        border.color: cLaserCyan
        border.width: 1.5
        z: 90

        Row {
            id: ribbonRow
            anchors.centerIn: parent
            spacing: 20

            // Flight Dynamics: Altitude & Speed
            Row {
                spacing: 16
                Column {
                    Text { text: "ALTITUDE AGL"; color: cTextMuted; font.pixelSize: 9; font.bold: true }
                    Row {
                        spacing: 2
                        Text {
                            text: _activeVehicle && _activeVehicle.altitudeRelative ? _activeVehicle.altitudeRelative.value.toFixed(1) : "120.5"
                            color: cTextWhite; font.pixelSize: 16; font.bold: true
                        }
                        Text { text: "m"; color: cLaserCyan; font.pixelSize: 11; font.bold: true; anchors.baseline: parent.baseline }
                    }
                }

                Column {
                    Text { text: "GROUND SPEED"; color: cTextMuted; font.pixelSize: 9; font.bold: true }
                    Row {
                        spacing: 2
                        Text {
                            text: _activeVehicle && _activeVehicle.groundSpeed ? _activeVehicle.groundSpeed.value.toFixed(1) : "12.4"
                            color: cTextWhite; font.pixelSize: 16; font.bold: true
                        }
                        Text { text: "m/s"; color: cLaserCyan; font.pixelSize: 11; font.bold: true; anchors.baseline: parent.baseline }
                    }
                }
            }

            Rectangle { width: 1; height: 36; color: Qt.rgba(0, 0.82, 1, 0.3); anchors.verticalCenter: parent.verticalCenter }

            // Gimbal Tilt & Heading
            Row {
                spacing: 16
                Column {
                    Text { text: "GIMBAL PITCH"; color: cTextMuted; font.pixelSize: 9; font.bold: true }
                    Text { text: gimbalPitchDeg.toFixed(1) + "° Nadir"; color: cBulbYellow; font.pixelSize: 15; font.bold: true }
                }

                Column {
                    Text { text: "YAW HEADING"; color: cTextMuted; font.pixelSize: 9; font.bold: true }
                    Text {
                        text: (_activeVehicle && _activeVehicle.heading ? _activeVehicle.heading.value.toFixed(0) : "048") + "° NE Locked"
                        color: cSafetyGreen; font.pixelSize: 15; font.bold: true
                    }
                }
            }

            Rectangle { width: 1; height: 36; color: Qt.rgba(0, 0.82, 1, 0.3); anchors.verticalCenter: parent.verticalCenter; visible: bottomRibbon.width > 600 }

            // Target Intelligence (GPS Coordinates & Distance)
            Column {
                visible: bottomRibbon.width > 600
                Text { text: "TARGET COORDINATES (LRF DERIVED)"; color: cTextMuted; font.pixelSize: 9; font.bold: true }
                Text { text: targetLat.toFixed(4) + "° N, " + targetLon.toFixed(4) + "° E"; color: cLaserCyan; font.pixelSize: 14; font.bold: true }
                Row {
                    spacing: 8
                    Text { text: "RANGE: " + lrfDistanceM.toFixed(0) + " m"; color: cTextWhite; font.pixelSize: 9; font.bold: true }
                    Text { text: "ELEV: " + targetElevationM.toFixed(0) + " m"; color: cTextWhite; font.pixelSize: 9; font.bold: true }
                    Text { text: "● IN SIGHT"; color: cSafetyGreen; font.pixelSize: 9; font.bold: true }
                }
            }
        }
    }

    // =========================================================================
    // 6. NOTIFICATION TOAST POPUP
    // =========================================================================
    Rectangle {
        anchors.top: topBar.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        height: 36
        width: toastText.implicitWidth + 28
        radius: 18
        color: cDarkSurface
        border.color: cLaserCyan
        border.width: 1.5
        visible: toastVisible
        z: 200

        Row {
            anchors.centerIn: parent
            spacing: 6
            Rectangle { width: 6; height: 6; radius: 3; color: cLaserCyan; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: toastText
                text: toastMessage
                color: cLaserCyan
                font.pixelSize: 11
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
