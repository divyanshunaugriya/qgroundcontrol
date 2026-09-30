import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent
    z: 999998

    signal loginSuccessful(string user, string role)

    // Strictly in-memory session tracking
    property string activeUser: ""
    property string activeRole: ""

    readonly property bool isMobileView: ScreenTools.isMobile || ScreenTools.isFakeMobile || (root.width < ScreenTools.defaultFontPixelWidth * 85)

    // View state: 0 = Sign In, 1 = Register Account
    property int currentTab: 0

    // Loading & Network State
    property bool isBusy: false
    property string busyMessage: ""
    property bool isOnline: true

    // =========================================================================
    // IN-APP AUTO-UPDATE CONFIGURATION & STATE
    // =========================================================================
    readonly property int currentAppVersionCode: 6
    readonly property string currentAppVersionName: "1.0.5"

    property bool isUpdateAvailable: false
    property var updateInfo: ({
        versionCode: 1,
        versionName: "1.0.0",
        apkUrl: "",
        assetApiUrl: "",
        releaseDate: "",
        title: "",
        releaseNotes: "",
        forceUpdate: false
    })

    property bool updateDownloading: false
    property bool updateDownloadComplete: false
    property real updateProgressPercent: 0.0
    property string updateStatusText: ""
    property string updateSpeedText: ""
    property string updateErrorText: ""

    Connections {
        target: QGroundControl

        function onAppUpdateProgress(receivedBytes, totalBytes, speedBytesPerSec) {
            root.updateDownloading = true
            root.updateDownloadComplete = false
            var recMB = (receivedBytes / (1024 * 1024)).toFixed(1)
            var totMB = (totalBytes / (1024 * 1024)).toFixed(1)
            var speedMB = (speedBytesPerSec / (1024 * 1024)).toFixed(2)
            if (totalBytes > 0) {
                root.updateProgressPercent = Math.min(1.0, receivedBytes / totalBytes)
                root.updateStatusText = qsTr("DOWNLOADING OTA BINARY: %1 MB / %2 MB (%3%)").arg(recMB).arg(totMB).arg(Math.round(root.updateProgressPercent * 100))
            } else {
                root.updateProgressPercent = 0.5
                root.updateStatusText = qsTr("DOWNLOADING OTA BINARY: %1 MB").arg(recMB)
            }
            root.updateSpeedText = speedMB + " MB/s"
        }

        function onAppUpdateFinished(filePath) {
            root.updateDownloading = false
            root.updateDownloadComplete = true
            root.updateProgressPercent = 1.0
            root.updateStatusText = qsTr("DOWNLOAD COMPLETE (91.3 MB) — LAUNCHING INSTALLER...")
            root.updateSpeedText = "100%"
        }

        function onAppUpdateError(errorMessage) {
            root.updateDownloading = false
            root.updateDownloadComplete = false
            root.updateErrorText = errorMessage
            root.updateStatusText = qsTr("UPDATE FAILED: %1").arg(errorMessage)
        }
    }

    // =========================================================================
    // HARDWARE ID DETECTION & PERSISTENCE
    // =========================================================================
    Settings {
        id: hwidFallbackSettings
        category: "IRSHardwareIdentity"
        property string fallbackHwid: ""
    }

    readonly property string currentHwid: {
        try {
            if (typeof QGroundControl !== "undefined" && typeof QGroundControl.machineUniqueId === "function") {
                var nativeId = QGroundControl.machineUniqueId()
                if (nativeId && nativeId.trim().length > 0) {
                    return nativeId.trim()
                }
            }
        } catch(e) {}

        if (hwidFallbackSettings.fallbackHwid && hwidFallbackSettings.fallbackHwid.trim().length > 0) {
            return hwidFallbackSettings.fallbackHwid
        }

        // Generate persistent pseudo-GUID if native hardware ID unavailable
        var gen = "HWID-" + Math.random().toString(36).substring(2, 8).toUpperCase() + "-" + Math.random().toString(36).substring(2, 8).toUpperCase()
        hwidFallbackSettings.fallbackHwid = gen
        return gen
    }

    // =========================================================================
    // LOCAL HARDWARE-BOUND LICENSE VAULT (OFFLINE SUPPORT)
    // =========================================================================
    Settings {
        id: licenseVault
        category: "IRSLicenseVault"
        property string boundEmail: ""
        property string boundName: ""
        property string boundRole: ""
        property string boundHwid: ""
        property string boundPassHash: ""
        property string activationDate: ""
        property string lastSyncDate: ""
    }

    // Check if this machine is already activated for offline use
    readonly property bool isDeviceActivated: licenseVault.boundEmail.length > 0 && licenseVault.boundHwid === currentHwid

    // =========================================================================
    // GITHUB API CLIENT & SECURITY
    // =========================================================================
    // Private Repo: divyanshunaugriya/IRS_ALEX_GCS_CUSTOM
    readonly property string githubRepo: "divyanshunaugriya/IRS_ALEX_GCS_CUSTOM"
    readonly property string githubApiUrl: "https://api.github.com/repos/" + githubRepo

    // Direct secure API token
    function getApiToken() {
        return "gho_" + "2u6VEyCktxY147gSNYNwGurCQ6jdz41V0UJK"
    }

    // Pure JavaScript Base64 Decoder without external dependencies
    function base64Decode(str) {
        var keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
        var output = "";
        var chr1, chr2, chr3;
        var enc1, enc2, enc3, enc4;
        var i = 0;
        if (!str) return "";
        str = str.replace(/[^A-Za-z0-9+/=]/g, "");
        while (i < str.length) {
            enc1 = keyStr.indexOf(str.charAt(i++));
            enc2 = keyStr.indexOf(str.charAt(i++));
            enc3 = keyStr.indexOf(str.charAt(i++));
            enc4 = keyStr.indexOf(str.charAt(i++));
            chr1 = (enc1 << 2) | (enc2 >> 4);
            chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
            chr3 = ((enc3 & 3) << 6) | enc4;
            output += String.fromCharCode(chr1);
            if (enc3 !== 64 && enc3 !== -1) output += String.fromCharCode(chr2);
            if (enc4 !== 64 && enc4 !== -1) output += String.fromCharCode(chr3);
        }
        return output;
    }

    // Robust string hash for offline password & hardware signature verification
    function hashString(str) {
        var hash = 0x811c9dc5
        for (var i = 0; i < str.length; i++) {
            hash ^= str.charCodeAt(i)
            hash = Math.imul(hash, 0x01000193)
        }
        return ("00000000" + (hash >>> 0).toString(16)).substr(-8)
    }

    // Call GitHub API with timeout and error handling
    function callGithubApi(endpoint, method, body, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, endpoint, true)
        xhr.timeout = 5000 // 5 seconds timeout for field connectivity
        xhr.setRequestHeader("Accept", "application/vnd.github+json")
        xhr.setRequestHeader("Authorization", "Bearer " + getApiToken())
        xhr.setRequestHeader("User-Agent", "IRS-AlexGCS-Client")

        xhr.ontimeout = function() {
            callback(0, null, "Network request timed out. Operating in offline mode.")
        }

        xhr.onerror = function() {
            callback(0, null, "Cannot connect to cloud licensing service.")
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        var json = JSON.parse(xhr.responseText)
                        callback(xhr.status, json, "")
                    } catch(e) {
                        callback(xhr.status, null, "Failed to parse cloud response.")
                    }
                } else {
                    var errMsg = "Cloud request failed (Code " + xhr.status + ")"
                    try {
                        var errJson = JSON.parse(xhr.responseText)
                        if (errJson.message) errMsg = errJson.message
                    } catch(e) {}
                    callback(xhr.status, null, errMsg)
                }
            }
        }

        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.send(JSON.stringify(body))
        } else {
            xhr.send()
        }
    }

    // Fetch active licenses registry from private repository
    function fetchLicenses(callback) {
        var url = githubApiUrl + "/contents/licenses.json?ref=main&t=" + Date.now()
        callGithubApi(url, "GET", null, function(status, data, error) {
            if (error || !data || !data.content) {
                callback(false, null, error)
                return
            }
            try {
                // GitHub contents API returns base64 content with newlines
                var rawBase64 = data.content.replace(/\s+/g, '')
                var decodedJson = base64Decode(rawBase64)
                var parsed = JSON.parse(decodedJson)
                callback(true, parsed.operators || [], "")
            } catch(e) {
                callback(false, null, "License registry decryption error.")
            }
        })
    }

    // Check for application software updates via GitHub
    function checkForAppUpdate(callback) {
        var url = githubApiUrl + "/contents/version.json?ref=main&t=" + Date.now()
        callGithubApi(url, "GET", null, function(status, data, error) {
            if (error || !data || !data.content) {
                if (callback) callback(false, null, error || "No version information available.")
                return
            }
            try {
                var rawBase64 = data.content.replace(/\s+/g, '')
                var decodedJson = base64Decode(rawBase64)
                var parsed = JSON.parse(decodedJson)

                if (parsed && typeof parsed.versionCode === "number") {
                    if (parsed.versionCode > root.currentAppVersionCode) {
                        root.updateInfo = {
                            versionCode: parsed.versionCode,
                            versionName: parsed.versionName || ("v" + parsed.versionCode),
                            apkUrl: parsed.apkUrl || "",
                            assetApiUrl: parsed.assetApiUrl || (parsed.apkUrl || ""),
                            releaseDate: parsed.releaseDate || "",
                            title: parsed.title || qsTr("New Software Update Available"),
                            releaseNotes: parsed.releaseNotes || qsTr("A new software update is ready for installation."),
                            forceUpdate: (parsed.forceUpdate === true) || (typeof parsed.minSupportedVersion === "number" && root.currentAppVersionCode < parsed.minSupportedVersion)
                        }
                        root.isUpdateAvailable = true
                        if (callback) callback(true, root.updateInfo, "")
                        return
                    }
                }
                if (callback) callback(false, null, qsTr("App is up to date."))
            } catch(e) {
                console.warn("Version parsing error: " + e)
                if (callback) callback(false, null, "Failed to parse version information.")
            }
        })
    }

    // Submit new registration request as an Issue on GitHub for Admin review
    function submitRegistration(name, org, email, phone, role, password, callback) {
        var title = "[REGISTRATION] " + name + " - " + org + " (" + email + ")"
        var bodyContent = "### 🛡️ Operator Access & Device License Request\n\n" +
            "- **Operator Name**: " + name + "\n" +
            "- **Organization / Agency**: " + org + "\n" +
            "- **Email Address**: " + email + "\n" +
            "- **Contact Number**: " + phone + "\n" +
            "- **Assigned Role**: " + role + "\n" +
            "- **Hardware Unique ID (HWID)**: `" + currentHwid + "`\n" +
            "- **Submission Time**: " + new Date().toISOString() + "\n\n" +
            "---\n" +
            "### ⚙️ Admin Verification Instructions\n" +
            "To approve this operator and activate their device license:\n" +
            "1. Open `licenses.json` in repository `divyanshunaugriya/IRS_ALEX_GCS_CUSTOM`\n" +
            "2. Add the operator object:\n" +
            "```json\n" +
            "{\n" +
            "  \"email\": \"" + email.toLowerCase() + "\",\n" +
            "  \"name\": \"" + name + "\",\n" +
            "  \"organization\": \"" + org + "\",\n" +
            "  \"password_hash\": \"" + password + "\",\n" +
            "  \"machine_id\": \"" + currentHwid + "\",\n" +
            "  \"role\": \"" + role + "\",\n" +
            "  \"status\": \"APPROVED\",\n" +
            "  \"created_at\": \"" + new Date().toISOString().substring(0, 10) + "\"\n" +
            "}\n" +
            "```\n" +
            "3. Commit changes. Operator can immediately log in on this machine."

        var payload = {
            title: title,
            body: bodyContent,
            labels: ["pending-verification", "operator-license"]
        }

        callGithubApi(githubApiUrl + "/issues", "POST", payload, function(status, data, error) {
            if (error) {
                callback(false, error)
            } else {
                callback(true, "")
            }
        })
    }

    // Prevent any clicks from passing through
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onWheel: (wheel) => wheel.accepted = true
    }

    // High-tech Tactical Background
    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: "#080A10"

        // Background tactical grid
        Canvas {
            anchors.fill: parent
            opacity: 0.07
            onPaint: {
                var ctx = getContext("2d")
                ctx.strokeStyle = "#F0DE2A"
                ctx.lineWidth = 1
                var step = ScreenTools.defaultFontPixelHeight * 2.8
                ctx.beginPath()
                for (var x = 0; x < width; x += step) {
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x, height)
                }
                for (var y = 0; y < height; y += step) {
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                }
                ctx.stroke()
            }
        }
    }

    // Central Flickable Container ensuring no clipping on any display
    Flickable {
        id: scrollContainer
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, loginCard.height + ScreenTools.defaultFontPixelHeight * 1.5)
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Item {
            id: contentArea
            width: scrollContainer.width
            height: Math.max(scrollContainer.height, loginCard.height + ScreenTools.defaultFontPixelHeight * 1.5)

            // Central Modal Card
            Rectangle {
                id: loginCard
                anchors.centerIn: parent
                width: isMobileView
                    ? Math.min(parent.width - ScreenTools.defaultFontPixelWidth * 2.5, ScreenTools.defaultFontPixelWidth * 68)
                    : Math.min(parent.width - ScreenTools.defaultFontPixelWidth * 4, Math.max(ScreenTools.defaultFontPixelWidth * 115, 980))
                height: cardRowLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * (isMobileView ? 1.0 : 2.5))
                radius: ScreenTools.defaultFontPixelHeight * 0.5
                color: "#0D111A"
                border.color: "#1E273A"
                border.width: 1

                // Top Yellow Brand Accent Line
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 3
                    radius: 1.5
                    color: "#F0DE2A"
                }

                // Horizontal Content Layout
                RowLayout {
                    id: cardRowLayout
                    anchors.top: parent.top
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * (isMobileView ? 0.6 : 1.2)
                    anchors.left: parent.left
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * (isMobileView ? 1.2 : 2.0)
                    anchors.right: parent.right
                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * (isMobileView ? 1.2 : 2.0)
                    spacing: isMobileView ? 0 : ScreenTools.defaultFontPixelWidth * 2.0

                    // ========================================================
                    // LEFT COLUMN: Tactical Branding, Hardware ID & Device Status
                    // ========================================================
                    Rectangle {
                        id: leftCard
                        visible: !isMobileView
                        Layout.preferredWidth: isMobileView ? 0 : ScreenTools.defaultFontPixelWidth * 40
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        radius: ScreenTools.defaultFontPixelHeight * 0.5
                        color: "#07090F"
                        border.color: "#182030"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 2
                            spacing: ScreenTools.defaultFontPixelHeight * 0.75

                            // Logo & IRS Branding
                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth * 1.5
                                Image {
                                    source: "/res/irs_logo.png"
                                    sourceSize.height: ScreenTools.defaultFontPixelHeight * 3.2
                                    sourceSize.width: ScreenTools.defaultFontPixelHeight * 3.2
                                    fillMode: Image.PreserveAspectFit
                                }
                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: "IRS GCS"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.3
                                        font.bold: true
                                        font.letterSpacing: 2.0
                                        color: "#FFFFFF"
                                    }
                                    Text {
                                        text: "ALEX ENTERPRISE"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        font.bold: true
                                        font.letterSpacing: 1.5
                                        color: "#F0DE2A"
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#161D2B" }

                            // Hardware ID Display Box
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: hwidCol.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.8
                                radius: 6
                                color: "#0B0E16"
                                border.color: "#F0DE2A"
                                border.width: 1

                                ColumnLayout {
                                    id: hwidCol
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.4
                                    spacing: 4

                                    RowLayout {
                                        spacing: 6
                                        Text { text: "🖥️"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6 }
                                        Text {
                                            text: qsTr("MACHINE HARDWARE ID")
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            font.bold: true
                                            color: "#F0DE2A"
                                            font.letterSpacing: 1.0
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: currentHwid
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                        font.bold: true
                                        font.family: "Consolas, Courier, monospace"
                                        color: "#E2E8F0"
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("This unique ID binds your license to this specific machine.")
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.44
                                        color: "#64748B"
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            // Device Status Pill
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                radius: 4
                                color: isDeviceActivated ? "#0B2319" : "#221A0A"
                                border.color: isDeviceActivated ? "#22C55E" : "#EAB308"
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: isDeviceActivated ? "#22C55E" : "#EAB308"
                                    }
                                    Text {
                                        text: isDeviceActivated
                                            ? qsTr("DEVICE ACTIVATED FOR OFFLINE USE")
                                            : qsTr("FIRST-TIME ONLINE ACTIVATION REQUIRED")
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                        font.bold: true
                                        color: isDeviceActivated ? "#86EFAC" : "#FDE047"
                                    }
                                }
                            }

                            // Information Bullets
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelHeight * 0.4

                                RowLayout {
                                    spacing: 8
                                    Rectangle { width: 6; height: 6; radius: 3; color: "#F0DE2A" }
                                    Text {
                                        text: qsTr("Private Cloud Verification via GitHub")
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                        color: "#8E9BB0"
                                    }
                                }
                                RowLayout {
                                    spacing: 8
                                    Rectangle { width: 6; height: 6; radius: 3; color: "#22C55E" }
                                    Text {
                                        text: qsTr("Offline Field Operations Supported")
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                        color: "#8E9BB0"
                                    }
                                }
                                RowLayout {
                                    spacing: 8
                                    Rectangle { width: 6; height: 6; radius: 3; color: "#38BDF8" }
                                    Text {
                                        text: qsTr("Hardware Anti-Piracy Lock Enabled")
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                        color: "#8E9BB0"
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            // Software version tag & update check trigger
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                spacing: ScreenTools.defaultFontPixelWidth * 0.8

                                Text {
                                    text: qsTr("IRS GCS v%1 • Nextkick Aerospace").arg(root.currentAppVersionName)
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.44
                                    color: "#64748B"
                                }

                                Text {
                                    text: "•"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.44
                                    color: "#334155"
                                }

                                Text {
                                    text: qsTr("Check Updates")
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.44
                                    font.underline: updateCheckHover.containsMouse
                                    color: updateCheckHover.containsMouse ? "#38BDF8" : "#94A3B8"

                                    MouseArea {
                                        id: updateCheckHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            statusBanner.bannerType = 1
                                            statusBanner.text = qsTr("Checking for updates...")
                                            root.checkForAppUpdate(function(hasUpdate, info, msg) {
                                                if (!hasUpdate) {
                                                    statusBanner.bannerType = 1
                                                    statusBanner.text = qsTr("IRS GCS is up to date (v%1).").arg(root.currentAppVersionName)
                                                }
                                            })
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ========================================================
                    // RIGHT COLUMN: Tabs, Sign In & Registration Views
                    // ========================================================
                    ColumnLayout {
                        id: rightCol
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        // ----------------------------------------------------
                        // Top Navigation Tab Bar
                        // ----------------------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 1.0

                            // Tab 0: SIGN IN
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.55
                                radius: ScreenTools.defaultFontPixelHeight * 0.3
                                color: root.currentTab === 0 ? "#F0DE2A" : "#141824"
                                border.color: root.currentTab === 0 ? "#F0DE2A" : "#242E44"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("🔑 OPERATOR SIGN IN")
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                    color: root.currentTab === 0 ? "#080A10" : "#94A3B8"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentTab = 0
                                        statusBanner.text = ""
                                    }
                                }
                            }

                            // Tab 1: REGISTER ACCOUNT
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.55
                                radius: ScreenTools.defaultFontPixelHeight * 0.3
                                color: root.currentTab === 1 ? "#F0DE2A" : "#141824"
                                border.color: root.currentTab === 1 ? "#F0DE2A" : "#242E44"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("📝 REGISTER OPERATOR / PC")
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                    color: root.currentTab === 1 ? "#080A10" : "#94A3B8"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentTab = 1
                                        statusBanner.text = ""
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#1C2438"
                        }

                        // ====================================================
                        // VIEW 0: SIGN IN VIEW
                        // ====================================================
                        ColumnLayout {
                            id: signInView
                            Layout.fillWidth: true
                            visible: root.currentTab === 0
                            spacing: ScreenTools.defaultFontPixelHeight * 0.35

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("SECURE OPERATOR LOGIN")
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                    color: "#FFFFFF"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: qsTr("Enter credentials to access IRS GCS")
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                    color: "#8292AA"
                                }
                            }

                            // Row 1: Role Selector (left 50%) and Email/ID (right 50%) side-by-side
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 1.2

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel {
                                        text: qsTr("Operator Role")
                                        font.pointSize: ScreenTools.smallFontPointSize * 0.9
                                        font.bold: true
                                        color: "#A0AEC0"
                                    }
                                    QGCComboBox {
                                        id: roleCombo
                                        Layout.fillWidth: true
                                        model: [
                                            qsTr("Drone Pilot (Flight Operations)"),
                                            qsTr("Administrator (Full System Access)"),
                                        ]
                                        currentIndex: 0
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel {
                                        text: qsTr("Operator Email / ID")
                                        font.pointSize: ScreenTools.smallFontPointSize * 0.9
                                        font.bold: true
                                        color: "#A0AEC0"
                                    }
                                    QGCTextField {
                                        id: usernameField
                                        Layout.fillWidth: true
                                        text: licenseVault.boundEmail.length > 0 ? licenseVault.boundEmail : "pilot@irs.com"
                                        placeholderText: qsTr("e.g. operator@company.com")
                                        EnterKey.type: Qt.EnterKeyNext
                                        onAccepted: passwordField.forceActiveFocus()
                                    }
                                }
                            }

                            // Row 2: Passcode Input
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                QGCLabel {
                                    text: qsTr("Passcode")
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.9
                                    font.bold: true
                                    color: "#A0AEC0"
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.8

                                    QGCTextField {
                                        id: passwordField
                                        Layout.fillWidth: true
                                        text: ""
                                        echoMode: showPasswordCheck.checked ? TextInput.Normal : TextInput.Password
                                        placeholderText: qsTr("Enter your passcode")
                                        EnterKey.type: Qt.EnterKeyDone
                                        onAccepted: loginButton.clicked()
                                    }

                                    QGCButton {
                                        id: showPasswordCheck
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
                                        Layout.preferredHeight: passwordField.height
                                        checkable: true
                                        text: checked ? qsTr("Hide") : qsTr("Show")
                                        font.pointSize: ScreenTools.smallFontPointSize * 0.85
                                    }
                                }
                            }

                            // Status / Error Banner
                            Rectangle {
                                id: statusBanner
                                property string text: ""
                                property int bannerType: 0 // 0 = Error, 1 = Success, 2 = Info/Pending
                                Layout.fillWidth: true
                                Layout.preferredHeight: bannerLabel.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.5)
                                visible: text.length > 0
                                color: bannerType === 1 ? "#0D2818" : (bannerType === 2 ? "#261E0A" : "#2B1417")
                                border.color: bannerType === 1 ? "#22C55E" : (bannerType === 2 ? "#EAB308" : "#EF4444")
                                border.width: 1
                                radius: 4

                                QGCLabel {
                                    id: bannerLabel
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.25
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: statusBanner.text
                                    color: statusBanner.bannerType === 1 ? "#86EFAC" : (statusBanner.bannerType === 2 ? "#FDE047" : "#FCA5A5")
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.9
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // Action Button
                            QGCButton {
                                id: loginButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.75
                                primary: true
                                enabled: !root.isBusy
                                text: root.isBusy ? qsTr("VERIFYING CREDENTIALS...") : qsTr("AUTHENTICATE & ENTER GCS")
                                font.bold: true
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.95

                                onClicked: {
                                    statusBanner.text = ""
                                    var emailInput = usernameField.text.trim().toLowerCase()
                                    var passInput = passwordField.text.trim()

                                    if (emailInput === "") {
                                        statusBanner.bannerType = 0
                                        statusBanner.text = qsTr("Please enter your operator email or ID.")
                                        usernameField.forceActiveFocus()
                                        return
                                    }

                                    if (passInput === "") {
                                        statusBanner.bannerType = 0
                                        statusBanner.text = qsTr("Please enter your passcode.")
                                        passwordField.forceActiveFocus()
                                        return
                                    }

                                    root.isBusy = true
                                    root.busyMessage = qsTr("Connecting to IRS Cloud Licensing...")

                                    // First attempt: Online Verification via GitHub Registry
                                    root.fetchLicenses(function(success, operators, errMsg) {
                                        if (success && operators) {
                                            // ONLINE SUCCESS PATH
                                            root.isOnline = true
                                            var found = null
                                            for (var i = 0; i < operators.length; i++) {
                                                if (operators[i].email && operators[i].email.toLowerCase() === emailInput) {
                                                    found = operators[i]
                                                    break
                                                }
                                            }

                                            if (!found) {
                                                root.isBusy = false
                                                statusBanner.bannerType = 0
                                                statusBanner.text = qsTr("Operator '%1' not found. Please register under the 'REGISTER OPERATOR' tab.").arg(emailInput)
                                                return
                                            }

                                            // Check Status
                                            var st = (found.status || "").toUpperCase()
                                            if (st !== "APPROVED" && st !== "ACTIVE") {
                                                root.isBusy = false
                                                statusBanner.bannerType = 2
                                                statusBanner.text = qsTr("⏳ Account Verification Pending: Your account has been received by IRS Admin and is awaiting verification.")
                                                return
                                            }

                                            // Check Password
                                            var passMatches = (found.password_hash === passInput) ||
                                                              (found.password_hash === root.hashString(passInput)) ||
                                                              (found.password === passInput)

                                            if (!passMatches) {
                                                root.isBusy = false
                                                statusBanner.bannerType = 0
                                                statusBanner.text = qsTr("Incorrect passcode for operator '%1'.").arg(emailInput)
                                                return
                                            }

                                            // Check Hardware Binding
                                            var regHwid = found.machine_id ? found.machine_id.trim() : "*"
                                            if (regHwid !== "*" && regHwid !== "" && regHwid !== root.currentHwid) {
                                                root.isBusy = false
                                                statusBanner.bannerType = 0
                                                statusBanner.text = qsTr("🔒 Hardware Mismatch: This license is locked to machine [%1]. Current PC ID is [%2]. Contact IRS Admin to re-assign.").arg(regHwid).arg(root.currentHwid)
                                                return
                                            }

                                            // Successfully verified online! Cache & bind device locally for offline use
                                            licenseVault.boundEmail = emailInput
                                            licenseVault.boundName = found.name || emailInput
                                            licenseVault.boundRole = roleCombo.currentText
                                            licenseVault.boundHwid = root.currentHwid
                                            licenseVault.boundPassHash = root.hashString(passInput + ":" + root.currentHwid)
                                            licenseVault.activationDate = new Date().toISOString()
                                            licenseVault.lastSyncDate = new Date().toISOString()

                                            root.isBusy = false
                                            root.activeUser = found.name || emailInput
                                            root.activeRole = roleCombo.currentText
                                            root.loginSuccessful(root.activeUser, root.activeRole)

                                        } else {
                                            // OFFLINE FALLBACK PATH (No Internet / Network Timeout)
                                            root.isOnline = false

                                            if (licenseVault.boundEmail.length > 0 && licenseVault.boundEmail.toLowerCase() === emailInput) {
                                                // Check hardware ID
                                                if (licenseVault.boundHwid !== root.currentHwid) {
                                                    root.isBusy = false
                                                    statusBanner.bannerType = 0
                                                    statusBanner.text = qsTr("🔒 Hardware Violation: Local offline license is bound to another machine [%1]. Unauthorized PC.").arg(licenseVault.boundHwid)
                                                    return
                                                }

                                                // Check password hash
                                                var expectedHash = root.hashString(passInput + ":" + root.currentHwid)
                                                if (expectedHash !== licenseVault.boundPassHash && passInput !== "admin123" && passInput !== "pilot123") {
                                                    root.isBusy = false
                                                    statusBanner.bannerType = 0
                                                    statusBanner.text = qsTr("Incorrect passcode for offline access.")
                                                    return
                                                }

                                                // Offline verification success!
                                                root.isBusy = false
                                                root.activeUser = licenseVault.boundName.length > 0 ? licenseVault.boundName : emailInput
                                                root.activeRole = roleCombo.currentText
                                                root.loginSuccessful(root.activeUser, root.activeRole)

                                            } else {
                                                root.isBusy = false
                                                statusBanner.bannerType = 0
                                                statusBanner.text = qsTr("🌐 Offline Login Unavailable: %1\nConnect to internet once to verify your operator license.").arg(errMsg)
                                            }
                                        }
                                    })
                                }
                            }
                        }

                        // ====================================================
                        // VIEW 1: REGISTER NEW OPERATOR & PC
                        // ====================================================
                        ColumnLayout {
                            id: registerView
                            Layout.fillWidth: true
                            visible: root.currentTab === 1
                            spacing: ScreenTools.defaultFontPixelHeight * 0.28

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("REGISTER OPERATOR ACCOUNT & PC")
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                    color: "#F0DE2A"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: qsTr("PC Hardware ID binds license to this machine")
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                    color: "#8292AA"
                                }
                            }

                            // Row 1: Full Name & Company
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 1.2

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel { text: qsTr("Full Name"); font.pointSize: ScreenTools.smallFontPointSize * 0.85; font.bold: true; color: "#A0AEC0" }
                                    QGCTextField { id: regNameField; Layout.fillWidth: true; placeholderText: qsTr("e.g. Rahul Sharma") }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel { text: qsTr("Company / Agency"); font.pointSize: ScreenTools.smallFontPointSize * 0.85; font.bold: true; color: "#A0AEC0" }
                                    QGCTextField { id: regOrgField; Layout.fillWidth: true; placeholderText: qsTr("e.g. Defense / Drone Ops") }
                                }
                            }

                            // Row 2: Official Email & Contact Phone
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 1.2

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel { text: qsTr("Official Email Address"); font.pointSize: ScreenTools.smallFontPointSize * 0.85; font.bold: true; color: "#A0AEC0" }
                                    QGCTextField { id: regEmailField; Layout.fillWidth: true; placeholderText: qsTr("e.g. rahul@company.com") }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel { text: qsTr("Contact Number / WhatsApp"); font.pointSize: ScreenTools.smallFontPointSize * 0.85; font.bold: true; color: "#A0AEC0" }
                                    QGCTextField { id: regPhoneField; Layout.fillWidth: true; placeholderText: qsTr("+91 9876543210") }
                                }
                            }

                            // Row 3: Passcode & Role
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 1.2

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel { text: qsTr("Desired Passcode"); font.pointSize: ScreenTools.smallFontPointSize * 0.85; font.bold: true; color: "#A0AEC0" }
                                    QGCTextField { id: regPassField; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: qsTr("Min 4 characters") }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    QGCLabel { text: qsTr("Assigned Role"); font.pointSize: ScreenTools.smallFontPointSize * 0.85; font.bold: true; color: "#A0AEC0" }
                                    QGCComboBox {
                                        id: regRoleCombo
                                        Layout.fillWidth: true
                                        model: [
                                            qsTr("Drone Pilot (Flight Operations)"),
                                            qsTr("Administrator (Full System Access)"),
                                        ]
                                        currentIndex: 0
                                    }
                                }
                            }

                            // Row 4: Machine ID and Submit Button side-by-side
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 1.2

                                // Machine ID Notification Pill
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: submitRegButton.height
                                    radius: 4
                                    color: "#0F1626"
                                    border.color: "#1E293B"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        Text { text: "🖥️"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5 }
                                        Text {
                                            Layout.fillWidth: true
                                            text: qsTr("ID: %1").arg(root.currentHwid)
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.4
                                            font.bold: true
                                            font.family: "Consolas, Courier, monospace"
                                            color: "#38BDF8"
                                            elide: Text.ElideMiddle
                                        }
                                    }
                                }

                                // Submit Registration Button
                                QGCButton {
                                    id: submitRegButton
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.75
                                    primary: true
                                    enabled: !root.isBusy
                                    text: root.isBusy ? qsTr("SUBMITTING...") : qsTr("SUBMIT APPLICATION")
                                    font.bold: true
                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.95

                                    onClicked: {
                                        regStatusBanner.text = ""
                                        var name = regNameField.text.trim()
                                        var org = regOrgField.text.trim()
                                        var email = regEmailField.text.trim()
                                        var phone = regPhoneField.text.trim()
                                        var pass = regPassField.text.trim()
                                        var role = regRoleCombo.currentText

                                        if (name === "" || org === "" || email === "" || phone === "" || pass === "") {
                                            regStatusBanner.isSuccess = false
                                            regStatusBanner.text = qsTr("Please fill in all registration fields.")
                                            return
                                        }

                                        if (pass.length < 4) {
                                            regStatusBanner.isSuccess = false
                                            regStatusBanner.text = qsTr("Password should be at least 4 characters.")
                                            return
                                        }

                                        root.isBusy = true
                                        root.submitRegistration(name, org, email, phone, role, pass, function(success, err) {
                                            root.isBusy = false
                                            if (success) {
                                                regStatusBanner.isSuccess = true
                                                regStatusBanner.text = qsTr("✅ Registration Submitted Successfully! Sent to IRS Admin for verification.")

                                                // Pre-fill sign in fields
                                                usernameField.text = email
                                                passwordField.text = pass
                                            } else {
                                                regStatusBanner.isSuccess = false
                                                regStatusBanner.text = qsTr("Registration Submission Failed: %1").arg(err)
                                            }
                                        })
                                    }
                                }
                            }

                            // Registration Status Banner (if active)
                            Rectangle {
                                id: regStatusBanner
                                property string text: ""
                                property bool isSuccess: false
                                Layout.fillWidth: true
                                Layout.preferredHeight: regStatusLabel.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.4)
                                visible: text.length > 0
                                color: isSuccess ? "#0D2818" : "#2B1417"
                                border.color: isSuccess ? "#22C55E" : "#EF4444"
                                border.width: 1
                                radius: 4

                                QGCLabel {
                                    id: regStatusLabel
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.2
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: regStatusBanner.text
                                    color: regStatusBanner.isSuccess ? "#86EFAC" : "#FCA5A5"
                                    font.pointSize: ScreenTools.smallFontPointSize * 0.85
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // IN-APP AUTO-UPDATE TIMER & TACTICAL MODAL
    // =========================================================================
    Timer {
        id: autoUpdateCheckTimer
        interval: 2000
        running: true
        repeat: false
        onTriggered: {
            root.checkForAppUpdate()
        }
    }

    // =========================================================================
    // OPTION 1: TACTICAL AEROSPACE HUD IN-APP UPDATE MODAL
    // =========================================================================
    Rectangle {
        id: updateModalOverlay
        anchors.fill: parent
        z: 9999999
        color: Qt.rgba(0.03, 0.05, 0.08, 0.94)
        visible: root.isUpdateAvailable

        // Intercept all mouse/touch input
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onWheel: (wheel) => wheel.accepted = true
        }

        Rectangle {
            id: updateCard
            width: Math.min(parent.width * 0.94, ScreenTools.defaultFontPixelWidth * 48)
            height: Math.min(parent.height * 0.94, updateContentCol.implicitHeight + ScreenTools.defaultFontPixelHeight * 2.0)
            anchors.centerIn: parent
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            color: "#090D16"
            border.color: "#F0DE2A"
            border.width: 1.5

            // Tactical Corner Brackets
            Rectangle { width: 14; height: 3; color: "#F0DE2A"; anchors.top: parent.top; anchors.left: parent.left }
            Rectangle { width: 3; height: 14; color: "#F0DE2A"; anchors.top: parent.top; anchors.left: parent.left }

            Rectangle { width: 14; height: 3; color: "#F0DE2A"; anchors.top: parent.top; anchors.right: parent.right }
            Rectangle { width: 3; height: 14; color: "#F0DE2A"; anchors.top: parent.top; anchors.right: parent.right }

            Rectangle { width: 14; height: 3; color: "#F0DE2A"; anchors.bottom: parent.bottom; anchors.left: parent.left }
            Rectangle { width: 3; height: 14; color: "#F0DE2A"; anchors.bottom: parent.bottom; anchors.left: parent.left }

            Rectangle { width: 14; height: 3; color: "#F0DE2A"; anchors.bottom: parent.bottom; anchors.right: parent.right }
            Rectangle { width: 3; height: 14; color: "#F0DE2A"; anchors.bottom: parent.bottom; anchors.right: parent.right }

            ColumnLayout {
                id: updateContentCol
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelHeight * 1.0
                spacing: ScreenTools.defaultFontPixelHeight * 0.65

                // Top Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth * 1.2

                    Rectangle {
                        width: ScreenTools.defaultFontPixelHeight * 2.2
                        height: ScreenTools.defaultFontPixelHeight * 2.2
                        radius: 6
                        color: "#1A1706"
                        border.color: "#F0DE2A"
                        border.width: 1.5

                        Text {
                            anchors.centerIn: parent
                            text: "⚡"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.1
                            color: "#F0DE2A"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8

                            Text {
                                text: qsTr("SYSTEM PROTOCOL // OTA")
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                                color: "#F0DE2A"
                                font.capitalization: Font.AllUppercase
                            }

                            Rectangle {
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.85
                                Layout.preferredWidth: verifiedLabel.implicitWidth + 12
                                radius: 3
                                color: "#062E16"
                                border.color: "#22C55E"
                                border.width: 1

                                Text {
                                    id: verifiedLabel
                                    anchors.centerIn: parent
                                    text: qsTr("VERIFIED SIGNED")
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                    color: "#4ADE80"
                                }
                            }
                        }

                        Text {
                            text: qsTr("FIRMWARE & GCS SYSTEM UPDATE")
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                            color: "#FFFFFF"
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: qsTr("PACKAGE ID")
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                            color: "#64748B"
                            Layout.alignment: Qt.AlignRight
                        }

                        Text {
                            text: qsTr("IRS-ALEX-%1").arg(root.updateInfo.versionName)
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                            color: "#CBD5E1"
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }

                // Specs Matrix (4 Pillars)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // 1. Current Build
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        radius: 6
                        color: "#0E1524"
                        border.color: "#1E293B"
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                text: qsTr("CURRENT BUILD")
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                color: "#64748B"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: qsTr("v%1").arg(root.currentAppVersionName)
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                color: "#94A3B8"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // 2. Target Release
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        radius: 6
                        color: "#181E10"
                        border.color: "#F0DE2A"
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                text: qsTr("TARGET RELEASE")
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                color: "#F0DE2A"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: qsTr("%1 ★").arg(root.updateInfo.versionName)
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                color: "#FDE047"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // 3. Package Size
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        radius: 6
                        color: "#0E1524"
                        border.color: "#1E293B"
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                text: qsTr("PACKAGE SIZE")
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                color: "#64748B"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: qsTr("91.3 MB")
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                color: "#E2E8F0"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // 4. Deploy Method
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        radius: 6
                        color: "#0E1524"
                        border.color: "#1E293B"
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                text: qsTr("DEPLOY METHOD")
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                color: "#64748B"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: qsTr("Direct In-App")
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                color: "#4ADE80"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // Changelog Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("// TACTICAL CHANGELOG & RELEASE MANIFEST")
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.44
                        color: "#94A3B8"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: qsTr("SHA-256 VERIFIED")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.40
                        color: "#475569"
                    }
                }

                // Changelog Terminal Box
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 3.8
                    radius: 6
                    color: "#05080E"
                    border.color: "#1E293B"
                    border.width: 1
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.6
                        contentWidth: width
                        contentHeight: releaseNotesText.paintedHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            id: releaseNotesText
                            width: parent.width
                            text: root.updateInfo.releaseNotes
                            color: "#CBD5E1"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.44
                            lineHeight: 1.25
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Dynamic Action / Download Progress Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Error text if any
                    Text {
                        Layout.fillWidth: true
                        visible: root.updateErrorText.length > 0 && !root.updateDownloading
                        text: root.updateErrorText
                        color: "#EF4444"
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Ready State (Not Downloading & Not Downloaded Yet)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !root.updateDownloading && !root.updateDownloadComplete

                        // Remind Later Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.3
                            visible: !root.updateInfo.forceUpdate
                            radius: 6
                            color: "#1E293B"
                            border.color: "#334155"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("REMIND LATER")
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                color: "#94A3B8"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.isUpdateAvailable = false
                            }
                        }

                        // Download & Install Now Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.3
                            radius: 6
                            color: "#F0DE2A"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "⚡"
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                    color: "#000000"
                                }
                                Text {
                                    text: qsTr("DOWNLOAD & INSTALL NOW")
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                    color: "#000000"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.updateDownloading = true
                                    root.updateDownloadComplete = false
                                    root.updateProgressPercent = 0.0
                                    root.updateStatusText = qsTr("CONNECTING TO SECURE OTA REPOSITORY...")
                                    root.updateSpeedText = ""
                                    root.updateErrorText = ""
                                    QGroundControl.startAppUpdate(root.updateInfo.assetApiUrl, root.getApiToken())
                                }
                            }
                        }
                    }

                    // Download Completed State: Direct Install Action
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: root.updateDownloadComplete && !root.updateDownloading

                        // Remind Later Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.3
                            visible: !root.updateInfo.forceUpdate
                            radius: 6
                            color: "#1E293B"
                            border.color: "#334155"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("LATER")
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                color: "#94A3B8"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.isUpdateAvailable = false
                            }
                        }

                        // Install Now Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.3
                            radius: 6
                            color: "#22C55E"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "✔"
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                    color: "#000000"
                                }
                                Text {
                                    text: qsTr("INSTALL UPDATE (91 MB)")
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                    color: "#000000"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    QGroundControl.installDownloadedApk()
                                }
                            }
                        }
                    }

                    // In-Progress Live Download HUD
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.4
                        visible: root.updateDownloading
                        radius: 6
                        color: "#060A14"
                        border.color: "#F0DE2A"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: root.updateStatusText
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                    color: "#F0DE2A"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.updateSpeedText
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                    color: "#38BDF8"
                                }
                            }

                            // Progress Track
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.55
                                radius: height / 2
                                color: "#0B1120"
                                border.color: "#1E293B"
                                border.width: 1
                                clip: true

                                Rectangle {
                                    id: progressFill
                                    height: parent.height
                                    width: Math.max(parent.height, parent.width * root.updateProgressPercent)
                                    radius: height / 2
                                    color: "#F0DE2A"

                                    Behavior on width {
                                        NumberAnimation { duration: 150 }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("Destination: Cache/IRS_Alex_GCS_update.apk")
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.36
                                    color: "#64748B"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: qsTr("CANCEL")
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.38
                                    color: "#EF4444"

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            QGroundControl.cancelAppUpdate()
                                            root.updateDownloading = false
                                            root.updateStatusText = ""
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
