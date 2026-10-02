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
    property var pipView

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _vehicleConnected: !!_activeVehicle

    // Company Brand Palette
    readonly property color cDeepNavy:     "#23285D"
    readonly property color cDarkSurface:   "#181B3D"
    readonly property color cBulbYellow:    "#F0DE2A"
    readonly property color cSafetyGreen:   "#10B981"
    readonly property color cTacticalCyan:  "#38BDF8"
    readonly property color cAlertRed:      "#EF4444"
    readonly property color cTextWhite:     "#FFFFFF"
    readonly property color cTextMuted:     "#94A3B8"

    // AB Point state
    property var    pointA:             null
    property var    pointB:             null
    property bool   modeMenuOpen:       false
    property bool   abModeActive:       false
    property bool   isCameraLightOn:    false
    property real   workDoneMu:         0.0
    property real   sprayFlowLMin:      0.0
    property real   totalSprayL:        0.0

    // =========================================================================
    // 1. TOP BAR (JIYI HEADER)
    // =========================================================================
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(52, ScreenTools.toolbarHeight)
        color: cDeepNavy
        z: 100

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: cBulbYellow
        }

        // Top-Left Section: 1-Tap Home + Device Status
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

            // Connection Badge Pill
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
                        text: _vehicleConnected ? ("IRS-PAWAN | " + (_activeVehicle.flightMode ? _activeVehicle.flightMode : "KX-V2")) : "Connect"
                        color: _vehicleConnected ? cSafetyGreen : cAlertRed
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
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

        // Top-Right Section: Telemetry Indicators + Settings Hamburger
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // RC & HD Signal
            Rectangle {
                height: 34
                width: 74
                radius: 6
                color: cDarkSurface
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Row {
                        spacing: 4
                        Text { text: "RC"; color: cTextMuted; font.pixelSize: 9; font.bold: true }
                        Text { text: _vehicleConnected ? "||||" : "--"; color: _vehicleConnected ? cSafetyGreen : cTextMuted; font.pixelSize: 9; font.bold: true }
                    }
                    Row {
                        spacing: 4
                        Text { text: "HD"; color: cTextMuted; font.pixelSize: 9; font.bold: true }
                        Text { text: _vehicleConnected ? "||||" : "--"; color: _vehicleConnected ? cSafetyGreen : cTextMuted; font.pixelSize: 9; font.bold: true }
                    }
                }
            }

            // Smart Battery (Green S, Voltage, %)
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
                            text: "S"
                            color: "#FFFFFF"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    Text {
                        text: _activeVehicle && _activeVehicle.battery && _activeVehicle.battery.voltage ? _activeVehicle.battery.voltage.value.toFixed(1) + "V" : "24.8V"
                        color: cSafetyGreen
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: _activeVehicle && _activeVehicle.battery && _activeVehicle.battery.percentRemaining ? _activeVehicle.battery.percentRemaining.value.toFixed(0) + "%" : "98%"
                        color: cTextMuted
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Satellites & RTK
            Rectangle {
                height: 34
                width: satRow.implicitWidth + 14
                radius: 6
                color: cDarkSurface
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Row {
                    id: satRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "SAT " + (_activeVehicle && _activeVehicle.gps ? _activeVehicle.gps.count.value : "18")
                        color: cTextWhite
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: cSafetyGreen
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "RTK"
                        color: cSafetyGreen
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Flight Mode Pill
            Rectangle {
                height: 34
                width: modeText.implicitWidth + 16
                radius: 6
                color: cDarkSurface
                border.color: cBulbYellow
                border.width: 1.5

                Text {
                    id: modeText
                    anchors.centerIn: parent
                    text: "MODE: " + (_activeVehicle && _activeVehicle.flightMode ? _activeVehicle.flightMode : (abModeActive ? "AB" : "M"))
                    color: cBulbYellow
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: modeMenuOpen = !modeMenuOpen
                }
            }

            // Sprayer Flow
            Rectangle {
                height: 34
                width: sprayText.implicitWidth + 14
                radius: 6
                color: cDarkSurface
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Text {
                    id: sprayText
                    anchors.centerIn: parent
                    text: "SPRAY 100%"
                    color: cTacticalCyan
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            // Radar Clearance
            Rectangle {
                height: 34
                width: radarText.implicitWidth + 14
                radius: 6
                color: cDarkSurface
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Text {
                    id: radarText
                    anchors.centerIn: parent
                    text: "RADAR 2.0m"
                    color: cSafetyGreen
                    font.pixelSize: 11
                    font.bold: true
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
    // 2. LEFT VERTICAL ACTION STRIP (AUTHENTIC JIYI)
    // =========================================================================
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: topBar.bottom
        anchors.topMargin: 16
        spacing: 12
        z: 90

        // Task / Plot List Button (📋)
        Rectangle {
            width: 44
            height: 44
            radius: 22
            color: taskMouseArea.pressed ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 1.5

            Canvas {
                anchors.centerIn: parent
                width: 20
                height: 20
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = taskMouseArea.pressed ? "#23285D" : "#FFFFFF";
                    ctx.lineWidth = 1.5;
                    ctx.strokeRect(3, 4, 14, 14);
                    ctx.fillStyle = taskMouseArea.pressed ? "#23285D" : "#FFFFFF";
                    ctx.fillRect(7, 2, 6, 3);
                    ctx.beginPath();
                    ctx.moveTo(6, 9); ctx.lineTo(14, 9);
                    ctx.moveTo(6, 12); ctx.lineTo(14, 12);
                    ctx.moveTo(6, 15); ctx.lineTo(11, 15);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: taskMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof mainWindow !== "undefined" && mainWindow.showPlanView) {
                        mainWindow.showPlanView();
                    }
                }
            }
        }

        // One-Key Takeoff / Land Button (🚀)
        Rectangle {
            width: 44
            height: 44
            radius: 22
            color: takeoffMouseArea.pressed ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 2

            Canvas {
                anchors.centerIn: parent
                width: 22
                height: 22
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = takeoffMouseArea.pressed ? "#23285D" : "#F0DE2A";
                    // Up arrow inside takeoff circle
                    ctx.beginPath();
                    ctx.moveTo(11, 3);
                    ctx.lineTo(4, 11);
                    ctx.lineTo(8, 11);
                    ctx.lineTo(8, 18);
                    ctx.lineTo(14, 18);
                    ctx.lineTo(14, 11);
                    ctx.lineTo(18, 11);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            MouseArea {
                id: takeoffMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (guidedController) {
                        if (_activeVehicle && _activeVehicle.flying) {
                            guidedController.confirmAction(guidedController.actionLand);
                        } else {
                            guidedController.confirmAction(guidedController.actionTakeoff);
                        }
                    }
                }
            }
        }

        // Flight Mode Switcher (M Circle)
        Rectangle {
            width: 44
            height: 44
            radius: 22
            color: modeCircleMouseArea.pressed ? cTacticalCyan : cDeepNavy
            border.color: cTacticalCyan
            border.width: 2

            Text {
                anchors.centerIn: parent
                text: abModeActive ? "AB" : "M"
                color: modeCircleMouseArea.pressed ? "#23285D" : cTacticalCyan
                font.pixelSize: 18
                font.bold: true
            }

            MouseArea {
                id: modeCircleMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modeMenuOpen = !modeMenuOpen
            }
        }

        // AB Point Work Strip (Blue A, Blue B, Red Direction)
        Column {
            spacing: 8

            // Point A Button (Save Point A)
            Rectangle {
                width: 44
                height: 38
                radius: 10
                color: pointA ? cSafetyGreen : (btnAMouseArea.pressed ? "#0284C7" : cTacticalCyan)
                border.color: "#FFFFFF"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "A"
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: btnAMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (_activeVehicle && _activeVehicle.coordinate.isValid) {
                            pointA = _activeVehicle.coordinate;
                            abModeActive = true;
                        }
                    }
                }
            }

            // Point B Button (Save Point B)
            Rectangle {
                width: 44
                height: 38
                radius: 10
                color: pointB ? cSafetyGreen : (btnBMouseArea.pressed ? "#0284C7" : cTacticalCyan)
                border.color: "#FFFFFF"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "B"
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: btnBMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (_activeVehicle && _activeVehicle.coordinate.isValid) {
                            pointB = _activeVehicle.coordinate;
                            abModeActive = true;
                        }
                    }
                }
            }

            // Direction Reversal Button (Red Reversal Arrow)
            Rectangle {
                width: 44
                height: 38
                radius: 10
                color: dirMouseArea.pressed ? "#B91C1C" : cAlertRed
                border.color: "#FFFFFF"
                border.width: 2

                Canvas {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "#FFFFFF";
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.arc(12, 12, 7, Math.PI, 0, false);
                        ctx.stroke();
                        // Arrow head
                        ctx.fillStyle = "#FFFFFF";
                        ctx.beginPath();
                        ctx.moveTo(5, 12);
                        ctx.lineTo(1, 7);
                        ctx.lineTo(9, 7);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                MouseArea {
                    id: dirMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Swap Point A and B
                        var temp = pointA;
                        pointA = pointB;
                        pointB = temp;
                    }
                }
            }
        }
    }

    // Mode Selector Popout Modal (Unfolds on Mode Click)
    Rectangle {
        visible: modeMenuOpen
        anchors.left: parent.left
        anchors.leftMargin: 64
        anchors.top: topBar.bottom
        anchors.topMargin: 124
        width: 140
        height: 180
        radius: 10
        color: cDeepNavy
        border.color: cBulbYellow
        border.width: 1.5
        z: 95

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            Repeater {
                model: [
                    { name: "A (Attitude)", mode: "Stabilized" },
                    { name: "M (Manual)",   mode: "Manual" },
                    { name: "AB (Operation)", mode: "AB" },
                    { name: "M+ (Sweep)",   mode: "M+" }
                ]

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 6
                    color: itemMouseArea.pressed ? cBulbYellow : (itemMouseArea.containsMouse ? cDarkSurface : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: itemMouseArea.pressed ? "#23285D" : "#FFFFFF"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.mode === "AB") {
                                abModeActive = true;
                            } else {
                                abModeActive = false;
                                if (_activeVehicle) {
                                    _activeVehicle.flightMode = modelData.mode;
                                }
                            }
                            modeMenuOpen = false;
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 3. TOP-RIGHT MAP UTILITIES (AUTHENTIC JIYI)
    // =========================================================================
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: topBar.bottom
        anchors.topMargin: 16
        spacing: 12
        z: 90

        // Compass Button (🧭)
        Rectangle {
            width: 42
            height: 42
            radius: 21
            color: compMouseArea.pressed ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 1.5

            Canvas {
                anchors.centerIn: parent
                width: 22
                height: 22
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    // North red triangle
                    ctx.fillStyle = "#EF4444";
                    ctx.beginPath();
                    ctx.moveTo(11, 2); ctx.lineTo(7, 11); ctx.lineTo(15, 11);
                    ctx.closePath();
                    ctx.fill();
                    // South white triangle
                    ctx.fillStyle = "#FFFFFF";
                    ctx.beginPath();
                    ctx.moveTo(11, 20); ctx.lineTo(7, 11); ctx.lineTo(15, 11);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            MouseArea {
                id: compMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (mapControl && typeof mapControl.bearing !== "undefined") {
                        mapControl.bearing = 0;
                    }
                }
            }
        }

        // Clear Track Button (🧹)
        Rectangle {
            width: 42
            height: 42
            radius: 21
            color: clearMouseArea.pressed ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 1.5

            Canvas {
                anchors.centerIn: parent
                width: 20
                height: 20
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = clearMouseArea.pressed ? "#23285D" : "#FFFFFF";
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(14, 4); ctx.lineTo(6, 16);
                    ctx.moveTo(4, 16); ctx.lineTo(10, 16);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: clearMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (_activeVehicle && _activeVehicle.clearTrajectoryPoints) {
                        _activeVehicle.clearTrajectoryPoints();
                    }
                }
            }
        }

        // Map Layers Toggle (🔲) (Satellite vs Street)
        Rectangle {
            width: 42
            height: 42
            radius: 21
            color: mapLayerMouseArea.pressed ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 2

            Canvas {
                anchors.centerIn: parent
                width: 22
                height: 22
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    // Bottom layer outline
                    ctx.strokeStyle = "#FFFFFF";
                    ctx.lineWidth = 1.5;
                    ctx.strokeRect(3, 7, 12, 12);
                    // Top yellow layer
                    ctx.strokeStyle = "#F0DE2A";
                    ctx.lineWidth = 1.8;
                    ctx.strokeRect(7, 3, 12, 12);
                }
            }

            MouseArea {
                id: mapLayerMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (mapControl && mapControl.supportedMapTypes) {
                        for (var i = 0; i < mapControl.supportedMapTypes.length; i++) {
                            var mt = mapControl.supportedMapTypes[i];
                            if (mapControl.isSatelliteMap) {
                                if (mt.name.indexOf("Street") > -1 || mt.name.indexOf("Road") > -1 || mt.name.indexOf("Standard") > -1) {
                                    mapControl.activeMapType = mt;
                                    break;
                                }
                            } else {
                                if (mt.name.indexOf("Satellite") > -1 || mt.name.indexOf("Hybrid") > -1) {
                                    mapControl.activeMapType = mt;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Center Aircraft Button (🎯)
        Rectangle {
            width: 42
            height: 42
            radius: 21
            color: centerMouseArea.pressed ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 1.5

            Canvas {
                anchors.centerIn: parent
                width: 22
                height: 22
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = centerMouseArea.pressed ? "#23285D" : "#FFFFFF";
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    ctx.arc(11, 11, 7, 0, 2 * Math.PI);
                    ctx.moveTo(11, 1); ctx.lineTo(11, 21);
                    ctx.moveTo(1, 11); ctx.lineTo(21, 11);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: centerMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (_activeVehicle && _activeVehicle.coordinate.isValid && mapControl) {
                        mapControl.center = _activeVehicle.coordinate;
                    }
                }
            }
        }
    }

    // =========================================================================
    // 4. BOTTOM-LEFT FPV CAMERA PIP (AUTHENTIC JIYI)
    // =========================================================================
    Rectangle {
        id: fpvPip
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 12
        width: 190
        height: 120
        radius: 8
        color: "#05070D"
        border.color: cBulbYellow
        border.width: 1.5
        clip: true
        z: 90

        Text {
            anchors.centerIn: parent
            text: "[ FPV LIVE FEED ]"
            color: cTextMuted
            font.pixelSize: 11
            font.bold: true
        }

        // Fullscreen / Swap Button (🗗)
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: 6
            width: 26
            height: 26
            radius: 4
            color: swapMouseArea.pressed ? cBulbYellow : cDeepNavy
            border.color: "#FFFFFF"
            border.width: 1

            Canvas {
                anchors.centerIn: parent
                width: 14
                height: 14
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = swapMouseArea.pressed ? "#23285D" : "#FFFFFF";
                    ctx.lineWidth = 1.2;
                    ctx.strokeRect(1, 5, 8, 8);
                    ctx.strokeRect(5, 1, 8, 8);
                }
            }

            MouseArea {
                id: swapMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (pipView && pipView._swapPip) {
                        pipView._swapPip();
                    }
                }
            }
        }

        // Headlight Spotlight Bulb Button (💡)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: 6
            width: 26
            height: 26
            radius: 4
            color: isCameraLightOn ? cBulbYellow : cDeepNavy
            border.color: cBulbYellow
            border.width: 1

            Canvas {
                anchors.centerIn: parent
                width: 14
                height: 14
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = isCameraLightOn ? "#23285D" : "#F0DE2A";
                    ctx.beginPath();
                    ctx.arc(7, 5, 4, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.fillRect(5, 9, 4, 3);
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: isCameraLightOn = !isCameraLightOn
            }
        }
    }

    // =========================================================================
    // 5. BOTTOM TELEMETRY OSD RIBBON (AUTHENTIC JIYI 2-ROW)
    // =========================================================================
    Rectangle {
        id: bottomOsd
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        anchors.left: fpvPip.right
        anchors.leftMargin: 14
        height: 72
        width: osdCol.implicitWidth + 32
        radius: 10
        color: cDeepNavy
        border.color: cBulbYellow
        border.width: 1.5
        z: 90

        Column {
            id: osdCol
            anchors.centerIn: parent
            spacing: 6

            // Row 1: Distance | Area | Flow
            Row {
                spacing: 24

                Row {
                    spacing: 6
                    Text { text: "DISTANCE:"; color: cTextMuted; font.pixelSize: 10; font.bold: true; anchors.baseline: dVal.baseline }
                    Text {
                        id: dVal
                        text: (_activeVehicle && _activeVehicle.distanceToHome ? _activeVehicle.distanceToHome.value.toFixed(1) : "0.0") + " m"
                        color: cTextWhite; font.pixelSize: 17; font.bold: true
                    }
                }

                Row {
                    spacing: 6
                    Text { text: "AREA:"; color: cTextMuted; font.pixelSize: 10; font.bold: true; anchors.baseline: aVal.baseline }
                    Text {
                        id: aVal
                        text: workDoneMu.toFixed(1) + " Mu"
                        color: cTextWhite; font.pixelSize: 17; font.bold: true
                    }
                }

                Row {
                    spacing: 6
                    Text { text: "FLOW:"; color: cTextMuted; font.pixelSize: 10; font.bold: true; anchors.baseline: fVal.baseline }
                    Text {
                        id: fVal
                        text: sprayFlowLMin.toFixed(1) + " L/min"
                        color: cTextWhite; font.pixelSize: 17; font.bold: true
                    }
                }
            }

            // Row 2: Altitude | Speed | Total Flow
            Row {
                spacing: 24

                Row {
                    spacing: 6
                    Text { text: "ALTITUDE:"; color: cTextMuted; font.pixelSize: 10; font.bold: true; anchors.baseline: altVal.baseline }
                    Text {
                        id: altVal
                        text: (_activeVehicle && _activeVehicle.altitudeRelative ? _activeVehicle.altitudeRelative.value.toFixed(1) : "0.0") + " m"
                        color: cTextWhite; font.pixelSize: 17; font.bold: true
                    }
                }

                Row {
                    spacing: 6
                    Text { text: "SPEED:"; color: cTextMuted; font.pixelSize: 10; font.bold: true; anchors.baseline: spdVal.baseline }
                    Text {
                        id: spdVal
                        text: (_activeVehicle && _activeVehicle.groundSpeed ? _activeVehicle.groundSpeed.value.toFixed(1) : "0.0") + " m/s"
                        color: cTextWhite; font.pixelSize: 17; font.bold: true
                    }
                }

                Row {
                    spacing: 6
                    Text { text: "TOTAL FLOW:"; color: cTextMuted; font.pixelSize: 10; font.bold: true; anchors.baseline: tfVal.baseline }
                    Text {
                        id: tfVal
                        text: totalSprayL.toFixed(1) + " L"
                        color: cTextWhite; font.pixelSize: 17; font.bold: true
                    }
                }
            }
        }
    }

    // =========================================================================
    // 6. BOTTOM-RIGHT EXECUTION DOCK (AUTHENTIC JIYI)
    // =========================================================================
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        spacing: 8
        z: 90

        // JIYI AB Action Bar: Cancel | B Adjust | Direction | Start
        Rectangle {
            height: 38
            width: dockRow.implicitWidth
            radius: 8
            color: cDeepNavy
            border.color: cBulbYellow
            border.width: 1.5
            clip: true

            Row {
                id: dockRow
                anchors.fill: parent

                Rectangle {
                    width: 65
                    height: parent.height
                    color: cancelMouseArea.pressed ? cDarkSurface : "transparent"
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#FFFFFF"; font.pixelSize: 12; font.bold: true }
                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        onClicked: {
                            pointA = null;
                            pointB = null;
                            abModeActive = false;
                        }
                    }
                }

                Rectangle { width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.2) }

                Rectangle {
                    width: 75
                    height: parent.height
                    color: bAdjMouseArea.pressed ? cDarkSurface : "transparent"
                    Text { anchors.centerIn: parent; text: "B Adjust"; color: "#FFFFFF"; font.pixelSize: 12; font.bold: true }
                    MouseArea {
                        id: bAdjMouseArea
                        anchors.fill: parent
                        onClicked: {
                            if (_activeVehicle && _activeVehicle.coordinate.isValid) {
                                pointB = _activeVehicle.coordinate;
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.2) }

                Rectangle {
                    width: 75
                    height: parent.height
                    color: dirBtnMouseArea.pressed ? cDarkSurface : "transparent"
                    Text { anchors.centerIn: parent; text: "Direction"; color: "#FFFFFF"; font.pixelSize: 12; font.bold: true }
                    MouseArea {
                        id: dirBtnMouseArea
                        anchors.fill: parent
                        onClicked: {
                            var temp = pointA;
                            pointA = pointB;
                            pointB = temp;
                        }
                    }
                }

                Rectangle { width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.2) }

                Rectangle {
                    width: 65
                    height: parent.height
                    color: startMouseArea.pressed ? "#059669" : cSafetyGreen
                    Text { anchors.centerIn: parent; text: "Start"; color: "#FFFFFF"; font.pixelSize: 12; font.bold: true }
                    MouseArea {
                        id: startMouseArea
                        anchors.fill: parent
                        onClicked: {
                            if (guidedController) {
                                guidedController.confirmAction(guidedController.actionStartMission);
                            }
                        }
                    }
                }
            }
        }

        // Slide to Execute Bar
        Rectangle {
            id: sliderTrack
            width: 280
            height: 38
            radius: 19
            color: cDarkSurface
            border.color: cBulbYellow
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                text: "Slide to Execute Job  >>"
                color: cBulbYellow
                font.pixelSize: 12
                font.bold: true
            }

            Rectangle {
                id: sliderThumb
                width: 34
                height: 34
                radius: 17
                color: cBulbYellow
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    color: cDeepNavy
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    id: thumbDrag
                    anchors.fill: parent
                    drag.target: sliderThumb
                    drag.axis: Drag.XAxis
                    drag.minimumX: 2
                    drag.maximumX: sliderTrack.width - sliderThumb.width - 2

                    onReleased: {
                        if (sliderThumb.x >= sliderTrack.width - sliderThumb.width - 10) {
                            if (guidedController) {
                                if (_activeVehicle && _activeVehicle.flying) {
                                    guidedController.confirmAction(guidedController.actionStartMission);
                                } else {
                                    guidedController.confirmAction(guidedController.actionTakeoff);
                                }
                            }
                        }
                        sliderThumb.x = 2;
                    }
                }
            }
        }
    }
}
