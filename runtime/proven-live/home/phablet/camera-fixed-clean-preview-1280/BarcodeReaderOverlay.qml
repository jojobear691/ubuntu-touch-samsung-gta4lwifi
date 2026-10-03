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

import QtQuick 2.4
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Lomiri.Content 1.3
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
    property bool touchAcquired: zoomPinchArea.active || tagDetailsOpen
    property var controls: controls
    property var settings: settings
    property bool readyForCapture
    property int sensorOrientation
    // Sometimes the value is FlashVideoLight, sometimes it's FlashTorch
    property int videoFlashOnValue: Camera.FlashVideoLight
    property alias tagDetailsOpen : tagDetailsOverlay.open

    function showFocusRing(x, y) {
        focusRing.center = Qt.point(x, y);
        focusRing.show();
    }

    Settings {
        id: settings

        property int flashMode: Camera.FlashOff
        property bool gpsEnabled: false
        property bool hdrEnabled: false
        property bool videoFlashOn: false
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
        property: "hdrEnabled"
        value: settings.hdrEnabled
    }

    Binding {
        target: camera.advanced
        property: "encodingQuality"
        value: settings.encodingQuality
    }

    Binding {
        target: camera.videoRecorder
        property: "resolution"
        value: Qt.size(1280, 720) // TABA7_FIXED_VIDEO_1280
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

    function resolutionToLabel(resolution) {
        // takes in a resolution string (e.g. "1920x1080") and returns a nicer
        // form of it for display in the UI: "1080p"
        return resolution.split("x").pop() + "p";
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
        // Try to only display well known resolutions: 1080p, 720p and 480p
        videoResolutionOptionsModel.clear();
        var supported = camera.advanced.videoSupportedResolutions;
        var wellKnown = ["1920x1080", "1280x720", "640x480"];

        var supportedFiltered = supported.filter(function (resolution) {
            return wellKnown.indexOf(resolution) !== -1;
        });

        if (supportedFiltered.length === 0)
            supportedFiltered = supported.slice();

        // Sort resolutions from low to high, but then insert them into model
        // in reverse order (so that highest resolution appear first).
        supportedFiltered.sort(function(a, b) {
            return a.split("x")[0] - b.split("x")[0];
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

    OrientationSensor {
        id: orientationSensor
        active: true
    }

    Item {
        id: controls

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        visible: opacity != 0.0
        enabled: !tagDetailsOverlay.open

        Behavior on opacity { LomiriNumberAnimation { duration: LomiriAnimation.FastDuration}}

        Connections {
            target: Qt.application
            onActiveChanged: if (active) zoomControl.value = camera.currentZoom
        }

        PinchArea {
            id: zoomPinchArea
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
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
                enabled: !tagDetailsOverlay.open
                onClicked: {
                    // mouse.x/y is relative to this item. Convert to be relative to the overlay,
                    // which in turn is relative to viewFinderView, where camera's VideoOutput resides.
                    var mappedPoint = mapToItem(viewFinderOverlay, mouse.x, mouse.y);
                    camera.manualFocus(mappedPoint.x, mappedPoint.y);
                    mouse.accepted = false;
                }
            }
        }

        Row {
            anchors {
                horizontalCenter: tagDetailsButton.horizontalCenter
                verticalCenter: tagDetailsButton.verticalCenter
            }
            spacing: units.gu(2)
            height: tagDetailsButton.height

            opacity: (viewFinderView.recentlyScannedTag == "") ? 1.0 : 0.0
            Behavior on opacity { LomiriNumberAnimation { duration: LomiriAnimation.FastDuration}}
            visible: opacity != 0.0
            enabled: opacity == 1.0 && !tagDetailsOverlay.open && !tagDetailsOverlay.visible

            ActivityIndicator {
                id: scanActivityIndicator
                running: parent.visible && (camera.cameraStatus == Camera.ActiveStatus)
                height: parent.height
            }

            Label {
                anchors {
                    verticalCenter: scanActivityIndicator.verticalCenter
                }
                text: camera.cameraStatus == Camera.ActiveStatus ?
                      i18n.tr("Scanning...") : i18n.tr("Preparing...")
                textSize: Label.Large
                color: "white"
            }
        }

        CircleButton {
            id: tagDetailsButton
            objectName: "tagDetailsButton"

            anchors {
                bottom: parent.bottom
                bottomMargin: units.gu(3)
                horizontalCenter: parent.horizontalCenter
            }
            height: units.gu(7)
            width: height

            opacity: (viewFinderView.recentlyScannedTag != "") ? 1.0 : 0.0
            Behavior on opacity { LomiriNumberAnimation { duration: LomiriAnimation.FastDuration} }
            visible: opacity != 0.0
            enabled: visible
            iconSource: !tagDetailsOverlay.open ? "../../assets/qr.svg" : ""
            iconName: tagDetailsOverlay.open ? "close" : ""

            onClicked: {
                tagDetailsOverlay.open = true
            }
        }

        ZoomControl {
            id: zoomControl

            anchors {
                bottom: parent.bottom
                bottomMargin: units.gu(2)
                left: parent.left
                right: parent.right
            }
            maximumValue: camera.maximumZoom

            Binding { target: camera; property: "currentZoom"; value: zoomControl.value }
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
                left: parent.left
            }

            iconName: visible ? "go-previous" : ""
            visible: main.contentExportMode
            enabled: main.contentExportMode
            onClicked: main.cancelExport()
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: tagDetailsOverlay.open
        onClicked: {
            tagDetailsOverlay.open = false
            mouse.accepted = true;
        }
    }

    LomiriShapeOverlay {
        id: tagDetailsOverlay
        backgroundColor: "black"

        property bool open : false

        anchors {
            bottom: parent.bottom
            bottomMargin: viewFinderOverlay.height - tagDetailsButton.y + units.gu(3)
            horizontalCenter: parent.horizontalCenter
        }

/*
        // Wrong geometry when opened sideways
        rotation: Screen.angleBetween(Screen.primaryOrientation, Screen.orientation)
        Behavior on rotation {
            RotationAnimator {
                duration: LomiriAnimation.BriskDuration
                easing: LomiriAnimation.StandardEasing
                direction: RotationAnimator.Shortest
            }
        }
*/
        readonly property bool sideways : (rotation == 90 || rotation == 270)

        opacity: tagDetailsOverlay.open ? 1.0 : 0.0
        visible: opacity != 0.0
        Behavior on opacity { LomiriNumberAnimation { duration: LomiriAnimation.FastDuration} }
        onOpacityChanged: {
            if (opacity == 0.0) {
                viewFinderView.recentlyScannedTag = ""
            }
        }

        readonly property int preferredWidth: units.gu(28)
        readonly property int maximumWidth: viewFinderOverlay.width - units.gu(4)
        readonly property int preferredHeight: tagContentLabel.height + buttonContainer.height + units.gu(2)
        readonly property int maximumHeight: parent.height - tagDetailsButton.height -
                                             (tagDetailsButton.anchors.bottomMargin * 3)

        readonly property int _width: Math.min(preferredWidth, maximumWidth)
        readonly property int _height: Math.min(preferredHeight, maximumHeight)
        width: !sideways ? _width : _height
        height: !sideways ? _height : _width

        function isUrl(tagText) {
            if (tagText.startsWith("https://") || tagText.startsWith("http://") || tagText.startsWith("appid://"))
                return true
            return false;
        }

        // VCards without a name cannot be trusted
        function isVCard(tagText) {
            var text = tagText.trim()
            return text.startsWith("BEGIN:VCARD") && text.endsWith("END:VCARD") && vCardText(tagText).length > 0
        }

        function vCardText(tagText) {
            var lines = tagText.split('\n')
            for (const line of lines) {
                if (line.startsWith("FN:"))
                    return line.substring(3)
            }
            return ""
        }

        function displayText(tagText) {
            if (isVCard(tagText))
                return vCardText(tagText)
            return tagText
        }

        ScrollView {
            id: tagContentContainer
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: buttonContainer.top
                margins: units.gu(1)
            }
            height: parent.height - buttonContainer.height

            Label {
                id: tagContentLabel
                text: tagDetailsOverlay.displayText(viewFinderView.recentlyScannedTag)
                textSize: Label.Large
                color: "white"
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                width: tagContentContainer.width
                height: Math.max(contentHeight + units.gu(3), textSize + units.gu(3))
            }
        }

        Row {
            id: buttonContainer
            height: units.gu(5)
            spacing: units.gu(2)
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                margins: units.gu(1)
            }

            CircleButton {
                id: shareButton
                iconName: "share"
                automaticOrientation: false
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    qrTagPicker.contentType = tagDetailsOverlay.isUrl(viewFinderView.recentlyScannedTag) ?
                                              ContentType.Links : ContentType.Text
                    qrTagPicker.stringToSend = viewFinderView.recentlyScannedTag
                    qrTagPicker.visible = true
                    tagDetailsOverlay.open = false
                }
            }

            CircleButton {
                id: addContactButton
                iconName: "contact-new"
                automaticOrientation: false
                anchors.verticalCenter: parent.verticalCenter
                visible: tagDetailsOverlay.isVCard(viewFinderView.recentlyScannedTag)
                onVisibleChanged: {
                    buttonContainer.forceLayout()
                }
                onClicked: {
                    qrTagPicker.contentType = ContentType.Contacts
                    qrTagPicker.stringToSend = viewFinderView.recentlyScannedTag
                    qrTagPicker.visible = true
                    tagDetailsOverlay.open = false
                }
            }

            CircleButton {
                id: externalLinkButton
                iconName: "external-link"
                automaticOrientation: false
                anchors.verticalCenter: parent.verticalCenter
                visible: tagDetailsOverlay.isUrl(viewFinderView.recentlyScannedTag)
                onVisibleChanged: {
                    buttonContainer.forceLayout()
                }
                onClicked: {
                    Qt.openUrlExternally(viewFinderView.recentlyScannedTag)
                    tagDetailsOverlay.open = false
                }
            }

            CircleButton {
                id: clipboardButton
                iconName: "edit-copy"
                automaticOrientation: false
                anchors.verticalCenter: parent.verticalCenter
                visible: viewFinderView.recentlyScannedTag
                onVisibleChanged: {
                    buttonContainer.forceLayout()
                }
                onClicked: {
                    Clipboard.push(viewFinderView.recentlyScannedTag)
                    tagDetailsOverlay.open = false
                }
            }
        }
    }

    Component {
        id: qrTagContentItemComponent
        ContentItem {}
    }

    FileOperations {
        id: fileOperations
    }

    ContentPeerPicker {
        id: qrTagPicker

        property string stringToSend : ""
        property var activeTransfer : null

        anchors.fill: parent
        visible: false

        handler: ContentHandler.Destination
        contentType: ContentType.Text

        onPeerSelected: {
            activeTransfer = peer.request();

            if (contentType != ContentType.Text) {
                var tmpFile = "file://" + fileOperations.createTemporaryFile(stringToSend)
                activeTransfer.items = [ qrTagContentItemComponent.createObject(viewFinderOverlay,
                                                                       {"url": tmpFile}) ];
            } else {
                activeTransfer.items = [ qrTagContentItemComponent.createObject(viewFinderOverlay,
                                                                       {"text": stringToSend}) ];
            }
            activeTransfer.state = ContentTransfer.Charged;
            visible = false
        }

        onCancelPressed: {
            visible = false
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
}
