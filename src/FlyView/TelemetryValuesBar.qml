import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id:             control
    implicitWidth:  mainLayout.width + (_toolsMargin * 2)
    implicitHeight: mainLayout.height + (_toolsMargin * 2)

    property real extraWidth: 0 ///< Extra width to add to the background rectangle
    readonly property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75

    property alias factValueGrid:           factValueGrid
    property alias settingsGroup:           factValueGrid.settingsGroup
    property alias specificVehicleForCard:  factValueGrid.specificVehicleForCard

    Rectangle {
        id:             backgroundRect
        width:          control.width + extraWidth
        height:         control.height
        color:          "#E60B0E14"
        border.color:   factValueGrid.settingsUnlocked ? "#00E5FF" : "#2E384D"
        border.width:   1
        radius:         6
    }

    Rectangle {
        id:                 quickEditBtn
        anchors.top:        backgroundRect.top
        anchors.right:      backgroundRect.right
        anchors.margins:    4
        width:              ScreenTools.defaultFontPixelHeight * 1.1
        height:             ScreenTools.defaultFontPixelHeight * 1.1
        radius:             4
        color:              editMouse.containsMouse ? "#334155" : "#1E293B"
        border.color:       editMouse.containsMouse ? "#38BDF8" : "#475569"
        border.width:       1
        visible:            !factValueGrid.settingsUnlocked
        z:                  20

        QGCColoredImage {
            anchors.centerIn:   parent
            width:              parent.width * 0.65
            height:             parent.height * 0.65
            source:             "qrc:/InstrumentValueIcons/edit-pencil.svg"
            mipmap:             true
            color:              editMouse.containsMouse ? "#38BDF8" : "#94A3B8"
            fillMode:           Image.PreserveAspectFit
        }

        MouseArea {
            id:             editMouse
            anchors.fill:   parent
            hoverEnabled:   true
            cursorShape:    Qt.PointingHandCursor
            onClicked: {
                factValueGrid.settingsUnlocked = true
            }
        }
    }

    ColumnLayout {
        id:                 mainLayout
        anchors.margins:    _toolsMargin
        anchors.bottom:     parent.bottom
        anchors.left:       parent.left
        spacing:            ScreenTools.defaultFontPixelHeight * 0.4

        RowLayout {
            visible: factValueGrid.settingsUnlocked
            spacing: ScreenTools.defaultFontPixelWidth

            Rectangle {
                height: ScreenTools.defaultFontPixelHeight * 1.3
                radius: 4
                color: "#0284C7"
                implicitWidth: doneBtnTxt.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5

                Text {
                    id: doneBtnTxt
                    anchors.centerIn: parent
                    text: qsTr("Done Editing")
                    color: "#FFFFFF"
                    font.bold: true
                    font.pixelSize: ScreenTools.smallFontPointSize * 0.85
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: factValueGrid.settingsUnlocked = false
                }
            }

            Text {
                text: qsTr("Click any item to change data • Use +/- for rows/columns")
                color: "#94A3B8"
                font.pixelSize: ScreenTools.smallFontPointSize * 0.85
                Layout.alignment: Qt.AlignVCenter
            }
        }

        HorizontalFactValueGrid {
            id: factValueGrid
        }
    }

    QGCMouseArea {
        id:                         mouseArea
        x:                          mainLayout.x
        y:                          mainLayout.y
        width:                      mainLayout.width
        height:                     mainLayout.height
        acceptedButtons:            Qt.LeftButton | Qt.RightButton
        propagateComposedEvents:    true
        visible:                    !factValueGrid.settingsUnlocked

        onClicked: (mouse) => {
            if (!ScreenTools.isMobile && mouse.button === Qt.RightButton) {
                factValueGrid.settingsUnlocked = true
                mouse.accepted = true
            }
        }

        onDoubleClicked: (mouse) => {
            factValueGrid.settingsUnlocked = true
            mouse.accepted = true
        }

        onPressAndHold: (mouse) => {
            factValueGrid.settingsUnlocked = true
            mouse.accepted = true
        }
    }
}
