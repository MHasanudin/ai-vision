import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_service.dart';

/// A widget that displays the camera preview using CameraController
class CameraPreviewWidget extends StatefulWidget {
  final CameraService cameraService;
  final Widget? child; // Overlay widgets (bounding boxes, landmarks, etc.)
  final BoxFit fit;
  final bool mirrorFrontCamera;

  const CameraPreviewWidget({
    super.key,
    required this.cameraService,
    this.child,
    this.fit = BoxFit.cover,
    this.mirrorFrontCamera = true,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  CameraController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.cameraService.controller;
    _isInitialized = _controller?.value.isInitialized ?? false;
    // Listen for camera switches (controller changes)
    widget.cameraService.controllerNotifier.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {
      _controller = widget.cameraService.controller;
      _isInitialized = _controller?.value.isInitialized ?? false;
    });
  }

  @override
  void dispose() {
    widget.cameraService.controllerNotifier.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calculate aspect ratio
    final aspectRatio = previewSize.width / previewSize.height;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          Transform(
            alignment: Alignment.center,
            transform: widget.mirrorFrontCamera && widget.cameraService.isFrontCamera
                ? Matrix4.rotationY(3.14159) // Mirror horizontally
                : Matrix4.identity(),
            child: CameraPreview(_controller!),
          ),
          // Overlay child (bounding boxes, landmarks, etc.)
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// A more advanced camera preview that handles orientation and scaling
class AdvancedCameraPreview extends StatefulWidget {
  final CameraService cameraService;
  final Widget Function(BuildContext, Size previewSize)? overlayBuilder;
  final BoxFit fit;
  final bool mirrorFrontCamera;
  final Color backgroundColor;

  const AdvancedCameraPreview({
    super.key,
    required this.cameraService,
    this.overlayBuilder,
    this.fit = BoxFit.cover,
    this.mirrorFrontCamera = true,
    this.backgroundColor = Colors.black,
  });

  @override
  State<AdvancedCameraPreview> createState() => _AdvancedCameraPreviewState();
}

class _AdvancedCameraPreviewState extends State<AdvancedCameraPreview> {
  CameraController? _controller;
  bool _isInitialized = false;
  Size? _previewSize;

  @override
  void initState() {
    super.initState();
    _controller = widget.cameraService.controller;
    _isInitialized = _controller?.value.isInitialized ?? false;
    _previewSize = _controller?.value.previewSize;
    // Listen for camera switches (controller changes)
    widget.cameraService.controllerNotifier.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {
      _controller = widget.cameraService.controller;
      _isInitialized = _controller?.value.isInitialized ?? false;
      _previewSize = _controller?.value.previewSize;
    });
  }

  @override
  void dispose() {
    widget.cameraService.controllerNotifier.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null || _previewSize == null) {
      return Container(
        color: widget.backgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the size to maintain aspect ratio
        final previewAspectRatio = _previewSize!.width / _previewSize!.height;
        final viewAspectRatio = constraints.maxWidth / constraints.maxHeight;

        double width, height;
        if (previewAspectRatio > viewAspectRatio) {
          // Preview is wider than view - fit to width
          width = constraints.maxWidth;
          height = width / previewAspectRatio;
        } else {
          // Preview is taller than view - fit to height
          height = constraints.maxHeight;
          width = height * previewAspectRatio;
        }

        return Container(
          color: widget.backgroundColor,
          child: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview
                  Transform(
                    alignment: Alignment.center,
                    transform: widget.mirrorFrontCamera && widget.cameraService.isFrontCamera
                        ? Matrix4.rotationY(3.14159)
                        : Matrix4.identity(),
                    child: CameraPreview(_controller!),
                  ),
                  // Overlay
                  if (widget.overlayBuilder != null)
                    widget.overlayBuilder!(context, _previewSize!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}