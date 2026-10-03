/* TABA7_FIXED_CLEAN_PREVIEW_FILE_ACTIVE */
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
import QtPositioning 5.2
import QtSensors 5.0
import CameraApp 0.1
import Qt.labs.settings 1.0
import QtGraphicalEffects 1.0

import "../components"

Item {
    id: viewFinderOverlay

    property Camera camera
    property bool touchAcquired: bottomEdge.pressed || zoomPinchArea.active
    property real revealProgress: noSpaceHint.visible ? 1.0 : bottomEdge.progress
    property var controls: controls
    property var settings: settings
    property bool readyForCapture
    property int sensorOrientation
    // Sometimes the value is FlashVideoLight, sometimes it's FlashTorch
    property int videoFlashOnValue: Camera.FlashVideoLight

    // Screen's aspect ratio in both major orientations
    readonly property string screenAspectRatio: sizeToAspectRatio(Qt.size(Screen.width, Screen.height))
    readonly property string screenAspectRatio2: sizeToAspectRatio(Qt.size(Screen.height, Screen.width))

    function showFocusRing(x, y) {
        focusRing.center = Qt.point(x, y);
        focusRing.show();
    }

    Settings {
        id: settings

        property int flashMode: Camera.FlashOff
        property bool gpsEnabled: false
        property bool hasEXIF: false // Should it even be enabled by default?
        property bool hdrEnabled: false
        property bool videoFlashOn: false
        property int videoQuality: 0 // 0 - Normal, 1 - High
        // Left for compatibility
        property int videoFlashMode: -1
        property int selfTimerDelay: 0
        property int encodingQuality: 2 // QMultimedia.NormalQuality
        property bool gridEnabled: false
        property bool preferRemovableStorage: false
        property bool playShutterSound: true
        property bool shutterVibration: false
        property var photoResolutions
        property var videoResolutions
        // Left for compatibility
        property string videoResolution: ""
        property bool dateStampImages: false
        property string dateStampFormat: Qt.locale().dateFormat(Locale.ShortFormat)
        property color dateStampColor: LomiriColors.orange;
        property real dateStampOpacity: 1.0;
        property int dateStampAlign :  Qt.AlignBottom | Qt.AlignRight;

        Component.onCompleted: {
            if (!photoResolutions) photoResolutions = {}

            if (!videoResolutions) {
                videoResolutions = {}
                if (videoResolution)
                    // Migrate old value into default camera
                    setVideoResolution(videoResolution);
            }

            if (videoFlashMode != -1) {
                videoFlashOn = (videoFlashMode != Camera.FlashOff);
                videoFlashMode = -1;
            }
        }

        onPhotoResolutionsChanged: updateViewfinderResolution();
        onVideoResolutionsChanged: updateViewfinderResolution();

        onGpsEnabledChanged: if(gpsEnabled&&!hasEXIF)hasEXIF = true;
        onHasEXIFChanged: if(gpsEnabled&&!hasEXIF)gpsEnabled = false;
        onFlashModeChanged: if (flashMode != Camera.FlashOff) hdrEnabled = false;
        onHdrEnabledChanged: if (hdrEnabled) flashMode = Camera.FlashOff
    }

    Binding {
        target: camera.flash
        property: "mode"
        value: Camera.FlashOff
        when: camera.captureMode == Camera.CaptureStillImage
    }

    Binding {
        target: camera.flash
        property: "mode"
        value: Camera.FlashOff
        when: camera.captureMode == Camera.CaptureVideo
    }

    Binding {
        target: camera.advanced
        property: "hasEXIF"
        value: settings.hasEXIF
    }

    Binding {
        target: camera.advanced
        property: "hdrEnabled"
        value: settings.hdrEnabled
    }

    Binding {
        target: camera.advanced
        property: "encodingQuality"
        value: settings.encodingQuality
        // This makes sure that the correct image quality is initiated
        when: camera.cameraStatus == Camera.ActiveStatus
    }

    Binding {
        target: camera.videoRecorder
        property: "videoBitRate"
        value: getVideoBitrate()
        // This makes sure that the correct video bitrate is initiated
        when: camera.cameraStatus == Camera.ActiveStatus
    }

    Binding {
        target: camera.videoRecorder
        property: "resolution"
        value: Qt.size(1280, 720) // TABA7_FIXED_VIDEO_1280
        // This makes sure that the correct video resolution is initiated
        when: camera.cameraStatus == Camera.LoadedStatus || camera.cameraStatus == Camera.ActiveStatus
    }

    Binding {
        target: camera.imageCapture
        property: "resolution"
        value: Qt.size(1280, 720) // TABA7_FIXED_IMAGE_1280
    }

    // FIXME: where's the proper location for this?
    function updateViewfinderResolution() {
        var EPSILON = 0.02;
        var supportedViewfinderResolutions = camera.supportedViewfinderResolutions();

        if (supportedViewfinderResolutions.length === 0) {
            console.log("TABA7_FIXED_PREVIEW_1280: supported viewfinder resolutions unknown; using 1280x720.");
            camera.viewfinder.resolution = Qt.size(1280, 720);
            return;
            return;
        }

        var targetResolution = stringToSize(
            camera.captureMode === Camera.CaptureStillImage
                ? settings.photoResolutions[camera.deviceId]
                : settings.videoResolutions[camera.deviceId]
        );

        if (!targetResolution) {
            // Resolution has not been selected yet.
            return;
        }

        var targetAspectRatio = targetResolution.width / targetResolution.height;
        var selectedResolution;

        // Select the highest resolution with matching aspect ratio.
        for (var i = 0; i < supportedViewfinderResolutions.length; i++) {
            var currentResolution = supportedViewfinderResolutions[i];
            var currentAspectRatio = currentResolution.width / currentResolution.height;

            if (Math.abs(targetAspectRatio - currentAspectRatio) > EPSILON)
                continue;

            if (!selectedResolution ||
                    currentResolution.width > selectedResolution.width) {
                selectedResolution = currentResolution;
            }
        }

        if (!selectedResolution) {
            // This is strange. Not sure why this would happen.
            console.log("updateViewfinderResolution: cannot find suitable viewfinder resolution. Use the default one.");
            selectedResolution = supportedViewfinderResolutions[0];
        }

        console.log("updateViewfinderResolution: For target resolution " +
                    sizeToString(targetResolution) + ", select " +
                    sizeToString(selectedResolution) + " for viewfinder resolution.");

        camera.viewfinder.resolution =
                Qt.size(selectedResolution.width, selectedResolution.height);
    }

    function updateVideoFlashOnValue() {
        if (camera.captureMode != Camera.CaptureVideo) {
            // The value can be probed only in video mode.
            return;
        }

        var supportedModes = camera.flash.supportedModes;
        for (var i = 0; i < supportedModes.length; i++) {
            if (supportedModes[i] === Camera.FlashVideoLight ||
                    supportedModes[i] === Camera.FlashTorch) {
                videoFlashOnValue = supportedModes[i];
                return;
            }
        }
    }

    Connections {
        target: camera.imageCapture
        onImageCaptured: {
           if(settings.shutterVibration) {
               Haptics.play({intensity:0.25,duration:LomiriAnimation.SnapDuration/3});
           }
        }
    }

    Connections {
        target: camera.flash
        onSupportedModesChanged: { updateVideoFlashOnValue(); }
    }

    Connections {
        target: camera
        onCaptureModeChanged: {
            updateViewfinderResolution();
        }

        onCameraStatusChanged: {
            // Supported viewfinder resolution is guaranteed to be known at
            // ActiveStatus, if not earlier.
            if (camera.cameraStatus == Camera.LoadedStatus
                || camera.cameraStatus == Camera.ActiveStatus) {
                updateViewfinderResolution();
            }
        }
    }

    function triggerShoot() {
        if (shootButton.enabled) {
            if (camera.captureMode == Camera.CaptureVideo && camera.videoRecorder.recorderState == CameraRecorder.RecordingState) {
                camera.videoRecorder.stop();
            } else {
                if (settings.selfTimerDelay > 0) {
                    controls.timedShoot(settings.selfTimerDelay);
                } else {
                    controls.shoot();
                }
            }
        }
    }

    function resolutionToLabel(resolution, full=true) {
        // takes in a resolution string (e.g. "1920x1080") and returns a nicer
        // form of it for display in the UI: "1080p"
        const label = resolution.split("x").pop() + "p";

        if (full) {
            // Include the aspect ratio in full format
            const aspectRatio = sizeToAspectRatio(stringToSize(resolution));
            let finalAspectRatio = aspectRatio

            // Label those that are equal to screen's aspect ratio as "Full"
            // except 16:9 since it's common
            if ((aspectRatio === viewFinderOverlay.screenAspectRatio
                    || aspectRatio === viewFinderOverlay.screenAspectRatio2
                 )
                    && aspectRatio !== "16:9") {
                finalAspectRatio = i18n.tr("Full")
            }

            return "%1 (%2)".arg(label).arg(finalAspectRatio);
        }

        return "%1".arg(label);
    }

    function sizeToString(size) {
        return size.width + "x" + size.height;
    }

    function stringToSize(resolution) {
        if (!resolution) {
            console.log("TABA7_SAFE_STRINGTOSIZE_EMPTY_1280");
            return Qt.size(1280, 720);
        }
        if (resolution.width !== undefined && resolution.height !== undefined) {
            console.log("TABA7_SAFE_STRINGTOSIZE_QSIZE", resolution.width, resolution.height);
            return Qt.size(resolution.width, resolution.height);
        }
        if (resolution.split === undefined) {
            console.log("TABA7_SAFE_STRINGTOSIZE_UNKNOWN_1280", resolution);
            return Qt.size(1280, 720);
        }
        var r = resolution.split("x");
        if (!r || r.length < 2 || !r[0] || !r[1]) {
            console.log("TABA7_SAFE_STRINGTOSIZE_BAD_1280", resolution);
            return Qt.size(1280, 720);
        }
        return Qt.size(r[0], r[1]);
    }

    function sizeToAspectRatio(size) {
        var ratio = Math.max(size.width, size.height) / Math.min(size.width, size.height);
        var maxDenominator = 12;
        var epsilon;
        var numerator;
        var denominator;
        var bestDenominator;
        var bestEpsilon = 10000;
        for (denominator = 2; denominator <= maxDenominator; denominator++) {
            numerator = ratio * denominator;
            epsilon = Math.abs(Math.round(numerator) - numerator);
            if (epsilon < bestEpsilon) {
                bestEpsilon = epsilon;
                bestDenominator = denominator;
            }
        }
        numerator = Math.round(ratio * bestDenominator);

        // Further simplify square aspect ratio to 1:1
        if (numerator === bestDenominator) {
            numerator = 1;
            bestDenominator = 1;
        }

        return "%1:%2".arg(numerator).arg(bestDenominator);
    }

    function sizeToMegapixels(size) {
        var megapixels = (size.width * size.height) / 1000000;
        return parseFloat(megapixels.toFixed(1))
    }

    function trimNumberToFit(numberStr, digits) {
        return (""+numberStr).substr(0,digits).replace(/\.$/,"");
    }

    function updateVideoResolutionOptions() {
        // Clear and refill videoResolutionOptionsModel with available resolutions
        // Try to only display well known resolutions: 2160p, 1440p, 1080p, 720p and 480p
        videoResolutionOptionsModel.clear();
        var supported = camera.advanced.videoSupportedResolutions;
        var wellKnown = ["2160", "1440", "1080", "720", "480"];

        var supportedFiltered = supported.filter(function (resolution) {
            return wellKnown.findIndex(
                value => {
                    const _pattern = "x" + value + "$"
                    const _regex = new RegExp(_pattern, "g")
                    return resolution.match(_regex)
                }
            ) !== -1;
        });

        if (supportedFiltered.length === 0)
            supportedFiltered = supported.slice();

        // Sort resolutions from low to high, but then insert them into model
        // in reverse order (so that highest resolution appear first).
        supportedFiltered.sort(function(a, b) {
            return a.split("x")[1] - b.split("x")[1];
        });

        for (var i=0; i<supportedFiltered.length; i++) {
            var resolution = supportedFiltered[i];
            var option = {"icon": "",
                          "label": resolutionToLabel(resolution),
                          "value": resolution};
            videoResolutionOptionsModel.insert(0, option);
        }

        // If resolution setting chosen is not supported select the highest available resolution
        if (supportedFiltered.length > 0
                && supportedFiltered.indexOf(settings.videoResolutions[camera.deviceId]) === -1) {
            setVideoResolution(supportedFiltered[supportedFiltered.length - 1]);
        }
    }

    function updatePhotoResolutionOptions() {
        // Clear and refill photoResolutionOptionsModel with available resolutions
        photoResolutionOptionsModel.clear();


        //Change to Size object and sort the resolutions by megapixel ( in reverse order so it goes from top high to  bottom low )
        var sortedResolutions = [];
        for(var i in camera.advanced.imageSupportedResolutions) {
            sortedResolutions.push( stringToSize(camera.advanced.imageSupportedResolutions[i]) );
        }
        sortedResolutions.sort(function(a, b) { return sizeToMegapixels(b) - sizeToMegapixels(a) });

        for(var i in sortedResolutions) {
            var res = sortedResolutions[i];
            photoResolutionOptionsModel.insert(i,{"icon": "",
                                                   "label": "%1 (%2MP)".arg(sizeToAspectRatio(res))
                                                                       .arg(sizeToMegapixels(res)),
                                                   "value": sizeToString(res)});
        }

        // If resolution setting is not supported select the resolution automatically
        var photoResolution = settings.photoResolutions[camera.deviceId];
        if (!isPhotoResolutionAnOption(photoResolution)) {
            setPhotoResolution(getAutomaticPhotoResolution());
        }

    }

    // Get the appropriate video bitrate based on the current quality setting
    function getVideoBitrate() {
        const quality = settings.videoQuality
        const resoSize = camera.videoRecorder.resolution

        if (quality === 1) { // High Quality
            switch(true) {
                case resoSize.height >= 2160:
                    return 48000000 // 48 Mbps
                case resoSize.height >= 1440:
                    return 35000000 // 35 Mbps
                case resoSize.height >= 1080:
                    return 17000000 // 17 Mbps
                case resoSize.height >= 720:
                    return 10000000 // 10 Mbps
                case resoSize.height >= 480:
                    return 6000000 // 6 Mbps
                default:
                    return 5000000 // 5 Mbps
            }
        } else {
            switch(true) {
                case resoSize.height >= 2160:
                    return 35000000 // 35 Mbps
                case resoSize.height >= 1440:
                    return 16000000 // 16 Mbps
                case resoSize.height >= 1080:
                    return 8000000 // 8 Mbps
                case resoSize.height >= 720:
                    return 5000000 // 5 Mbps
                case resoSize.height >= 480:
                    return 2500000 // 2.5 Mbps
                default:
                    return 2000000 // 2 Mbps
            }
        }
    }

    function setPhotoResolution(resolution) {
        var size = stringToSize(resolution);
        if (size.width > 0 && size.height > 0
            && resolution != settings.photoResolutions[camera.deviceId]) {
            settings.photoResolutions[camera.deviceId] = resolution;
            // FIXME: resetting the value of the property 'photoResolutions' is
            // necessary to ensure that a change notification signal is emitted
            settings.photoResolutions = settings.photoResolutions;
        }
    }

    function setVideoResolution(resolution) {
        if (resolution !== settings.videoResolutions[camera.deviceId]) {
            settings.videoResolutions[camera.deviceId] = resolution;
            // FIXME: resetting the value of the property 'videoResolutions' is
            // necessary to ensure that a change notification signal is emitted
            settings.videoResolutions = settings.videoResolutions;
        }
    }

    function getAutomaticPhotoResolution() {
        var fittingResolution = sizeToString(camera.advanced.fittingResolution);
        var maximumResolution = sizeToString(camera.advanced.maximumResolution);
        if (isPhotoResolutionAnOption(fittingResolution)) {
            return fittingResolution;
        } else {
            return maximumResolution;
        }
    }

    function isPhotoResolutionAnOption(resolution) {
        for (var i=0; i<photoResolutionOptionsModel.count; i++) {
            var option = photoResolutionOptionsModel.get(i);
            if (option.value == resolution) {
                return true;
            }
        }
        return false;
    }

    Connections {
        target: camera.advanced
        onVideoSupportedResolutionsChanged: updateVideoResolutionOptions();
        onImageSupportedResolutionsChanged: updatePhotoResolutionOptions();
        onFittingResolutionChanged: updatePhotoResolutionOptions();
        onMaximumResolutionChanged: updatePhotoResolutionOptions();
    }

    Connections {
        target: camera
        onDeviceIdChanged: {
            // Clear viewfinder resolution settings as it might not be supported
            // by the new device.
            camera.viewfinder.resolution = Qt.size(1280, 720); // TABA7_FIXED_NO_NEGATIVE_VIEWFINDER
        }
    }

    function optionsOverlayClose() {
        print("optionsOverlayClose")
        if (optionsOverlayLoader.item.valueSelectorOpened) {
            optionsOverlayLoader.item.closeValueSelector();
        } else {
            bottomEdge.close();
        }
    }

    MouseArea {
        id: bottomEdgeClose
        anchors.fill: parent
        onClicked: optionsOverlayClose()
        enabled: !camera.timedCaptureInProgress
    }

    OrientationHelper {
        id: bottomEdgeOrientation
        transitionEnabled: bottomEdge.opened

        Panel {
            id: bottomEdge
            anchors {
                right: parent.right
                left: parent.left
                bottom: parent.bottom
            }
            height: optionsOverlayLoader.height
            onOpenedChanged: optionsOverlayLoader.item.closeValueSelector()
            enabled: camera.videoRecorder.recorderState == CameraRecorder.StoppedState
                     && !camera.photoCaptureInProgress && !camera.timedCaptureInProgress
            opacity: enabled ? 1.0 : 0.3
            property bool ready: optionsOverlayLoader.status == Loader.Ready

            /* At startup, opened is false and 'bottomEdge.height' is 0 until
               optionsOverlayLoader has finished loading. When that happens
               'bottomEdge.height' becomes non 0 and 'bottomEdge.position' which
               depends on bottomEdge.height eventually reaches the value
               'bottomEdge.height'. Unfortunately during that short period 'progress'
               has an incorrect value and unfortunate consequences/bugs occur.
               That makes it important to only compute progress when 'opened' is true.

               Ref.: https://bugs.launchpad.net/ubuntu/+source/camera-app/+bug/1472903
            */
            property real progress: bottomEdge.height ? (bottomEdge.height - bottomEdge.position) / bottomEdge.height : 0
            property list<ListModel> options: [
                ListModel {
                    id: gpsOptionsModel

                    property string settingsProperty: "gpsEnabled"
                    property string icon: "location"
                    property string label: ""
                    property bool isToggle: true
                    property int selectedIndex: bottomEdge.indexForValue(gpsOptionsModel, settings.gpsEnabled)
                    property bool available: true
                    property bool visible: true
                    property bool showInIndicators: true
                    property bool colorize: !positionSource.isPrecise

                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("On")
                        value: true
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Off")
                        value: false
                    }
                },
                ListModel {
                    id: flashOptionsModel

                    property string settingsProperty: "flashMode"
                    property string icon: ""
                    property string label: ""
                    property bool isToggle: false
                    property int selectedIndex: bottomEdge.indexForValue(flashOptionsModel, settings.flashMode)
                    property bool available: camera.advanced.hasFlash
                    property bool visible: camera.captureMode == Camera.CaptureStillImage
                    property bool showInIndicators: true

                    ListElement {
                        icon: "flash-on"
                        label: QT_TR_NOOP("On")
                        value: Camera.FlashOn
                    }
                    ListElement {
                        icon: "flash-auto"
                        label: QT_TR_NOOP("Auto")
                        value: Camera.FlashAuto
                    }
                    ListElement {
                        icon: "flash-off"
                        label: QT_TR_NOOP("Off")
                        value: Camera.FlashOff
                    }
                },
                ListModel {
                    id: videoFlashOptionsModel

                    property string settingsProperty: "videoFlashOn"
                    property string icon: ""
                    property string label: ""
                    property bool isToggle: false
                    property int selectedIndex: bottomEdge.indexForValue(videoFlashOptionsModel, settings.videoFlashOn)
                    property bool available: camera.advanced.hasFlash
                    property bool visible: camera.captureMode == Camera.CaptureVideo
                    property bool showInIndicators: true

                    ListElement {
                        icon: "torch-on"
                        label: QT_TR_NOOP("On")
                        value: true
                    }
                    ListElement {
                        icon: "torch-off"
                        label: QT_TR_NOOP("Off")
                        value: false
                    }
                },
                ListModel {
                    id: hdrOptionsModel

                    property string settingsProperty: "hdrEnabled"
                    property string icon: ""
                    property string label: i18n.tr("HDR")
                    property bool isToggle: true
                    property int selectedIndex: bottomEdge.indexForValue(hdrOptionsModel, settings.hdrEnabled)
                    property bool available: camera.advanced.hasHdr
                    property bool visible: camera.captureMode === Camera.CaptureStillImage
                    property bool showInIndicators: true

                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("On")
                        value: true
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Off")
                        value: false
                    }
                },
                ListModel {
                    id: selfTimerOptionsModel

                    property string settingsProperty: "selfTimerDelay"
                    property string icon: ""
                    property string iconSource: "../../assets/self_timer.svg"
                    property string label: ""
                    property bool isToggle: true
                    property int selectedIndex: bottomEdge.indexForValue(selfTimerOptionsModel, settings.selfTimerDelay)
                    property bool available: true
                    property bool visible: true
                    property bool showInIndicators: true

                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Off")
                        value: 0
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("5 seconds")
                        value: 5
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("15 seconds")
                        value: 15
                    }
                },
                ListModel {
                    id: encodingQualityOptionsModel

                    property string settingsProperty: "encodingQuality"
                    property string icon: "stock_image"
                    property string label: ""
                    property bool isToggle: false
                    property int selectedIndex: bottomEdge.indexForValue(encodingQualityOptionsModel, settings.encodingQuality)
                    property bool available: true
                    property bool visible: camera.captureMode == Camera.CaptureStillImage
                    property bool showInIndicators: false

                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Fine Quality")
                        value: 4 // QMultimedia.VeryHighQuality
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("High Quality")
                        value: 3 // QMultimedia.HighQuality
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Normal Quality")
                        value: 2 // QMultimedia.NormalQuality
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Basic Quality")
                        value: 1 // QMultimedia.LowQuality
                    }
                },
                ListModel {
                    id: videoQualityOptionsModel
                    property string settingsProperty: "videoQuality"
                    property string icon: "stock_video"
                    property string label: ""
                    property bool isToggle: false
                    property int selectedIndex: bottomEdge.indexForValue(videoQualityOptionsModel, settings.videoQuality)
                    property bool available: true
                    property bool visible: camera.captureMode == Camera.CaptureVideo
                    property bool showInIndicators: false
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("High Quality")
                        value: 1
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Normal Quality")
                        value: 0
                    }
                },
                ListModel {
                    id: videoResolutionOptionsModel

                    function setSettingProperty(value) {
                        setVideoResolution(value);
                    }

                    property string icon: ""
                    property string label: resolutionToLabel(settings.videoResolutions[camera.deviceId], false)
                    property bool isToggle: false
                    property int selectedIndex: bottomEdge.indexForValue(videoResolutionOptionsModel,
                                                    settings.videoResolutions[camera.deviceId])
                    property bool available: true
                    property bool visible: camera.captureMode == Camera.CaptureVideo
                    property bool showInIndicators: false
                },
                ListModel {
                    id: gridOptionsModel

                    property string settingsProperty: "gridEnabled"
                    property string icon: ""
                    property string iconSource: "../../assets/grid_lines.svg"
                    property string label: ""
                    property bool isToggle: true
                    property int selectedIndex: bottomEdge.indexForValue(gridOptionsModel, settings.gridEnabled)
                    property bool available: true
                    property bool visible: true

                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("On")
                        value: true
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Off")
                        value: false
                    }
                },
                ListModel {
                    id: removableStorageOptionsModel

                    property string settingsProperty: "preferRemovableStorage"
                    property string icon: ""
                    // TRANSLATORS: this will be displayed on an small button so for it to fit it should be less then 3 characters long.
                    property string label: i18n.tr("SD")
                    property bool isToggle: true
                    property int selectedIndex: bottomEdge.indexForValue(removableStorageOptionsModel, settings.preferRemovableStorage)
                    property bool available: StorageLocations.removableStoragePresent
                    property bool visible: available

                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Save to SD Card")
                        value: true
                    }
                    ListElement {
                        icon: ""
                        label: QT_TR_NOOP("Save internally")
                        value: false
                    }
                },
                ListModel {
                    id: shutterSoundOptionsModel

                    function setSettingProperty(value) {
                        settings.shutterVibration = value & 0x1;
                        settings.playShutterSound = value & 0x2;
                    }

                    property string settingsProperty: "playShutterSound"
                    property string icon: ""
                    property string label: ""
                    property bool isToggle: true
                    property int selectedIndex: bottomEdge.indexForValue(shutterSoundOptionsModel, 2 * settings.playShutterSound  + settings.shutterVibration)
                    property bool available: true
                    property bool visible: camera.captureMode === Camera.CaptureStillImage
                    property bool showInIndicators: false

                    ListElement {
                        icon: "audio-volume-high"
                        label: QT_TR_NOOP("On")
                        value: 2
                    }
                    ListElement {
                        iconSource: "../../assets/vibrate.png"
                        label: QT_TR_NOOP("Vibrate")
                        value: 1
                    }
                    ListElement {
                        icon: "audio-volume-muted"
                        label: QT_TR_NOOP("Off")
                        value: 0
                    }
                },
                ListModel {
                    id: photoResolutionOptionsModel

                    function setSettingProperty(value) {
                        setPhotoResolution(value);
                    }

                    property string icon: ""
                    property string label: "%1MP".arg(trimNumberToFit(sizeToMegapixels(stringToSize(settings.photoResolutions[camera.deviceId])),3))
                    property bool isToggle: false
                    property int selectedIndex: bottomEdge.indexForValue(photoResolutionOptionsModel, settings.photoResolutions[camera.deviceId])
                    property bool available: true
                    property bool visible: camera.captureMode == Camera.CaptureStillImage
                    property bool showInIndicators: false
                },
                ListModel {
                    id: photoEXIFSettingsModel

                    function setSettingProperty(value) {
                        settings.hasEXIF = value;
                    }

                    property string settingsProperty: "hasEXIF"
                    property string icon: ""
                    property string label: ""
                    property bool isToggle: true
                    property int selectedIndex: bottomEdge.indexForValue(photoEXIFSettingsModel, settings.hasEXIF)
                    property bool available: true
                    property bool visible: camera.captureMode === Camera.CaptureStillImage
                    property bool showInIndicators: false

                    ListElement {
                        icon: "private-browsing-exit"
                        label: QT_TR_NOOP("Save device info")
                        value: true
                    }
                    ListElement {
                        icon: "private-browsing"
                        label: QT_TR_NOOP("No device info")
                        value: false
                    }
                }
            ]

            /* FIXME: StorageLocations.removableStoragePresent is not updated dynamically.
               Workaround that by reading it when the bottom edge is opened/closed.
            */
            Connections {
                target: bottomEdge
                onOpenedChanged: StorageLocations.updateRemovableStorageInfo()
            }

            function indexForValue(model, value) {
                var i;
                var element;
                for (i=0; i<model.count; i++) {
                    element = model.get(i);
                    if (element.value === value) {
                        return i;
                    }
                }

                return -1;
            }

            BottomEdgeIndicators {
                id: bottomEdgeIndicators
                options: bottomEdge.options
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.top
                }
                opacity: bottomEdge.pressed || bottomEdge.opened ? 0.0 : 1.0
                Behavior on opacity { LomiriNumberAnimation {} }
            }

            Loader {
                id: optionsOverlayLoader
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                asynchronous: true
                sourceComponent: Component {
                    OptionsOverlay {
                        options: bottomEdge.options
                    }
                }
            }

            triggerSize: units.gu(3)

            Item {
                /* Use the 'trigger' feature of Panel so that tapping on the Panel
                   can be acted upon */
                id: clickReceiver
                anchors.fill: parent
                anchors.topMargin: -bottomEdge.triggerSize

                function trigger() {
                    if (bottomEdge.opened) {
                        optionsOverlayClose();
                    } else {
                        bottomEdge.open();
                    }
                }
            }
        }
    }

    OrientationSensor {
        id: orientationSensor
        active: true
    }

    Item {
        id: controls

        anchors {
            left: parent.left
            right: parent.right
        }
        height: parent.height
        y: Screen.angleBetween(Screen.primaryOrientation, Screen.orientation) == 0 ? bottomEdge.position - bottomEdge.height : 0
        opacity: 1 - bottomEdge.progress
        visible: opacity != 0.0
        enabled: !bottomEdge.progress

        Behavior on opacity { LomiriNumberAnimation { duration: LomiriAnimation.FastDuration}}

        function timedShoot(secs) {
            camera.timedCaptureInProgress = true;
            timedShootFeedback.start();
            shootingTimer.remainingSecs = secs;
            shootingTimer.start();
        }

        function cancelTimedShoot() {
            if (camera.timedCaptureInProgress) {
                camera.timedCaptureInProgress = false;
                shootingTimer.stop();
                timedShootFeedback.stop();
            }
        }

        function shoot() {
            // Note that orientation now means the clockwise rotation of the image.
            var orientation = 0;
            if (orientationSensor.reading != null) {
                switch (orientationSensor.reading.orientation) {
                    case OrientationReading.TopUp:
                        orientation = 0;
                        break;
                    case OrientationReading.TopDown:
                        orientation = 180;
                        break;
                    case OrientationReading.LeftUp:
                        orientation = 270;
                        break;
                    case OrientationReading.RightUp:
                        orientation = 90;
                        break;
                    default:
                        /* Workaround for OrientationSensor not setting a valid value until
                           the device is rotated.
                           Ref.: https://bugs.launchpad.net/qtubuntu-sensors/+bug/1429865

                           Note that the value returned by Screen.angleBetween is valid if
                           the orientation lock is not engaged.
                           Ref.: https://bugs.launchpad.net/camera-app/+bug/1422762
                        */
                        orientation = Screen.angleBetween(Screen.primaryOrientation, Screen.orientation);
                        break;
                }
            }

            if (camera.position === Camera.FrontFace) {
                // Clockwise device becomes counter-clockwise camera
                orientation = 360 - orientation;
            }

            // account for the orientation of the sensor
            orientation += viewFinderOverlay.sensorOrientation;

            // Ensure that the orientation is positive and within range.
            orientation = (orientation + 360) % 360;

            if (camera.captureMode == Camera.CaptureVideo) {
                if (main.contentExportMode) {
                    camera.videoRecorder.outputLocation = StorageLocations.temporaryLocation;
                } else if (StorageLocations.removableStoragePresent && settings.preferRemovableStorage) {
                    camera.videoRecorder.outputLocation = StorageLocations.removableStorageVideosLocation;
                } else {
                    camera.videoRecorder.outputLocation = StorageLocations.videosLocation;
                }

                if (camera.videoRecorder.recorderState == CameraRecorder.StoppedState) {
                    camera.videoRecorder.setMetadata("Orientation", orientation);
                    camera.videoRecorder.setMetadata("Date", new Date());
                    camera.videoRecorder.record();
                }
            } else {
                if (!main.contentExportMode) {
                    shootFeedback.start();
                }
                camera.photoCaptureInProgress = true;
                camera.imageCapture.setMetadata("Orientation", orientation);
                camera.imageCapture.setMetadata("Date", new Date());
                var position = positionSource.position;
                if (settings.hasEXIF && settings.gpsEnabled && positionSource.isPrecise) {
                    camera.imageCapture.setMetadata("GPSLatitude", position.coordinate.latitude);
                    camera.imageCapture.setMetadata("GPSLongitude", position.coordinate.longitude);
                    camera.imageCapture.setMetadata("GPSTimeStamp", position.timestamp);
                    camera.imageCapture.setMetadata("GPSProcessingMethod", "GPS");
                    if (position.altitudeValid) {
                        camera.imageCapture.setMetadata("GPSAltitude", position.coordinate.altitude);
                    }
                }

                if (main.contentExportMode) {
                    camera.imageCapture.captureToLocation(StorageLocations.temporaryLocation);
                } else if (StorageLocations.removableStoragePresent && settings.preferRemovableStorage) {
                    camera.imageCapture.captureToLocation(StorageLocations.removableStoragePicturesLocation);
                } else {
                    camera.imageCapture.captureToLocation(StorageLocations.picturesLocation);
                }
            }
        }

        function switchCamera() {
            camera.switchInProgress = true;
            //                viewFinderGrab.sourceItem = viewFinder;
            viewFinderGrab.x = viewFinder.x;
            viewFinderGrab.y = viewFinder.y;
            viewFinderGrab.width = viewFinder.width;
            viewFinderGrab.height = viewFinder.height;
            viewFinderGrab.visible = true;
            viewFinderGrab.scheduleUpdate();
        }

        function completeSwitch() {
            viewFinderSwitcherAnimation.restart();
            camera.switchInProgress = false;
            zoomControl.value = camera.currentZoom;
        }

        function changeRecordMode() {
            if (camera.captureMode == Camera.CaptureVideo) camera.videoRecorder.stop()
            camera.captureMode = (camera.captureMode == Camera.CaptureVideo) ? Camera.CaptureStillImage : Camera.CaptureVideo
            zoomControl.value = camera.currentZoom
        }

        Connections {
            target: Qt.application
            onActiveChanged: if (active) zoomControl.value = camera.currentZoom
        }

        Timer {
            id: shootingTimer
            repeat: true
            triggeredOnStart: true

            property int remainingSecs: 0

            onTriggered: {
                if (remainingSecs == 0) {
                    running = false;
                    camera.timedCaptureInProgress = false;
                    controls.shoot();
                    timedShootFeedback.stop();
                } else {
                    timedShootFeedback.showRemainingSecs(remainingSecs);
                    remainingSecs--;
                }
            }
        }

        PositionSource {
            id: positionSource
            updateInterval: 1000
            active: settings.gpsEnabled
            property bool isPrecise: valid
                                     && position.latitudeValid
                                     && position.longitudeValid
                                     && (!position.horizontalAccuracyValid ||
                                          position.horizontalAccuracy <= 100)
        }

        Connections {
            target: camera.imageCapture
            onReadyChanged: {
                if (camera.imageCapture.ready) {
                    if (camera.switchInProgress) {
                        controls.completeSwitch();
                    }
                }
            }
        }

        CircleButton {
            id: recordModeButton
            objectName: "recordModeButton"

            anchors {
                right: shootButton.left
                rightMargin: units.gu(7.5)
                bottom: parent.bottom
                bottomMargin: units.gu(6)
            }

            automaticOrientation: false
            customRotation: main.staticRotationAngle
            iconName: (camera.captureMode == Camera.CaptureStillImage) ? "camcorder" : "camera-symbolic"
            onClicked: controls.changeRecordMode()
            enabled: camera.videoRecorder.recorderState == CameraRecorder.StoppedState && !main.contentExportMode
                     && !camera.photoCaptureInProgress && !camera.timedCaptureInProgress
        }

        ShootButton {
            id: shootButton

            anchors {
                bottom: parent.bottom
                // account for the bottom shadow in the asset
                bottomMargin: units.gu(5) - units.dp(6)
                horizontalCenter: parent.horizontalCenter
            }

            enabled: (
                (camera.captureMode == Camera.CaptureVideo
                    && camera.videoRecorder.recorderStatus == CameraRecorder.RecordingStatus) ||
                (viewFinderOverlay.readyForCapture && !storageMonitor.diskSpaceCriticallyLow
                     && !camera.timedCaptureInProgress)
            )
            state: (camera.captureMode == Camera.CaptureVideo) ?
                   ((camera.videoRecorder.recorderState == CameraRecorder.StoppedState) ? "record_off" : "record_on") :
                   "camera"
            onClicked: {
                viewFinderOverlay.triggerShoot();
            }
            rotation: main.staticRotationAngle
            Behavior on rotation {
                RotationAnimator {
                    duration: LomiriAnimation.BriskDuration
                    easing: LomiriAnimation.StandardEasing
                    direction: RotationAnimator.Shortest
                }
            }
        }

        CircleButton {
            id: swapButton
            objectName: "swapButton"

            anchors {
                left: shootButton.right
                leftMargin: units.gu(7.5)
                bottom: parent.bottom
                bottomMargin: units.gu(6)
            }

            automaticOrientation: false
            customRotation: main.staticRotationAngle
            enabled: !camera.switchInProgress && camera.videoRecorder.recorderState == CameraRecorder.StoppedState
                     && !camera.photoCaptureInProgress && !camera.timedCaptureInProgress
            iconName: "camera-flip"
            onClicked: controls.switchCamera()
        }


        PinchArea {
            id: zoomPinchArea
            anchors {
                top: parent.top
                topMargin: bottomEdgeIndicators.height
                bottom: shootButton.top
                bottomMargin: bottomEdgeIndicators.height
                left: parent.left
                leftMargin: bottomEdgeIndicators.height
                right: parent.right
                rightMargin: bottomEdgeIndicators.height
            }

            property real initialZoom
            property real minimumScale: 0.3
            property real maximumScale: 3.0
            property bool active: false

            enabled: !camera.photoCaptureInProgress && !camera.timedCaptureInProgress
            onPinchStarted: {
                active = true;
                initialZoom = zoomControl.value;
                zoomControl.show();
            }
            onPinchUpdated: {
                zoomControl.show();
                var scaleFactor = MathUtils.projectValue(pinch.scale, 1.0, maximumScale, 0.0, zoomControl.maximumValue);
                zoomControl.value = MathUtils.clamp(initialZoom + scaleFactor, zoomControl.minimumValue, zoomControl.maximumValue);
            }
            onPinchFinished: {
                active = false;
            }


            MouseArea {
                id: manualFocusMouseArea
                anchors.fill: parent
                objectName: "manualFocusMouseArea"
                enabled: camera.focus.isFocusPointModeSupported(Camera.FocusPointCustom) &&
                         !camera.photoCaptureInProgress && !camera.timedCaptureInProgress
                onClicked: {
                    // mouse.x/y is relative to this item. Convert to be relative to the overlay,
                    // which in turn is relative to viewFinderView, where camera's VideoOutput resides.
                    var mappedPoint = mapToItem(viewFinderOverlay, mouse.x, mouse.y);
                    camera.manualFocus(mappedPoint.x, mappedPoint.y);
                    mouse.accepted = false;
                }
            }
        }

        ZoomControl {
            id: zoomControl

            anchors {
                bottom: shootButton.top
                bottomMargin: units.gu(2)
                left: parent.left
                right: parent.right
                leftMargin: recordModeButton.x
                rightMargin: parent.width - (swapButton.x + swapButton.width)
            }
            maximumValue: camera.maximumZoom

            Binding { target: camera; property: "currentZoom"; value: zoomControl.value }
        }

        StopWatch {
            id: stopWatch

            anchors {
                top: parent.top
                topMargin: units.gu(6)
                horizontalCenter: parent.horizontalCenter
            }
            opacity: camera.videoRecorder.recorderState == CameraRecorder.StoppedState ? 0.0 : 1.0
            Behavior on opacity { LomiriNumberAnimation {} }
            visible: opacity != 0
            time: camera.videoRecorder.duration / 1000
            rotation: main.staticRotationAngle
        }

        FocusRing {
            id: focusRing
        }

        CircleButton {
            id: exportBackButton
            objectName: "exportBackButton"

            anchors {
                top: parent.top
                topMargin: units.gu(4)
                left: recordModeButton.left
            }

            iconName: visible ? "go-previous" : ""
            visible: main.contentExportMode
            enabled: main.contentExportMode
            onClicked: main.cancelExport()
        }
    }

    ProcessingFeedback {
        anchors {
            top: parent.top
            topMargin: units.gu(2)
            left: parent.left
            leftMargin: units.gu(2)
        }
        processing: camera.photoCaptureInProgress
    }

    StorageMonitor {
        id: storageMonitor
        location: (StorageLocations.removableStoragePresent && settings.preferRemovableStorage) ?
                   StorageLocations.removableStorageLocation : StorageLocations.videosLocation
        onDiskSpaceLowChanged: if (storageMonitor.diskSpaceLow && !storageMonitor.diskSpaceCriticallyLow) {
                                   PopupUtils.open(freeSpaceLowDialogComponent);
                               }
        onDiskSpaceCriticallyLowChanged: if (storageMonitor.diskSpaceCriticallyLow) {
                                             camera.videoRecorder.stop();
                                         }
        onIsWriteableChanged: if (!isWriteable && !diskSpaceLow && !main.contentExportMode) {
                                  PopupUtils.open(readOnlyMediaDialogComponent);
                              }
    }

    NoSpaceHint {
        id: noSpaceHint
        objectName: "noSpace"
        anchors.fill: parent
        visible: storageMonitor.diskSpaceCriticallyLow
    }

    Component {
        id: freeSpaceLowDialogComponent
        Dialog {
            id: freeSpaceLowDialog
            objectName: "lowSpaceDialog"
            title: i18n.tr("Low storage space")
            text: i18n.tr("You are running out of storage space. To continue without interruptions, free up storage space now.")
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(freeSpaceLowDialog)
            }
        }
    }

    Component {
         id: readOnlyMediaDialogComponent
         Dialog {
             id: readOnlyMediaDialog
             objectName: "readOnlyMediaDialog"
             title: i18n.tr("External storage not writeable")
             text: i18n.tr("It does not seem possible to write to your external storage media. Trying to eject and insert it again might solve the issue, or you might need to format it.")
             Button {
                 text: i18n.tr("Cancel")
                 onClicked: PopupUtils.close(readOnlyMediaDialog)
             }
         }
    }

    Connections {
        id: permissionErrorMonitor
        property var currentPermissionsDialog: null
        target: camera
        onError: {
            if (false && errorCode == Camera.ServiceMissingError) { console.log("TABA7_SUPPRESSED_SERVICE_MISSING_ERROR_POPUP", errorCode);
                if (currentPermissionsDialog == null) {
                    currentPermissionsDialog = PopupUtils.open(noPermissionsDialogComponent);
                }
                camera.failedToConnect = true;
            }
        }
        onCameraStateChanged: {
            if (camera.cameraState != Camera.UnloadedState) {
                if (currentPermissionsDialog != null) {
                    PopupUtils.close(currentPermissionsDialog);
                    currentPermissionsDialog = null;
                }
                camera.failedToConnect = false;
            } else {
                camera.photoCaptureInProgress = false;
            }
        }
    }

    Component {
        id: noPermissionsDialogComponent
        Dialog {
            id: noPermissionsDialog
            objectName: "noPermissionsDialog"
            title: i18n.tr("Cannot access camera")
            text: i18n.tr("Camera app doesn't have permission to access the camera hardware or another error occurred.\n\nIf granting permission does not resolve this problem, reboot your device.")
            Button {
                text: i18n.tr("Edit Permissions")
                color: theme.palette.normal.focus
                onClicked: {
                    Qt.openUrlExternally("settings:///system/security-privacy?service=camera");
                    PopupUtils.close(noPermissionsDialog);
                    permissionErrorMonitor.currentPermissionsDialog = null;
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: {
                    PopupUtils.close(noPermissionsDialog);
                    permissionErrorMonitor.currentPermissionsDialog = null;
                }
            }
        }
    }

    FastBlur {
        id: viewFinderSwitcherBlurred
        anchors.fill: parent
        property real finalRadius: 67
        property real finalOpacity: 1.0
        radius: photoRollHint.visible ? finalRadius : viewFinderOverlay.revealProgress * finalRadius
        opacity: photoRollHint.visible ? finalOpacity : (1.0 - viewFinderOverlay.revealProgress) * finalOpacity + finalOpacity
        source: viewFinderSwitcher !== null ? viewFinderSwitcher : null
        z:-1
        visible:  appSettings.blurEffects && radius !== 0
        transparentBorder:false
        Behavior on radius { LomiriNumberAnimation { duration: LomiriAnimation.SnapDuration} }
    }

    Rectangle {
        id: viewFinderOverlayTint
        anchors.fill:parent
        property real finalOpacity: 0.25
        property real tintOpacity : viewFinderOverlay.revealProgress * finalOpacity
        visible: viewFinderOverlay.revealProgress > 0
        opacity:tintOpacity
        color: LomiriColors.jet
        z:-1
    }
}
