import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent

    // Navigation signals
    signal openFlyView()
    signal openPlanView()
    signal openAnalyzeView()
    signal openVehicleConfig()
    signal openSettings()
    signal logoutRequested()

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) {
            root._activeVehicle = activeVehicle
        }
    }

    readonly property string currentDroneModelName: {
        if (!_activeVehicle) {
            return qsTr("DISCONNECTED")
        }
        if (_activeVehicle.detectedModelName && _activeVehicle.detectedModelName !== "" && _activeVehicle.detectedModelName !== "UNAUTHORIZED") {
            return _activeVehicle.detectedModelName
        }
        if (_activeVehicle.vehicleTypeString && _activeVehicle.vehicleTypeString !== "" && _activeVehicle.vehicleTypeString !== "Generic micro air vehicle") {
            return "IRS " + _activeVehicle.vehicleTypeString.toUpperCase()
        }
        return qsTr("IRS DRONE")
    }

    property string activeUserName: "Admin Pilot"
    property string activeUserRole: "Flight Operations"

    // Responsive orientation detection
    readonly property bool isLandscape: root.width > root.height

    // 1. Day & Night Theme Toggle
    property bool isDarkTheme: false

    // 4. Operator Profile Dialog state
    property bool showProfileDialog: false

    // Adaptive Theme Colors
    readonly property color cTextPrimary: root.isDarkTheme ? "#F8FAFC" : "#23285D"
    readonly property color cTextSecondary: root.isDarkTheme ? "#94A3B8" : "#64748B"
    readonly property color cCardBg: root.isDarkTheme ? "#161F30" : "#F8FAFC"
    readonly property color cCardBorder: root.isDarkTheme ? "#2A374D" : "#E2E8F0"
    readonly property color cCardHover: root.isDarkTheme ? "#1E2B45" : "#FFFFFF"
    readonly property color cBottomBarBg: root.isDarkTheme ? "#0B0F17" : "#FFFFFF"
    readonly property color cBottomBarBorder: root.isDarkTheme ? "#1E293B" : "#E2E8F0"
    readonly property color cStripBg: root.isDarkTheme ? "#131B2A" : "#FFFFFF"
    readonly property color cStripBorder: root.isDarkTheme ? "#1E293B" : "#E2E8F0"

    // Prevent background clicks
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onWheel: (wheel) => wheel.accepted = true
    }

    // Adaptive Background
    Rectangle {
        id: bgRect
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.isDarkTheme ? "#080B11" : "#FFFFFF" }
            GradientStop { position: 0.35; color: root.isDarkTheme ? "#0F141F" : "#F8F9FA" }
            GradientStop { position: 1.0; color: root.isDarkTheme ? "#0C101A" : "#ECEEF2" }
        }
    }

    // ========================================================================
    // MAIN HUB INTERFACE
    // ========================================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // --------------------------------------------------------------------
        // TOP STATUS / NAVIGATION BAR
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * (root.isLandscape ? 3.0 : 3.4)
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * (root.isLandscape ? 2.5 : 1.8)
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * (root.isLandscape ? 2.5 : 1.8)
                spacing: ScreenTools.defaultFontPixelWidth * 1.5

                // Official IRS Bulb Logo
                Image {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    Layout.preferredWidth: Layout.preferredHeight * (197.0 / 297.0)
                    source: "/res/irs_logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                // Dynamic Model Name Dropdown
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    Layout.preferredWidth: modelDropdownLayout.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5
                    radius: ScreenTools.defaultFontPixelHeight * 0.5
                    color: modelDropdownMouseArea.containsMouse ? (root.isDarkTheme ? "#1E293B" : "#E2E8F0") : "transparent"

                    RowLayout {
                        id: modelDropdownLayout
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.6

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: root._activeVehicle ? "#10B981" : "#94A3B8"
                        }

                        QGCLabel {
                            text: root.currentDroneModelName
                            font.bold: true
                            font.pointSize: ScreenTools.largeFontPointSize * 1.05
                            color: root.cTextPrimary
                        }

                        QGCLabel {
                            text: "▼"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.8
                            color: root.cTextPrimary
                        }
                    }

                    MouseArea {
                        id: modelDropdownMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: modelMenu.open()
                    }

                    Menu {
                        id: modelMenu
                        y: parent.height + 4
                        MenuItem {
                            text: qsTr("⚡ IRS MODEL 1 (Quadcopter)")
                            onTriggered: if (root._activeVehicle) root._activeVehicle.detectedModelName = "IRS MODEL 1"
                        }
                        MenuItem {
                            text: qsTr("⚡ IRS MODEL 2 (Hexacopter)")
                            onTriggered: if (root._activeVehicle) root._activeVehicle.detectedModelName = "IRS MODEL 2"
                        }
                        MenuItem {
                            text: qsTr("⚡ IRS MODEL 3 (Heavy Octacopter)")
                            onTriggered: if (root._activeVehicle) root._activeVehicle.detectedModelName = "IRS MODEL 3"
                        }
                        MenuItem {
                            text: qsTr("⚡ IRS PAWAN (VTOL Hybrid)")
                            onTriggered: if (root._activeVehicle) root._activeVehicle.detectedModelName = "IRS PAWAN"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Landscape Telemetry Capsule
                Rectangle {
                    visible: root.isLandscape && root._activeVehicle !== null
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                    Layout.preferredWidth: telemetryLayout.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.5
                    radius: height / 2
                    color: root.isDarkTheme ? "#1E293B" : "#FFFFFF"
                    border.color: root.isDarkTheme ? "#334155" : "#E2E8F0"
                    border.width: 1

                    RowLayout {
                        id: telemetryLayout
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "#10B981"
                        }

                        QGCLabel {
                            text: (root._activeVehicle && root._activeVehicle.gps ? root._activeVehicle.gps.count.valueString : "19") + " Sats"
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: "#10B981"
                        }

                        QGCLabel { text: "|"; color: root.isDarkTheme ? "#475569" : "#CBD5E1" }

                        QGCLabel {
                            text: "🔋 " + (root._activeVehicle && root._activeVehicle.battery ? root._activeVehicle.battery.percentRemaining.valueString + "%" : "88%")
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: root.cTextPrimary
                        }

                        QGCLabel { text: "|"; color: root.isDarkTheme ? "#475569" : "#CBD5E1" }

                        QGCLabel {
                            text: root._activeVehicle ? root._activeVehicle.flightMode : "Loiter"
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: root.cTextPrimary
                        }
                    }
                }

                // 1. Day / Night Theme Toggle Button
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                    Layout.preferredWidth: themeToggleLayout.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.8
                    radius: height / 2
                    color: themeMouseArea.containsMouse ? (root.isDarkTheme ? "#334155" : "#E2E8F0") : (root.isDarkTheme ? "#1E293B" : "#F1F5F9")
                    border.color: root.isDarkTheme ? "#475569" : "#CBD5E1"
                    border.width: 1

                    RowLayout {
                        id: themeToggleLayout
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        QGCLabel {
                            text: root.isDarkTheme ? "🌙" : "☀️"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.95
                        }
                        QGCLabel {
                            text: root.isDarkTheme ? qsTr("Dark") : qsTr("Day")
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                            color: root.cTextPrimary
                        }
                    }

                    MouseArea {
                        id: themeMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.isDarkTheme = !root.isDarkTheme
                    }
                }

                // Operator Pill (Click opens profile dialog)
                Rectangle {
                    visible: root.isLandscape
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                    Layout.preferredWidth: pilotPillLayout.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.8
                    radius: height / 2
                    color: pilotMouseArea.containsMouse ? (root.isDarkTheme ? "#334155" : "#E2E8F0") : (root.isDarkTheme ? "#1E293B" : "#F1F5F9")
                    border.color: root.isDarkTheme ? "#475569" : "#CBD5E1"
                    border.width: 1

                    RowLayout {
                        id: pilotPillLayout
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        QGCLabel {
                            text: "👤"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }
                        QGCLabel {
                            text: root.activeUserName
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                            color: root.cTextPrimary
                        }
                    }

                    MouseArea {
                        id: pilotMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.showProfileDialog = true
                    }
                }

                // Settings Button
                QGCToolBarButton {
                    id: menuBtn
                    icon.source: "/res/QGCLogoFull.svg"
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.openSettings()
                }
            }
        }

        // --------------------------------------------------------------------
        // 2. PRE-FLIGHT HEALTH CHECKLIST STRIP
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * (root.isLandscape ? 2.5 : 2.8)
            Layout.leftMargin: ScreenTools.defaultFontPixelWidth * (root.isLandscape ? 2.5 : 1.5)
            Layout.rightMargin: ScreenTools.defaultFontPixelWidth * (root.isLandscape ? 2.5 : 1.5)
            radius: ScreenTools.defaultFontPixelHeight * 0.6
            color: root.cStripBg
            border.color: root.cStripBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.5
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.5
                spacing: ScreenTools.defaultFontPixelWidth * 1.2

                // Health Readiness Badge
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                    Layout.preferredWidth: readinessRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.4
                    radius: height / 2
                    color: root._activeVehicle ? (root.isDarkTheme ? "#064E3B" : "#ECFDF5") : (root.isDarkTheme ? "#450A0A" : "#FEF2F2")
                    border.color: root._activeVehicle ? "#10B981" : "#EF4444"
                    border.width: 1

                    RowLayout {
                        id: readinessRow
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: root._activeVehicle ? "#10B981" : "#EF4444"
                        }
                        QGCLabel {
                            text: root._activeVehicle ? qsTr("SYSTEM READY") : qsTr("DISCONNECTED")
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.75
                            color: root._activeVehicle ? "#10B981" : "#EF4444"
                        }
                    }
                }

                // Check 1: IMU / Compass
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.4
                    QGCLabel { text: "🧭"; font.pointSize: ScreenTools.smallFontPointSize * 0.85 }
                    QGCLabel {
                        text: root._activeVehicle ? qsTr("Sensors Normal") : qsTr("Sensors Standby")
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize * 0.8
                        color: root.cTextPrimary
                    }
                }

                QGCLabel { text: "|"; color: root.isDarkTheme ? "#334155" : "#CBD5E1"; visible: root.isLandscape }

                // Check 2: GPS Constellation
                RowLayout {
                    visible: root.isLandscape
                    spacing: ScreenTools.defaultFontPixelWidth * 0.4
                    QGCLabel { text: "🛰️"; font.pointSize: ScreenTools.smallFontPointSize * 0.85 }
                    QGCLabel {
                        text: root._activeVehicle && root._activeVehicle.gps ? (root._activeVehicle.gps.count.valueString + " Sats (3D Fix)") : qsTr("GPS Standby")
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize * 0.8
                        color: root.cTextPrimary
                    }
                }

                QGCLabel { text: "|"; color: root.isDarkTheme ? "#334155" : "#CBD5E1"; visible: root.isLandscape }

                // Check 3: Battery & Voltage
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.4
                    QGCLabel { text: "🔋"; font.pointSize: ScreenTools.smallFontPointSize * 0.85 }
                    QGCLabel {
                        text: root._activeVehicle && root._activeVehicle.battery ? (root._activeVehicle.battery.percentRemaining.valueString + "% (" + root._activeVehicle.battery.voltage.valueString + "V)") : qsTr("Power Standby")
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize * 0.8
                        color: root.cTextPrimary
                    }
                }

                Item { Layout.fillWidth: true }

                // Calibrate Sensors Quick Link
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                    Layout.preferredWidth: calLinkRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.4
                    radius: height / 2
                    color: calLinkMouse.containsMouse ? (root.isDarkTheme ? "#1E293B" : "#E2E8F0") : "transparent"
                    border.color: root.isDarkTheme ? "#334155" : "#CBD5E1"
                    border.width: 1

                    RowLayout {
                        id: calLinkRow
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.4
                        QGCLabel { text: "⚙️"; font.pointSize: ScreenTools.smallFontPointSize * 0.8 }
                        QGCLabel {
                            text: qsTr("Diagnostics")
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.75
                            color: root.cTextPrimary
                        }
                    }
                    MouseArea {
                        id: calLinkMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.openVehicleConfig()
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // CENTER BODY AREA
        // --------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // === LANDSCAPE LAYOUT ===
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 3
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 3
                visible: root.isLandscape
                spacing: ScreenTools.defaultFontPixelWidth * 2

                // Left: 3D Drone Hero Image
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 6

                    Image {
                        anchors.centerIn: parent
                        height: Math.min(parent.height * 0.9, parent.width * 0.8)
                        width: height * (495.0 / 570.0)
                        source: "/res/dji_drone_hero.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                }

                // Right: Action Box & Navigation
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 4
                    Layout.alignment: Qt.AlignVCenter
                    spacing: ScreenTools.defaultFontPixelHeight * 1.0

                    // Hero Enter Device Box (IRS Yellow)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 7.2
                        radius: ScreenTools.defaultFontPixelHeight * 1.2
                        color: enterMouseArea.containsMouse ? "#E5D324" : "#F0DE2A"
                        border.color: "#23285D"
                        border.width: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.9
                            spacing: ScreenTools.defaultFontPixelHeight * 0.3

                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                Rectangle {
                                    width: 8; height: 8; radius: 4; color: root._activeVehicle ? "#10B981" : "#64748B"
                                }
                                QGCLabel {
                                    text: root._activeVehicle ? qsTr("AIRCRAFT READY FOR FLIGHT") : qsTr("AIRCRAFT DISCONNECTED")
                                    font.bold: true
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.85
                                    color: "#23285D"
                                }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                QGCLabel {
                                    text: qsTr("Enter Device")
                                    font.bold: true
                                    font.italic: true
                                    font.pointSize: ScreenTools.largeFontPointSize * 1.35
                                    color: "#23285D"
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.8
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                                    radius: ScreenTools.defaultFontPixelHeight * 0.7
                                    color: "#23285D"

                                    QGCLabel {
                                        anchors.centerIn: parent
                                        text: "➔"
                                        font.bold: true
                                        font.pointSize: ScreenTools.largeFontPointSize
                                        color: "#F0DE2A"
                                    }
                                }
                            }

                            // Dark underline
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                radius: 1.5
                                color: "#23285D"
                            }
                        }

                        MouseArea {
                            id: enterMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openFlyView()
                        }
                    }

                    // 3. 3-Tile Quick Action Row (Missions, Calibrate Sensors, Flight Logs)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 0.8

                        // Tile 1: Missions
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.8
                            radius: ScreenTools.defaultFontPixelHeight * 0.7
                            color: missionsArea.containsMouse ? root.cCardHover : root.cCardBg
                            border.color: missionsArea.containsMouse ? (root.isDarkTheme ? "#38BDF8" : "#23285D") : root.cCardBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelWidth * 0.8

                                QGCLabel { text: "🗺️"; font.pointSize: ScreenTools.mediumFontPointSize }
                                ColumnLayout {
                                    spacing: 1
                                    QGCLabel { text: qsTr("Missions"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize; color: root.cTextPrimary }
                                    QGCLabel { text: qsTr("Survey"); font.pointSize: ScreenTools.smallFontPointSize * 0.8; color: root.cTextSecondary }
                                }
                            }

                            MouseArea {
                                id: missionsArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openPlanView()
                            }
                        }

                        // Tile 2: Calibrate Sensors
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.8
                            radius: ScreenTools.defaultFontPixelHeight * 0.7
                            color: calArea.containsMouse ? root.cCardHover : root.cCardBg
                            border.color: calArea.containsMouse ? (root.isDarkTheme ? "#38BDF8" : "#23285D") : root.cCardBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelWidth * 0.8

                                QGCLabel { text: "🧭"; font.pointSize: ScreenTools.mediumFontPointSize }
                                ColumnLayout {
                                    spacing: 1
                                    QGCLabel { text: qsTr("Calibrate"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize; color: root.cTextPrimary }
                                    QGCLabel { text: qsTr("Sensors"); font.pointSize: ScreenTools.smallFontPointSize * 0.8; color: root.cTextSecondary }
                                }
                            }

                            MouseArea {
                                id: calArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openVehicleConfig()
                            }
                        }

                        // Tile 3: Flight Logs
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.8
                            radius: ScreenTools.defaultFontPixelHeight * 0.7
                            color: logsArea.containsMouse ? root.cCardHover : root.cCardBg
                            border.color: logsArea.containsMouse ? (root.isDarkTheme ? "#38BDF8" : "#23285D") : root.cCardBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelWidth * 0.8

                                QGCLabel { text: "📋"; font.pointSize: ScreenTools.mediumFontPointSize }
                                ColumnLayout {
                                    spacing: 1
                                    QGCLabel { text: qsTr("Logs"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize; color: root.cTextPrimary }
                                    QGCLabel { text: qsTr("Replay"); font.pointSize: ScreenTools.smallFontPointSize * 0.8; color: root.cTextSecondary }
                                }
                            }

                            MouseArea {
                                id: logsArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openAnalyzeView()
                            }
                        }
                    }
                }
            }

            // === PORTRAIT LAYOUT ===
            ColumnLayout {
                anchors.fill: parent
                visible: !root.isLandscape
                spacing: 0

                // Center Drone Visual
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.95
                        height: parent.height * 0.95
                        source: "/res/dji_drone_hero.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                }

                // 3 Quick Action Tiles in Portrait
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 1.5
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 1.5
                    spacing: ScreenTools.defaultFontPixelWidth * 0.8

                    // Missions
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                        radius: ScreenTools.defaultFontPixelHeight * 0.6
                        color: root.cCardBg
                        border.color: root.cCardBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel { text: "🗺️"; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: qsTr("Missions"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextPrimary }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openPlanView()
                        }
                    }

                    // Calibrate
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                        radius: ScreenTools.defaultFontPixelHeight * 0.6
                        color: root.cCardBg
                        border.color: root.cCardBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel { text: "🧭"; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: qsTr("Calibrate"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextPrimary }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openVehicleConfig()
                        }
                    }

                    // Logs
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                        radius: ScreenTools.defaultFontPixelHeight * 0.6
                        color: root.cCardBg
                        border.color: root.cCardBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel { text: "📋"; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: qsTr("Logs"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextPrimary }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openAnalyzeView()
                        }
                    }
                }

                // Lower Action Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 5.0
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 2

                        // Left: Connection Status
                        ColumnLayout {
                            spacing: ScreenTools.defaultFontPixelHeight * 0.2
                            QGCLabel {
                                text: "🧭"
                                font.pointSize: ScreenTools.largeFontPointSize
                                Layout.alignment: Qt.AlignHCenter
                            }
                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    width: 6; height: 6; radius: 3; color: root._activeVehicle ? "#10B981" : "#94A3B8"
                                }
                                QGCLabel {
                                    text: root._activeVehicle ? qsTr("CONNECTED (%1%)").arg(root._activeVehicle.battery ? root._activeVehicle.battery.percentRemaining.valueString : "88") : qsTr("DISCONNECTED")
                                    font.bold: true
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.85
                                    color: root._activeVehicle ? "#10B981" : "#94A3B8"
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Right: Enter Device CTA with IRS Yellow Slanted Bar
                        ColumnLayout {
                            spacing: 4
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                            RowLayout {
                                spacing: 6
                                QGCLabel {
                                    text: qsTr("Enter Device")
                                    font.bold: true
                                    font.italic: true
                                    font.pointSize: ScreenTools.largeFontPointSize * 1.2
                                    color: root.cTextPrimary
                                }
                                QGCLabel {
                                    text: ">"
                                    font.bold: true
                                    font.pointSize: ScreenTools.largeFontPointSize * 1.2
                                    color: root.cTextPrimary
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
                                Layout.preferredHeight: 6
                                radius: 3
                                color: "#F0DE2A"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openFlyView()
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // BOTTOM NAVIGATION BAR
        // --------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * (root.isLandscape ? 2.8 : 3.6)
            color: root.cBottomBarBg
            border.color: root.cBottomBarBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * (root.isLandscape ? 4 : 2)
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * (root.isLandscape ? 4 : 2)
                spacing: ScreenTools.defaultFontPixelWidth * (root.isLandscape ? 4 : 1)

                // Tab 1: Equipment (Active)
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    QGCLabel {
                        text: "🛸 " + qsTr("Equipment")
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: root.cTextPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Rectangle {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                        Layout.preferredHeight: 3
                        radius: 1.5
                        color: "#F0DE2A"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Tab 2: Missions
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    QGCLabel {
                        text: "🗺️ " + qsTr("Missions")
                        font.bold: false
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: root.cTextSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openPlanView()
                    }
                }

                // Tab 3: Logs
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    QGCLabel {
                        text: "📊 " + qsTr("Logs")
                        font.bold: false
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: root.cTextSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openAnalyzeView()
                    }
                }

                // Tab 4: Profile / Me -> Opens Operator Profile Dialog
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    QGCLabel {
                        text: "👤 " + qsTr("Me")
                        font.bold: false
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: root.cTextSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showProfileDialog = true
                    }
                }

                Item { Layout.fillWidth: true; visible: root.isLandscape }

                // Version string
                QGCLabel {
                    visible: root.isLandscape
                    text: "IRS GCS v1.0.6 • Nextkick System Ready"
                    font.pointSize: ScreenTools.smallFontPointSize * 0.85
                    color: root.cTextSecondary
                }
            }
        }
    }

    // ========================================================================
    // 4. OPERATOR PROFILE POPUP MODAL
    // ========================================================================
    Rectangle {
        id: profileModalOverlay
        anchors.fill: parent
        visible: root.showProfileDialog
        z: 9999
        color: "#88000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.showProfileDialog = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(root.width * 0.9, ScreenTools.defaultFontPixelWidth * 44)
            implicitHeight: profileDialogLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 2.2
            radius: ScreenTools.defaultFontPixelHeight * 1.0
            color: root.isDarkTheme ? "#161F30" : "#FFFFFF"
            border.color: root.isDarkTheme ? "#2A374D" : "#CBD5E1"
            border.width: 1

            // Prevent clicks from propagating to overlay
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: profileDialogLayout
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 1.1
                spacing: ScreenTools.defaultFontPixelHeight * 0.8

                // Header: Title & Close Button
                RowLayout {
                    Layout.fillWidth: true
                    QGCLabel {
                        text: qsTr("👤 Operator Profile & Security")
                        font.bold: true
                        font.pointSize: ScreenTools.mediumFontPointSize * 1.1
                        color: root.cTextPrimary
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: ScreenTools.defaultFontPixelHeight * 1.8
                        height: width
                        radius: width / 2
                        color: closeMouse.containsMouse ? (root.isDarkTheme ? "#334155" : "#E2E8F0") : "transparent"
                        QGCLabel {
                            anchors.centerIn: parent
                            text: "✕"
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: root.cTextSecondary
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.showProfileDialog = false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.isDarkTheme ? "#2A374D" : "#E2E8F0"
                }

                // Operator Avatar & Identity Info
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 1.5

                    Rectangle {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.6
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: Layout.preferredWidth / 2
                        color: "#23285D"
                        border.color: "#F0DE2A"
                        border.width: 2
                        QGCLabel {
                            anchors.centerIn: parent
                            text: root.activeUserName.length > 0 ? root.activeUserName.charAt(0).toUpperCase() : "U"
                            font.bold: true
                            font.pointSize: ScreenTools.largeFontPointSize * 1.1
                            color: "#F0DE2A"
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        QGCLabel {
                            text: root.activeUserName
                            font.bold: true
                            font.pointSize: ScreenTools.largeFontPointSize
                            color: root.cTextPrimary
                        }
                        QGCLabel {
                            text: "Nextkick Aerospace • IRS Flight Ops"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                            color: root.cTextSecondary
                        }
                    }
                }

                // Security & Device Authorization Details
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: credCol.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.0
                    radius: ScreenTools.defaultFontPixelHeight * 0.6
                    color: root.isDarkTheme ? "#0F172A" : "#F8FAFC"
                    border.color: root.isDarkTheme ? "#1E293B" : "#E2E8F0"
                    border.width: 1

                    ColumnLayout {
                        id: credCol
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.6
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel { text: qsTr("Assigned Role:"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextSecondary }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                                Layout.preferredWidth: roleLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.4
                                radius: height / 2
                                color: "#23285D"
                                QGCLabel {
                                    id: roleLabel
                                    anchors.centerIn: parent
                                    text: root.activeUserRole
                                    font.bold: true
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.8
                                    color: "#F0DE2A"
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel { text: qsTr("License Status:"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextSecondary }
                            Item { Layout.fillWidth: true }
                            QGCLabel { text: qsTr("🟢 DGCA UAS Pilot Authorization"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: "#10B981" }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel { text: qsTr("Station HWID:"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextSecondary }
                            Item { Layout.fillWidth: true }
                            QGCLabel { text: "IRS-GCS-STATION-661006"; font.bold: false; font.pointSize: ScreenTools.smallFontPointSize * 0.8; color: root.cTextSecondary }
                        }
                    }
                }

                // Action Buttons: Switch Role & Log Out
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    // Switch Role Button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        radius: ScreenTools.defaultFontPixelHeight * 0.5
                        color: switchMouse.containsMouse ? (root.isDarkTheme ? "#334155" : "#E2E8F0") : (root.isDarkTheme ? "#1E293B" : "#F1F5F9")
                        border.color: root.isDarkTheme ? "#475569" : "#CBD5E1"
                        border.width: 1

                        QGCLabel {
                            anchors.centerIn: parent
                            text: qsTr("🔄 Switch Role")
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            color: root.cTextPrimary
                        }

                        MouseArea {
                            id: switchMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (root.activeUserRole === "Administrator") {
                                    root.activeUserRole = "Drone Pilot"
                                } else {
                                    root.activeUserRole = "Administrator"
                                }
                            }
                        }
                    }

                    // Log Out Button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        radius: ScreenTools.defaultFontPixelHeight * 0.5
                        color: logoutMouse.containsMouse ? "#DC2626" : "#EF4444"

                        QGCLabel {
                            anchors.centerIn: parent
                            text: qsTr("🚪 Log Out")
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            id: logoutMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                root.showProfileDialog = false
                                root.logoutRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}
