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
            if (activeVehicle) {
                if (activeVehicle.detectedModelName.indexOf("PAWAN") !== -1) {
                    root.selectedModelIndex = 0
                } else if (activeVehicle.detectedModelName.indexOf("VAYU") !== -1) {
                    root.selectedModelIndex = 1
                }
            }
        }
    }

    // Only 2 Drones in the fleet
    // 0 = IRS PAWAN (VTOL Hybrid), 1 = IRS VAYU (Heavy Hexacopter)
    property int selectedModelIndex: 0
    readonly property string selectedModelName: selectedModelIndex === 0 ? "IRS PAWAN" : "IRS VAYU"

    readonly property string currentDroneModelName: {
        if (!_activeVehicle) {
            return root.selectedModelName + " " + qsTr("(DISCONNECTED)")
        }
        if (_activeVehicle.detectedModelName && _activeVehicle.detectedModelName !== "" && _activeVehicle.detectedModelName !== "UNAUTHORIZED") {
            return _activeVehicle.detectedModelName
        }
        return root.selectedModelName
    }

    property string activeUserName: "Admin Pilot"
    property string activeUserRole: "Flight Operations"
    readonly property bool isAdmin: activeUserRole.toLowerCase().indexOf("admin") !== -1

    function showAccessRestricted(featureName) {
        mainWindow.showMessageDialog(
            qsTr("Access Restricted"),
            qsTr("Access to %1 is restricted to Administrator accounts.\n\nYour assigned role: %2\n\nUnder IRS Drone Operations policy, pilots are granted flight control and mission planning access only. Vehicle calibration, parameter tuning, and application settings require Administrator credentials.").arg(featureName).arg(activeUserRole),
            Dialog.Ok
        )
    }

    // Responsive orientation detection
    readonly property bool isLandscape: root.width > root.height

    // 1. Day & Night Theme Toggle
    property bool isDarkTheme: false

    // Modals
    property bool showProfileDialog: false
    property bool showBluetoothSheet: false
    property bool showProtocolSheet: false

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

                // Dynamic Model Dropdown (PAWAN & VAYU only)
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
                            text: qsTr("🛸 IRS PAWAN (VTOL Hybrid)")
                            onTriggered: {
                                root.selectedModelIndex = 0
                                if (root._activeVehicle) root._activeVehicle.detectedModelName = "IRS PAWAN"
                            }
                        }
                        MenuItem {
                            text: qsTr("🛸 IRS VAYU (Heavy Hexacopter)")
                            onTriggered: {
                                root.selectedModelIndex = 1
                                if (root._activeVehicle) root._activeVehicle.detectedModelName = "IRS VAYU"
                            }
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

                // Settings Button (Admin Only)
                QGCToolBarButton {
                    id: menuBtn
                    visible: root.isAdmin
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
                        QGCLabel { text: root.isAdmin ? "⚙️" : "🔒"; font.pointSize: ScreenTools.smallFontPointSize * 0.8 }
                        QGCLabel {
                            text: root.isAdmin ? qsTr("Diagnostics") : qsTr("Diagnostics (Admin)")
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
                        onClicked: {
                            if (root.isAdmin) {
                                root.openVehicleConfig()
                            } else {
                                root.showAccessRestricted(qsTr("Vehicle Diagnostics & Calibration"))
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // MODEL SELECTION PILLS (ONLY 2 MODELS: PAWAN & VAYU)
        // --------------------------------------------------------------------
        Rectangle {
            visible: !root._activeVehicle
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
            color: "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 1.5

                // Pill 1: IRS PAWAN
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    Layout.preferredWidth: pawanPillLayout.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.0
                    radius: height / 2
                    color: root.selectedModelIndex === 0 ? "#F0DE2A" : (root.isDarkTheme ? "#162032" : "#E2E8F0")
                    border.color: root.selectedModelIndex === 0 ? "#23285D" : (root.isDarkTheme ? "#283750" : "#CBD5E1")
                    border.width: root.selectedModelIndex === 0 ? 2 : 1

                    RowLayout {
                        id: pawanPillLayout
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        QGCLabel { text: "🛸"; font.pointSize: ScreenTools.smallFontPointSize }
                        QGCLabel {
                            text: "IRS PAWAN (VTOL)"
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                            color: root.selectedModelIndex === 0 ? "#23285D" : root.cTextPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedModelIndex = 0
                    }
                }

                // Pill 2: IRS VAYU
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    Layout.preferredWidth: vayuPillLayout.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.0
                    radius: height / 2
                    color: root.selectedModelIndex === 1 ? "#F0DE2A" : (root.isDarkTheme ? "#162032" : "#E2E8F0")
                    border.color: root.selectedModelIndex === 1 ? "#23285D" : (root.isDarkTheme ? "#283750" : "#CBD5E1")
                    border.width: root.selectedModelIndex === 1 ? 2 : 1

                    RowLayout {
                        id: vayuPillLayout
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        QGCLabel { text: "🛸"; font.pointSize: ScreenTools.smallFontPointSize }
                        QGCLabel {
                            text: "IRS VAYU (Hexacopter)"
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                            color: root.selectedModelIndex === 1 ? "#23285D" : root.cTextPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedModelIndex = 1
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

                // Left: ZERO-BOX DIRECT FLOATING DRONE IMAGE
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 6

                    // Direct Transparent Floating Image (NO BACKGROUND BOX)
                    Image {
                        id: droneImage
                        anchors.centerIn: parent
                        height: Math.min(parent.height * 0.92, parent.width * 0.85)
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
                    spacing: ScreenTools.defaultFontPixelHeight * (ScreenTools.isMobile ? 0.4 : 0.8)

                    // Hero Enter / Connect Box (IRS Yellow)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 4.6 : ScreenTools.defaultFontPixelHeight * 6.5
                        radius: ScreenTools.defaultFontPixelHeight * (ScreenTools.isMobile ? 0.8 : 1.2)
                        color: enterMouseArea.containsMouse ? "#E5D324" : "#F0DE2A"
                        border.color: "#23285D"
                        border.width: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * (ScreenTools.isMobile ? 0.5 : 0.9)
                            spacing: ScreenTools.defaultFontPixelHeight * 0.2

                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                Rectangle {
                                    width: 8; height: 8; radius: 4; color: root._activeVehicle ? "#10B981" : "#64748B"
                                }
                                QGCLabel {
                                    text: root._activeVehicle ? qsTr("AIRCRAFT READY FOR FLIGHT") : (root.selectedModelName + " " + qsTr("DISCONNECTED"))
                                    font.bold: true
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.8
                                    color: "#23285D"
                                }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    spacing: 1
                                    QGCLabel {
                                        text: root._activeVehicle ? qsTr("Enter Device") : (qsTr("Connect ") + root.selectedModelName)
                                        font.bold: true
                                        font.italic: true
                                        font.pointSize: ScreenTools.largeFontPointSize * (ScreenTools.isMobile ? 1.05 : 1.3)
                                        color: "#23285D"
                                    }
                                    QGCLabel {
                                        visible: !root._activeVehicle
                                        text: root.selectedModelIndex === 0 ? qsTr("Skydroid T10 (Bluetooth)") : qsTr("SIYI MK15 / G12 (Multi-Link)")
                                        font.pointSize: ScreenTools.smallFontPointSize * 0.75
                                        color: "#475569"
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * (ScreenTools.isMobile ? 2.2 : 2.8)
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * (ScreenTools.isMobile ? 2.2 : 2.8)
                                    radius: ScreenTools.defaultFontPixelHeight * 0.6
                                    color: "#23285D"

                                    QGCLabel {
                                        anchors.centerIn: parent
                                        text: "➔"
                                        font.bold: true
                                        font.pointSize: ScreenTools.largeFontPointSize * (ScreenTools.isMobile ? 0.85 : 1.0)
                                        color: "#F0DE2A"
                                    }
                                }
                            }

                            // Dark underline
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 2.5
                                radius: 1.25
                                color: "#23285D"
                            }
                        }

                        MouseArea {
                            id: enterMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root._activeVehicle) {
                                    root.openFlyView()
                                } else {
                                    if (root.selectedModelIndex === 0) {
                                        root.showBluetoothSheet = true
                                    } else {
                                        root.showProtocolSheet = true
                                    }
                                }
                            }
                        }
                    }

                    // 3-Tile Quick Action Row (Missions, Calibrate Sensors, Flight Logs)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 0.8

                        // Tile 1: Missions
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 2.5 : ScreenTools.defaultFontPixelHeight * 3.4
                            radius: ScreenTools.defaultFontPixelHeight * 0.6
                            color: missionsArea.containsMouse ? root.cCardHover : root.cCardBg
                            border.color: missionsArea.containsMouse ? (root.isDarkTheme ? "#38BDF8" : "#23285D") : root.cCardBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelWidth * 0.6

                                QGCLabel { text: "🗺️"; font.pointSize: ScreenTools.isMobile ? ScreenTools.smallFontPointSize * 1.05 : ScreenTools.mediumFontPointSize }
                                ColumnLayout {
                                    spacing: 1
                                    QGCLabel { text: qsTr("Missions"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * (ScreenTools.isMobile ? 0.85 : 1.0); color: root.cTextPrimary }
                                    QGCLabel { text: qsTr("Survey"); font.pointSize: ScreenTools.smallFontPointSize * (ScreenTools.isMobile ? 0.7 : 0.8); color: root.cTextSecondary }
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
                            Layout.preferredHeight: ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 2.5 : ScreenTools.defaultFontPixelHeight * 3.4
                            radius: ScreenTools.defaultFontPixelHeight * 0.6
                            color: calArea.containsMouse ? root.cCardHover : root.cCardBg
                            border.color: calArea.containsMouse ? (root.isDarkTheme ? "#38BDF8" : "#23285D") : root.cCardBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelWidth * 0.6

                                QGCLabel { text: root.isAdmin ? "🧭" : "🔒"; font.pointSize: ScreenTools.isMobile ? ScreenTools.smallFontPointSize * 1.05 : ScreenTools.mediumFontPointSize }
                                ColumnLayout {
                                    spacing: 1
                                    QGCLabel { text: root.isAdmin ? qsTr("Calibrate") : qsTr("Calibrate (Admin)"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * (ScreenTools.isMobile ? 0.85 : 1.0); color: root.cTextPrimary }
                                    QGCLabel { text: root.isAdmin ? qsTr("Sensors") : qsTr("Admin Only"); font.pointSize: ScreenTools.smallFontPointSize * (ScreenTools.isMobile ? 0.7 : 0.8); color: root.isAdmin ? root.cTextSecondary : "#EAB308" }
                                }
                            }

                            MouseArea {
                                id: calArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.isAdmin) {
                                        root.openVehicleConfig()
                                    } else {
                                        root.showAccessRestricted(qsTr("Vehicle Calibration & Setup"))
                                    }
                                }
                            }
                        }

                        // Tile 3: Flight Logs
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 2.5 : ScreenTools.defaultFontPixelHeight * 3.4
                            radius: ScreenTools.defaultFontPixelHeight * 0.6
                            color: logsArea.containsMouse ? root.cCardHover : root.cCardBg
                            border.color: logsArea.containsMouse ? (root.isDarkTheme ? "#38BDF8" : "#23285D") : root.cCardBorder
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelWidth * 0.6

                                QGCLabel { text: root.isAdmin ? "📋" : "🔒"; font.pointSize: ScreenTools.isMobile ? ScreenTools.smallFontPointSize * 1.05 : ScreenTools.mediumFontPointSize }
                                ColumnLayout {
                                    spacing: 1
                                    QGCLabel { text: root.isAdmin ? qsTr("Logs") : qsTr("Logs (Admin)"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * (ScreenTools.isMobile ? 0.85 : 1.0); color: root.cTextPrimary }
                                    QGCLabel { text: root.isAdmin ? qsTr("Replay") : qsTr("Admin Only"); font.pointSize: ScreenTools.smallFontPointSize * (ScreenTools.isMobile ? 0.7 : 0.8); color: root.isAdmin ? root.cTextSecondary : "#EAB308" }
                                }
                            }

                            MouseArea {
                                id: logsArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.isAdmin) {
                                        root.openAnalyzeView()
                                    } else {
                                        root.showAccessRestricted(qsTr("Flight Logs & Analyze Tools"))
                                    }
                                }
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

                // Center Zero-Box Drone Visual
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
                            QGCLabel { text: root.isAdmin ? "🧭" : "🔒"; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: root.isAdmin ? qsTr("Calibrate") : qsTr("Calibrate (Admin)"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextPrimary }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.isAdmin) {
                                    root.openVehicleConfig()
                                } else {
                                    root.showAccessRestricted(qsTr("Vehicle Calibration & Setup"))
                                }
                            }
                        }
                    }

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
                            QGCLabel { text: root.isAdmin ? "📋" : "🔒"; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: root.isAdmin ? qsTr("Logs") : qsTr("Logs (Admin)"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextPrimary }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.isAdmin) {
                                    root.openAnalyzeView()
                                } else {
                                    root.showAccessRestricted(qsTr("Flight Logs & Analyze Tools"))
                                }
                            }
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

                        // Right: Enter Device CTA
                        ColumnLayout {
                            spacing: 4
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                            RowLayout {
                                spacing: 6
                                QGCLabel {
                                    text: root._activeVehicle ? qsTr("Enter Device") : (qsTr("Connect ") + root.selectedModelName)
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
                                onClicked: {
                                    if (root._activeVehicle) {
                                        root.openFlyView()
                                    } else {
                                        if (root.selectedModelIndex === 0) {
                                            root.showBluetoothSheet = true
                                        } else {
                                            root.showProtocolSheet = true
                                        }
                                    }
                                }
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
                    text: "IRS GCS v1.1.0 • Encrypted Nextkick Fleet"
                    font.pointSize: ScreenTools.smallFontPointSize * 0.85
                    color: root.cTextSecondary
                }
            }
        }
    }

    // ========================================================================
    // BLUETOOTH FAST CONNECT SHEET (FOR IRS PAWAN / SKYDROID T10)
    // ========================================================================
    Rectangle {
        id: btModalOverlay
        anchors.fill: parent
        visible: root.showBluetoothSheet
        z: 9998
        color: "#88000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.showBluetoothSheet = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(root.width * 0.9, ScreenTools.defaultFontPixelWidth * 42)
            implicitHeight: btDialogLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 2.2
            radius: ScreenTools.defaultFontPixelHeight * 1.0
            color: root.isDarkTheme ? "#161F30" : "#FFFFFF"
            border.color: root.isDarkTheme ? "#2A374D" : "#CBD5E1"
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: btDialogLayout
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 1.1
                spacing: ScreenTools.defaultFontPixelHeight * 0.8

                RowLayout {
                    Layout.fillWidth: true
                    QGCLabel {
                        text: qsTr("📶 Connect IRS PAWAN via Bluetooth")
                        font.bold: true
                        font.pointSize: ScreenTools.mediumFontPointSize * 1.05
                        color: root.cTextPrimary
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: ScreenTools.defaultFontPixelHeight * 1.8
                        height: width
                        radius: width / 2
                        color: closeBtMouse.containsMouse ? (root.isDarkTheme ? "#334155" : "#E2E8F0") : "transparent"
                        QGCLabel {
                            anchors.centerIn: parent
                            text: "✕"
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: root.cTextSecondary
                        }
                        MouseArea {
                            id: closeBtMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showBluetoothSheet = false
                        }
                    }
                }

                QGCLabel {
                    text: qsTr("Select your paired Skydroid T10 controller:")
                    font.pointSize: ScreenTools.smallFontPointSize * 0.85
                    color: root.cTextSecondary
                }

                // Preset Device: Skydroid T10
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.6
                    radius: ScreenTools.defaultFontPixelHeight * 0.6
                    color: t10Mouse.containsMouse ? (root.isDarkTheme ? "#1E2B45" : "#F1F5F9") : (root.isDarkTheme ? "#0F172A" : "#F8FAFC")
                    border.color: root.isDarkTheme ? "#2A374D" : "#CBD5E1"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.2
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel { text: "🎮"; font.pointSize: ScreenTools.largeFontPointSize }
                        ColumnLayout {
                            spacing: 1
                            QGCLabel { text: "Skydroid T10 Controller"; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize; color: root.cTextPrimary }
                            QGCLabel { text: "Bluetooth SPP • MAVLink 2 Encrypted"; font.pointSize: ScreenTools.smallFontPointSize * 0.75; color: "#10B981" }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                            radius: height / 2
                            color: "#23285D"
                            QGCLabel {
                                anchors.centerIn: parent
                                text: qsTr("Connect")
                                font.bold: true
                                font.pointSize: ScreenTools.smallFontPointSize * 0.8
                                color: "#F0DE2A"
                            }
                        }
                    }

                    MouseArea {
                        id: t10Mouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.showBluetoothSheet = false
                            root.openSettings()
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // PROTOCOL SHEET (FOR IRS VAYU / SIYI MK15 & G12)
    // ========================================================================
    Rectangle {
        id: protoModalOverlay
        anchors.fill: parent
        visible: root.showProtocolSheet
        z: 9998
        color: "#88000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.showProtocolSheet = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(root.width * 0.9, ScreenTools.defaultFontPixelWidth * 42)
            implicitHeight: protoDialogLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 2.2
            radius: ScreenTools.defaultFontPixelHeight * 1.0
            color: root.isDarkTheme ? "#161F30" : "#FFFFFF"
            border.color: root.isDarkTheme ? "#2A374D" : "#CBD5E1"
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: protoDialogLayout
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 1.1
                spacing: ScreenTools.defaultFontPixelHeight * 0.8

                RowLayout {
                    Layout.fillWidth: true
                    QGCLabel {
                        text: qsTr("📡 Connect IRS VAYU")
                        font.bold: true
                        font.pointSize: ScreenTools.mediumFontPointSize * 1.05
                        color: root.cTextPrimary
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: ScreenTools.defaultFontPixelHeight * 1.8
                        height: width
                        radius: width / 2
                        color: closeProtoMouse.containsMouse ? (root.isDarkTheme ? "#334155" : "#E2E8F0") : "transparent"
                        QGCLabel {
                            anchors.centerIn: parent
                            text: "✕"
                            font.bold: true
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: root.cTextSecondary
                        }
                        MouseArea {
                            id: closeProtoMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showProtocolSheet = false
                        }
                    }
                }

                // Option 1: SIYI MK15 UDP
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.4
                    radius: ScreenTools.defaultFontPixelHeight * 0.6
                    color: mk15Mouse.containsMouse ? (root.isDarkTheme ? "#1E2B45" : "#F1F5F9") : (root.isDarkTheme ? "#0F172A" : "#F8FAFC")
                    border.color: root.isDarkTheme ? "#2A374D" : "#CBD5E1"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.2
                        spacing: ScreenTools.defaultFontPixelWidth
                        QGCLabel { text: "📡"; font.pointSize: ScreenTools.largeFontPointSize }
                        ColumnLayout {
                            spacing: 1
                            QGCLabel { text: "SIYI MK15 / HM30 Dual Link"; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize; color: root.cTextPrimary }
                            QGCLabel { text: "UDP Port 14550 • Auto Listen"; font.pointSize: ScreenTools.smallFontPointSize * 0.75; color: "#38BDF8" }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
                            radius: height / 2
                            color: "#23285D"
                            QGCLabel {
                                anchors.centerIn: parent
                                text: qsTr("UDP")
                                font.bold: true
                                font.pointSize: ScreenTools.smallFontPointSize * 0.8
                                color: "#F0DE2A"
                            }
                        }
                    }
                    MouseArea {
                        id: mk15Mouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.showProtocolSheet = false
                            root.openSettings()
                        }
                    }
                }

                // Option 2: Skydroid G12 Serial
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.4
                    radius: ScreenTools.defaultFontPixelHeight * 0.6
                    color: g12Mouse.containsMouse ? (root.isDarkTheme ? "#1E2B45" : "#F1F5F9") : (root.isDarkTheme ? "#0F172A" : "#F8FAFC")
                    border.color: root.isDarkTheme ? "#2A374D" : "#CBD5E1"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.2
                        spacing: ScreenTools.defaultFontPixelWidth
                        QGCLabel { text: "🎮"; font.pointSize: ScreenTools.largeFontPointSize }
                        ColumnLayout {
                            spacing: 1
                            QGCLabel { text: "Skydroid G12 / Telemetry Radio"; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize; color: root.cTextPrimary }
                            QGCLabel { text: "USB Serial • Baud 57600"; font.pointSize: ScreenTools.smallFontPointSize * 0.75; color: "#F0DE2A" }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
                            radius: height / 2
                            color: "#23285D"
                            QGCLabel {
                                anchors.centerIn: parent
                                text: qsTr("Serial")
                                font.bold: true
                                font.pointSize: ScreenTools.smallFontPointSize * 0.8
                                color: "#F0DE2A"
                            }
                        }
                    }
                    MouseArea {
                        id: g12Mouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.showProtocolSheet = false
                            root.openSettings()
                        }
                    }
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

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: profileDialogLayout
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 1.1
                spacing: ScreenTools.defaultFontPixelHeight * 0.8

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
                            QGCLabel { text: qsTr("Encryption Key:"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextSecondary }
                            Item { Layout.fillWidth: true }
                            QGCLabel { text: qsTr("🟢 Nextkick Master (Active)"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: "#10B981" }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel { text: qsTr("License Status:"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextSecondary }
                            Item { Layout.fillWidth: true }
                            QGCLabel { text: qsTr("🟢 DGCA UAS Valid"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: "#10B981" }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel { text: qsTr("Station HWID:"); font.bold: true; font.pointSize: ScreenTools.smallFontPointSize * 0.85; color: root.cTextSecondary }
                            Item { Layout.fillWidth: true }
                            QGCLabel { text: "IRS-GCS-STATION-661007"; font.bold: false; font.pointSize: ScreenTools.smallFontPointSize * 0.8; color: root.cTextSecondary }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius: ScreenTools.defaultFontPixelHeight * 0.5
                    color: logoutMouse.containsMouse ? "#DC2626" : "#EF4444"

                    QGCLabel {
                        anchors.centerIn: parent
                        text: qsTr("🚪 Log Out")
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize * 0.95
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
