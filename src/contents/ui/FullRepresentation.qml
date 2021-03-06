/**
 * OctoPrint Monitor
 *
 * Plasmoid to monitor OctoPrint instance and print job progress.
 *
 * @author    Marcin Orlowski <mail (#) marcinOrlowski (.) com>
 * @copyright 2020 Marcin Orlowski
 * @license   http://www.opensource.org/licenses/mit-license.php MIT
 * @link      https://github.com/MarcinOrlowski/octoprint-monitor
 */

import QtQuick 2.6
import QtQuick.Layouts 1.5
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as Core
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as Extras
import org.kde.kquickcontrolsaddons 2.0
import QtQuick.Controls.Styles 1.4

GridLayout {
    id: fullContainer

//    width: units.gu(300)
//    height: units.gu(200)

    columns: 1
    rows: 5

    // ------------------------------------------------------------------------------------------------------------------------

	property bool isCameraViewEnabled: plasmoid.configuration.cameraViewEnabled && plasmoid.configuration.cameraViewSnapshotUrl != ""
	property string cameraViewTimerState: ""
	property string cameraView0Stamp: ""
	property string cameraView1Stamp: ""
    Timer {
        id: fullImageTimer;

        interval: plasmoid.configuration.cameraViewUpdateInterval * 1000
        repeat: true
        running: plasmoid.expanded
        triggeredOnStart: plasmoid.expanded

        onTriggered: {
            if (!main.apiConnected || plasmoid.expanded == false || !isCameraViewEnabled || !isCameraViewPollActive()) {
                fullContainer.cameraViewTimerState = i18n("STOPPED")
                return
            } else {
                fullContainer.cameraViewTimerState = `@${plasmoid.configuration.cameraViewUpdateInterval} secs`
            }

			var targetImageView = (cameraViewStack.currentIndex === 0) ? cameraView0 : cameraView1
			targetImageView.source = plasmoid.configuration.cameraViewSnapshotUrl

			function finishImage() {
				if (targetImageView.status === Component.Ready) {
					targetImageView.statusChanged.disconnect(finishImage)
			        cameraViewStack.currentIndex = (cameraViewStack.currentIndex+1) % 2

                    var stamp = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
                    if (cameraViewStack.currentIndex === 0) {
                        cameraView0Stamp = stamp
                    } else {
                        cameraView1Stamp = stamp
                    }
				}
			}

			if (targetImageView.status === Component.Loading) {
				targetImageView.statusChanged.connect(finishImage)
			} else {
				finishImage()
			}
		}
	}

    // ------------------------------------------------------------------------------------------------------------------------

    /*
    ** Determines if we should keep polling camera view or stop,
    ** depeneding of multiple factors, incl. user settings.
    **
    ** Returns:
    **  bool: False if camera view poll should stop.
    */
    function isCameraViewPollActive() {
        if (!plasmoid.configuration.stopCameraPollForBuckets) return true

        var result = true
        switch (getPrinterStateBucket()) {
            case main.bucket_idle: result = !plasmoid.configuration.stopCameraPollForBucketIdle; break;
            case main.bucket_unknown: result = !plasmoid.configuration.stopCameraPollForBucketUnknown; break;
            case main.bucket_working: result = !plasmoid.configuration.stopCameraPollForBucketWorking; break;
            case main.bucket_paused: result = !plasmoid.configuration.stopCameraPollForBucketPaused; break;
            case main.bucket_error: result = !plasmoid.configuration.stopCameraPollForBucketError; break;
            case main.bucket_disconnected: result = !plasmoid.configuration.stopCameraPollForBucketDisconnected; break;
        }
        return result
    }

    // ------------------------------------------------------------------------------------------------------------------------

    ColumnLayout {

        RowLayout {
            width: parent.width
            Layout.fillWidth: true

            Image {
                readonly property int iconSize: 96

                Layout.alignment: Qt.AlignCenter
                fillMode: Image.PreserveAspectFit
                source: main.octoStateIcon
                clip: true
                width: iconSize
                height: iconSize
                Layout.maximumWidth: iconSize
                Layout.maximumHeight: iconSize
                Layout.preferredWidth: iconSize
                Layout.preferredHeight: iconSize
            }

            ColumnLayout {
                id: fullStateContainer

                Layout.fillWidth: true

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    fontSizeMode: Text.Fit
                    minimumPointSize: 1
                    text: {
                        var state = main.octoState;
                        if (main.jobInProgress) {
                            state += ` ${main.jobCompletion}%`
                        }
                        return state;
                    }
                    font.capitalization: Font.Capitalize
                }
                PlasmaComponents.ProgressBar {
                    Layout.maximumWidth: fullStateContainer.width
                    height: 4
                    value: main.jobCompletion/100
                    visible: main.jobInProgress
                }
                PlasmaComponents.Label {
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 8
                    text: i18n('Print time') + `: ${main.jobPrintTime}`
                    font.pixelSize: Qt.application.font.pixelSize * 0.8
                    visible: main.jobInProgress && plasmoid.configuration.showJobPrintTime
                }
                PlasmaComponents.Label {
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 8
                    text: i18n('ETA') + `: ${main.jobPrintTimeLeft}`
                    font.pixelSize: Qt.application.font.pixelSize * 0.8
                    visible: main.jobInProgress && plasmoid.configuration.showJobTimeLeft
                }
            } // ColumnLayout
        } // RowLayout

        PlasmaComponents.Label {
            fontSizeMode: Text.Fit
            minimumPixelSize: 8
            elide: Text.ElideMiddle
            text: main.jobFileName
            visible: main.jobInProgress && plasmoid.configuration.showJobFileName
        }
    } // ColumnLayout

    StackLayout {
        id: cameraViewStack

        width: fullContainer.width
        Layout.minimumWidth: fullContainer.width
        Layout.maximumWidth: fullContainer.width

        visible: isCameraViewEnabled
        currentIndex: 0

        ColumnLayout {
            width: fullContainer.width
            Layout.minimumWidth: fullContainer.width

            Image {
                id: cameraView0
                Layout.minimumWidth: parent.width
                Layout.maximumWidth: parent.width

                sourceSize.width: cameraView0.width
                sourceSize.height: cameraView0.height
                fillMode: Image.PreserveAspectFit;
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
                cache: false
                asynchronous: true
                Layout.alignment: Qt.AlignCenter
            }
            PlasmaComponents.Label {
                maximumLineCount: 1
                Layout.maximumWidth: parent.width
                fontSizeMode: Text.Fit
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Qt.application.font.pixelSize * 0.8
                text: (cameraView0Stamp != '') ? `${cameraView0Stamp} (${cameraViewTimerState})` : ''
            }
        }

        ColumnLayout {
            width: parent.width
            Layout.minimumWidth: parent.width
            Layout.maximumWidth: parent.width
            Image {
                id: cameraView1
                Layout.minimumWidth: parent.width
                Layout.maximumWidth: parent.width

                sourceSize.width: cameraView1.width
                sourceSize.height: cameraView1.height
                fillMode: Image.PreserveAspectFit;
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
                cache: false
                asynchronous: true
                Layout.alignment: Qt.AlignCenter
            }
            PlasmaComponents.Label {
                maximumLineCount: 1
                Layout.maximumWidth: parent.width
                wrapMode: Text.NoWrap
                fontSizeMode: Text.Fit
                elide: Text.ElideRight
                font.pixelSize: Qt.application.font.pixelSize * 0.8
                text: (cameraView1Stamp != '') ? `${cameraView1Stamp} (${cameraViewTimerState})` : ''
            }
        }
    } // StackLayout

    // ------------------------------------------------------------------------------------------------------------------------
}
