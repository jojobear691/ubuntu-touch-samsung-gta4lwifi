/*
 * Copyright 2014 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtMultimedia 5.9
import CameraApp 0.1
//import QtGraphicalEffects 1.0
import Lomiri.Content 1.3

import "../components"

FocusScope {
    id: viewFinderView

    property bool overlayVisible: true
    property bool optionValueSelectorVisible: false
    property bool touchAcquired: viewFinderOverlay.touchAcquired || camera.videoRecorder.recorderState == CameraRecorder.RecordingState
    property bool inView
    property alias captureMode: camera.captureMode
    property alias finderOverlay: viewFinderOverlay
    property real aspectRatio: viewFinder.sourceRect.height != 0 ? viewFinder.sourceRect.width / viewFinder.sourceRect.height : 1.0
    property bool readOnly : false
    property var cameraFilters : []
    property string recentlyScannedTag: ""
    signal photoTaken(string filePath)
    signal videoShot(string filePath)

    Connections {
        target: viewFinderOverlay
        onStatusChanged: decideCameraState()
    }
    Connections {
        target: Qt.application
        onActiveChanged: if (Qt.application.active && camera.failedToConnect) decideCameraState()
    }

    function decideCameraState() {
        if (viewFinderOverlay.status == Loader.Ready) {
            camera.cameraState = Camera.ActiveState;
        }
    }

    property Camera camera: Camera {
        id: camera
        captureMode: Camera.CaptureStillImage
        cameraState: Camera.UnloadedState
        StateSaver.properties: "captureMode, position"
        property bool failedToConnect: false

        function manualFocus(x, y) {
            var normalizedPoint = viewFinder.mapPointToSourceNormalized(Qt.point(x, y - viewFinder.y));
            if (normalizedPoint.x >= 0.0 && normalizedPoint.x <= 1.0 &&
                normalizedPoint.y >= 0.0 && normalizedPoint.y <= 1.0) {
                viewFinderOverlay.showFocusRing(x, y);
                autoFocusTimer.restart();
                focus.focusMode = Camera.FocusAuto;
                focus.customFocusPoint = normalizedPoint;
                focus.focusPointMode = Camera.FocusPointCustom;

                searchAndLock();
            }
        }

        function autoFocus() {
            unlock();

            focus.focusMode = Camera.FocusContinuous;
            focus.focusPointMode = Camera.FocusPointAuto;
        }

        property var autoFocusTimer: Timer {
            interval: 5000
            onTriggered: camera.autoFocus();
        }

        focus {
            focusMode: Camera.FocusContinuous
            focusPointMode: Camera.FocusPointAuto
        }

        property AdvancedCameraSettings advanced: AdvancedCameraSettings {
            id: advancedCamera
            camera: camera
        }

        /* Use only digital zoom for now as it's what phone cameras mostly use.
               TODO: if optical zoom is available, maximumZoom should be the combined
               range of optical and digital zoom and currentZoom should adjust the two
               transparently based on the value. */
        property alias currentZoom: camera.digitalZoom
        property alias maximumZoom: camera.maximumDigitalZoom
        property bool switchInProgress: false
        property bool photoCaptureInProgress: false
        property bool timedCaptureInProgress: false

        onPhotoCaptureInProgressChanged: {
            if (main.contentExportMode && camera.photoCaptureInProgress) {
                viewFinderExportConfirmation.photoCaptureStarted();
            }
        }

        imageCapture {
            onImageCaptured: {
                if (camera.photoCaptureInProgress) {
                    if (photoRollHint.necessary && !main.transfer) photoRollHint.enable();
                    camera.photoCaptureInProgress = false;
                }
            }

            onCaptureFailed: {
                console.log("Image capture failed for request " + requestId + ": " + message);
                camera.photoCaptureInProgress = false;
                viewFinderOverlay.visible = true;
                PopupUtils.open(captureFailedDialogComponent);
            }

            onImageSaved: {
                if(!viewFinderOverlay.settings.hasEXIF) {
                    // TODO: make this operation asynchronous.
                    postProcessOperations.deleteEXIFdata(path);
                }

                if(viewFinderOverlay.settings.dateStampImages && !main.contentExportMode) {
                    postProcessOperations.addDateStamp(path,
                                                       viewFinderOverlay.settings.dateStampFormat,
                                                       viewFinderOverlay.settings.dateStampColor,
                                                       viewFinderOverlay.settings.dateStampOpacity,
                                                       viewFinderOverlay.settings.dateStampAlign);
                }

                // TODO: make it so that asynchronous operations signals to us
                // on finished and only then proceed to the code below.

                if (main.contentExportMode)
                    viewFinderExportConfirmation.mediaPath = path;

                viewFinderView.photoTaken(path);
                metricPhotos.increment();
                console.log("Picture saved as " + path);
            }
        }

        videoRecorder {
            muted: true // TABA7_FORCE_VIDEO_MUTED_REAL_RECORDER
            onRecorderStateChanged: {
                if (videoRecorder.recorderState === CameraRecorder.StoppedState) {
                    metricVideos.increment()
                    // "actualLocation" is a URL string. Get only path from it
                    // before passing on.
                    var videoPath = videoRecorder.actualLocation.replace("file://", "");
                    viewFinderView.videoShot(videoPath);
                    if (main.contentExportMode) {
                        viewFinderExportConfirmation.mediaPath = videoRecorder.actualLocation
                    } else if (photoRollHint.necessary) {
                        photoRollHint.enable();
                    }
                }
            }
            onErrorCodeChanged: {
                if (videoRecorder.errorCode !== CameraRecorder.NoError) {
                    PopupUtils.open(captureFailedDialogComponent);
                }
            }
        }
    }

    Item {
        id: viewFinderSwitcher
        anchors.fill: parent
        visible: true //!viewFinderSwitcherBlurred.visible

        ShaderEffectSource {
            id: viewFinderGrab
            live: false
            sourceItem: viewFinder

            onScheduledUpdateCompleted: {
                if (camera.switchInProgress) {
                    // FIXME: hack to make viewFinder invisible
                    // 'viewFinder.visible = false' prevents the camera switching
                    viewFinder.width = 1;
                    viewFinder.height = 1;
                    camera.cameraState = Camera.LoadedState;
                    camera.position = (camera.position === Camera.FrontFace) ? Camera.BackFace : Camera.FrontFace;
                    decideCameraState();
                    viewFinderSwitcherRotation.angle = 180;
                }
            }
            transform: Rotation {
                origin.x: viewFinderGrab.width/2
                origin.y: viewFinderGrab.height/2
                axis.x: 0; axis.y: 1; axis.z: 0
                angle: 180
            }
        }

        transform: [
            Scale {
                id: viewFinderSwitcherScale
                origin.x: viewFinderSwitcher.width/2
                origin.y: viewFinderSwitcher.height/2
                xScale: 1
                yScale: xScale
            },
            Rotation {
                id: viewFinderSwitcherRotation
                origin.x: viewFinderSwitcher.width/2
                origin.y: viewFinderSwitcher.height/2
                axis.x: 0; axis.y: 1; axis.z: 0
                angle: 0
            }
        ]


        SequentialAnimation {
            id: viewFinderSwitcherAnimation

            SequentialAnimation {
                ParallelAnimation {
                    LomiriNumberAnimation {target: viewFinderSwitcherScale; property: "xScale"; from: 1.0; to: 0.8; duration: LomiriAnimation.BriskDuration ; easing: LomiriAnimation.StandardEasing}
                    LomiriNumberAnimation {
                        target: viewFinderSwitcherRotation
                        property: "angle"
                        from: 180
                        to: 90
                        duration: LomiriAnimation.BriskDuration
                        easing: LomiriAnimation.StandardEasing
                    }
                }
                ScriptAction {
                    script: {
                        viewFinder.width = Qt.binding(function () {return viewFinderSwitcher.width;});
                        viewFinder.height = Qt.binding(function () {return viewFinderSwitcher.height;});
                    }
                }
                PropertyAction { target: viewFinderGrab; property: "visible"; value: false }
                ParallelAnimation {
                    LomiriNumberAnimation {target: viewFinderSwitcherScale; property: "xScale"; from: 0.8; to: 1.0; duration: LomiriAnimation.BriskDuration; easing: LomiriAnimation.StandardEasingReverse}
                    LomiriNumberAnimation {
                        target: viewFinderSwitcherRotation
                        property: "angle"
                        from: 90
                        to: 0
                        duration: LomiriAnimation.BriskDuration
                        easing: LomiriAnimation.StandardEasingReverse
                    }
                }
            }
        }

        VideoOutput {
            id: viewFinder

            x: 0
            y: -viewFinderGeometry.y
            width: parent.width
            height: parent.height
            source: camera
            filters: cameraFilters
            opacity: ((main.contentExportMode && viewFinderExportConfirmation.waitingForPictureCapture) ||
                      (!main.contentExportMode && camera.photoCaptureInProgress && !camera.imageCapture.ready))
                      ? 0.1 : 1.0

            orientation: {
                // Camera-app uses X-Lomiri-Rotates-Window-Contents, which means we're always in
                // native orientation. Thus, Screen.orientation isn't used here.

                if (camera.position === Camera.FrontFace) {
                    // Front facing cameras are flipped horizontally, compensate the mirror
                    return (360 - camera.orientation) % 360;
                } else {
                    return camera.orientation;
                }
            }

            transform: Rotation {
                origin.x: viewFinder.width / 2
                origin.y: viewFinder.height / 2
                axis.x: 0; axis.y: 1; axis.z: 0
                angle: application.desktopMode ? 180 : 0
            }
        }

        /* Convenience item tracking the real position and size of the real video feed.
           Having this helps since these values depend on a lot of rules:
           - the feed is automatically scaled to fit the viewfinder
           - the viewfinder might apply a rotation to the feed, depending on device orientation
           - the resolution and aspect ratio of the feed changes depending on the active camera
           The item is also separated in a component so it can be unit tested.
         */
        ViewFinderGeometry {
            id: viewFinderGeometry
            anchors.centerIn: parent

            cameraResolution: camera.viewfinder.resolution
            viewFinderHeight: viewFinder.height
            viewFinderWidth: viewFinder.width
            viewFinderOrientation: viewFinder.orientation
        }

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            width: viewFinderGeometry.width
            height: viewFinderGeometry.height
            visible: viewFinderOverlay.settings != undefined && viewFinderOverlay.settings.gridEnabled
            source: "GridLines.qml"
            asynchronous: true
        }

        Connections {
            target: viewFinderView
            onInViewChanged: if (!viewFinderView.inView) viewFinderOverlay.controls.cancelTimedShoot()
        }

        TimedShootFeedback {
            id: timedShootFeedback
            anchors.fill: parent
            automaticOrientation: false
            customRotation: main.staticRotationAngle
        }

        ShootFeedback {
            id: shootFeedback
            anchors.fill: parent
        }
    }


    PhotoRollHint {
        id: photoRollHint
        objectName: "photoRollHint"
        anchors.fill: parent
        visible: enabled

        Connections {
            target: viewFinderView
            onInViewChanged: if (!viewFinderView.inView) photoRollHint.disable()
        }
    }


    ViewFinderOverlayLoader {
        id: viewFinderOverlay

        anchors.fill: parent
        asynchronous: true
        camera: camera
        readOnly: viewFinderView.readOnly
        sensorOrientation: camera.orientation
        opacity: status == Loader.Ready && overlayVisible && !photoRollHint.enabled ? 1.0 : 0.0
        readyForCapture: main.contentExportMode &&
                         viewFinderExportConfirmation.waitingForPictureCapture ? false : camera.imageCapture.ready

        Behavior on opacity {
            enabled: !photoRollHint.enabled
            LomiriNumberAnimation {duration: LomiriAnimation.SnapDuration}
        }

        // Tapping anywhere on the screen should not trigger any camera
        // controls while PhotoRoll hint is visible 
        MouseArea {
            anchors.fill: parent
            enabled: photoRollHint.visible
        }
    }

    Loader {
        id: viewFinderExportConfirmationLoader
        asynchronous: true
        anchors.fill: parent
        sourceComponent: viewFinderExportConfirmationComp
    }

    PostProcessOperations {
        id: postProcessOperations
    }

    property alias viewFinderExportConfirmation: viewFinderExportConfirmationLoader.item

    Component {
        id: viewFinderExportConfirmationComp
        ViewFinderExportConfirmation {
            id: viewFinderExportConfirmation
            anchors.fill: parent

            isVideo: main.transfer && main.transfer.contentType == ContentType.Videos
            geometry: viewFinderGeometry

            onShowRequested: {
                viewFinder.visible = false;
                viewFinderOverlay.visible = false;
                visible = true;
            }

            onHideRequested: {
                viewFinder.visible = true;
                viewFinderOverlay.visible = true;
                visible = false;
            }
        }
    }

    Component {
         id: captureFailedDialogComponent
         Dialog {
             id: captureFailedDialog
             objectName: "captureFailedDialog"
             title: i18n.tr("Capture failed")

             // If we are capturing to an SD card the problem can be a broken card, otherwise it is probably a
             // crash in the driver and a reboot might fix things.
             text: StorageLocations.removableStorageLocation && viewFinderOverlay.settings.preferRemovableStorage ?
                   i18n.tr("Replacing your external media, formatting it, or restarting the device might fix the problem.") :
                   i18n.tr("Restarting your device might fix the problem.")

             Button {
                 text: i18n.tr("Cancel")
                 onClicked: PopupUtils.close(captureFailedDialog)
             }
         }
    }
}
