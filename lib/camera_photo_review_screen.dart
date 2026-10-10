import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_controls.dart';

/// A captured image is held here until the person chooses to analyze it.
class CameraPhotoReviewScreen extends StatefulWidget {
  const CameraPhotoReviewScreen({
    super.key,
    required this.imageBytes,
    required this.onUsePhoto,
  });

  final Uint8List imageBytes;
  final Future<void> Function() onUsePhoto;

  @override
  State<CameraPhotoReviewScreen> createState() =>
      _CameraPhotoReviewScreenState();
}

class _CameraPhotoReviewScreenState extends State<CameraPhotoReviewScreen> {
  bool _processing = false;
  bool _photoReady = false;
  bool _photoFailed = false;
  String? _error;

  Future<void> _usePhoto() async {
    if (_processing || !_photoReady || _photoFailed) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await widget.onUsePhoto();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'We could not analyze this photo. Try again or retake it.';
      });
    }
  }

  void _retake() {
    if (!_processing) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scaledTitle = MediaQuery.textScalerOf(context).scale(22);
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: AppIconButton(
            key: const Key('discardCameraPhotoButton'),
            icon: CupertinoIcons.chevron_left,
            tooltip: 'Discard photo and return to camera',
            onPressed: _processing ? null : _retake,
          ),
          toolbarHeight: 64 + (scaledTitle - 22).clamp(0, 44),
          title: const Text(
            'Review photo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final photoHeight = (constraints.maxHeight * .52).clamp(
                    120.0,
                    640.0,
                  );
                  final stacked =
                      constraints.maxWidth < 560 ||
                      MediaQuery.textScalerOf(context).scale(16) > 24;
                  final usePhoto = AppButton(
                    key: const Key('useCameraPhotoButton'),
                    label: 'Use photo',
                    loadingLabel: 'Analyzing photo',
                    icon: CupertinoIcons.check_mark,
                    onPressed: _photoReady && !_photoFailed && !_processing
                        ? _usePhoto
                        : null,
                    busy: _processing,
                    expand: true,
                  );
                  final retake = AppButton(
                    key: const Key('retakeCameraPhotoButton'),
                    label: 'Retake',
                    icon: CupertinoIcons.camera,
                    onPressed: _processing ? null : _retake,
                    variant: AppButtonVariant.secondary,
                    expand: true,
                  );
                  return SingleChildScrollView(
                    key: const Key('cameraPhotoReviewScrollView'),
                    padding: EdgeInsets.all(AppSpacing.pageGutterOf(context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: photoHeight,
                          child: _FrozenPhoto(
                            bytes: widget.imageBytes,
                            onReady: () {
                              if (mounted && !_photoReady) {
                                setState(() => _photoReady = true);
                              }
                            },
                            onError: () {
                              if (mounted && !_photoFailed) {
                                setState(() => _photoFailed = true);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _photoFailed
                              ? 'This photo could not be displayed. Please retake it.'
                              : 'Check that the medication name is clear and fully visible.',
                          style: AppTextStyles.body.copyWith(
                            color: _photoFailed
                                ? colors.error
                                : colors.onSurface,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: AppTextStyles.body.copyWith(
                                color: colors.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (stacked) ...[
                          usePhoto,
                          const SizedBox(height: 12),
                          retake,
                        ] else
                          Row(
                            children: [
                              Expanded(child: retake),
                              const SizedBox(width: 16),
                              Expanded(child: usePhoto),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrozenPhoto extends StatefulWidget {
  const _FrozenPhoto({
    required this.bytes,
    required this.onReady,
    required this.onError,
  });

  final Uint8List bytes;
  final VoidCallback onReady;
  final VoidCallback onError;

  @override
  State<_FrozenPhoto> createState() => _FrozenPhotoState();
}

class _FrozenPhotoState extends State<_FrozenPhoto> {
  ImageProvider? _provider;
  Size? _decodeSize;
  bool _reportedReady = false;
  bool _reportedError = false;

  @override
  void dispose() {
    final provider = _provider;
    if (provider != null) unawaited(provider.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ratio = MediaQuery.devicePixelRatioOf(context);
          final size = Size(
            (constraints.maxWidth * ratio).clamp(1, 1600),
            (constraints.maxHeight * ratio).clamp(1, 1600),
          );
          if (size != _decodeSize) {
            final oldProvider = _provider;
            if (oldProvider != null) unawaited(oldProvider.evict());
            _decodeSize = size;
            // Only the display decode is bounded. OCR receives the original
            // full-resolution bytes, and discarded previews leave the cache.
            _provider = ResizeImage(
              MemoryImage(widget.bytes),
              width: size.width.round(),
              height: size.height.round(),
              policy: ResizeImagePolicy.fit,
            );
          }
          return Image(
            key: const Key('frozenCameraPhoto'),
            image: _provider!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            semanticLabel: 'Captured medication photo',
            frameBuilder: (context, child, frame, synchronous) {
              if ((frame != null || synchronous) && !_reportedReady) {
                _reportedReady = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) widget.onReady();
                });
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              if (!_reportedError) {
                _reportedError = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) widget.onError();
                });
              }
              return const Center(
                child: Icon(
                  CupertinoIcons.photo,
                  color: Colors.white,
                  size: 40,
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
