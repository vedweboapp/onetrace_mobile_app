import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/forms/data/form_video_recorder_constraints.dart';

/// Full-screen in-app video recorder for operative forms.
class FormVideoRecorderPage extends StatefulWidget {
  const FormVideoRecorderPage({super.key});

  static Future<FormPickedVideoValue?> open(BuildContext context) {
    return Navigator.of(context).push<FormPickedVideoValue>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const FormVideoRecorderPage(),
      ),
    );
  }

  @override
  State<FormVideoRecorderPage> createState() => _FormVideoRecorderPageState();
}

class _FormVideoRecorderPageState extends State<FormVideoRecorderPage> {
  CameraController? _controller;
  var _initializing = true;
  String? _initError;
  var _isRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _initError = 'No camera found on this device.';
          _initializing = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (entry) => entry.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        videoBitrate: FormVideoRecorderConstraints.videoBitrate,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initError = _cameraErrorMessage(error);
        _initializing = false;
      });
    }
  }

  String _cameraErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission') || message.contains('denied')) {
      return 'Camera or microphone permission was denied.';
    }
    return 'Could not open the camera.';
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }
      final next = _elapsed + const Duration(seconds: 1);
      if (next > FormVideoRecorderConstraints.maxDuration) {
        unawaited(_stopRecording(autoStopped: true));
        return;
      }
      setState(() => _elapsed = next);
    });
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isRecording) {
      return;
    }

    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = true);
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cameraErrorMessage(error))),
      );
    }
  }

  Future<void> _stopRecording({bool autoStopped = false}) async {
    final controller = _controller;
    if (controller == null || !_isRecording) return;

    _timer?.cancel();
    setState(() => _isRecording = false);

    try {
      final file = await controller.stopVideoRecording();
      final path = file.path;
      final bytes = await File(path).length();
      final duration = _elapsed == Duration.zero
          ? FormVideoRecorderConstraints.maxDuration
          : _elapsed;

      final validationError = FormVideoRecorderConstraints.validate(
        duration: duration,
        bytes: bytes,
      );
      if (!mounted) return;

      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
        if (autoStopped) {
          Navigator.of(context).pop();
        }
        return;
      }

      Navigator.of(context).pop(
        FormPickedVideoValue(
          name: _filenameFromPath(path),
          path: path,
          sizeBytes: bytes,
          duration: duration,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cameraErrorMessage(error))),
      );
    }
  }

  static String _filenameFromPath(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : 'video.mp4';
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Record video',
          style: AppFonts.titleMedium(color: AppColors.white).copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          onPressed: _isRecording
              ? null
              : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildPreview()),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      );
    }
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _initError!,
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(color: AppColors.white),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        Positioned(
          left: 16,
          top: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                FormVideoRecorderConstraints.resolutionLabel,
                style: AppFonts.labelSmall(color: AppColors.white).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        if (_isRecording)
          Positioned(
            right: 16,
            top: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      FormVideoRecorderConstraints.formatDuration(_elapsed),
                      style: AppFonts.labelLarge(color: AppColors.white)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    final remaining =
        FormVideoRecorderConstraints.maxDuration - _elapsed;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              FormVideoRecorderConstraints.limitsHint,
              textAlign: TextAlign.center,
              style: AppFonts.bodySmall(color: AppColors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _isRecording ? () => _stopRecording() : _startRecording,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 4),
                ),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _isRecording ? 30 : 58,
                  height: _isRecording ? 30 : 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(_isRecording ? 8 : 40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isRecording
                  ? 'Tap to stop · ${FormVideoRecorderConstraints.formatDuration(remaining > Duration.zero ? remaining : Duration.zero)} left'
                  : 'Tap to record',
              style: AppFonts.bodySmall(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
