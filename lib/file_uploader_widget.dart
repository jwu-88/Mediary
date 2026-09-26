import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

/// A self-contained, cross-platform file picker that works with Flutter Web.
///
/// The widget deliberately reads the selected file through
/// [PlatformFile.readAsBytes] instead of using [PlatformFile.path]. A local
/// file path is not guaranteed to exist on Web, and this keeps the widget free
/// of any `dart:io` dependency.
class FileUploaderWidget extends StatefulWidget {
  const FileUploaderWidget({
    super.key,
    this.allowedExtensions = const <String>[],
  });

  /// Optional extensions without leading dots, for example `['jpg', 'png']`.
  /// An empty list allows any file type.
  final List<String> allowedExtensions;

  @override
  State<FileUploaderWidget> createState() => _FileUploaderWidgetState();
}

class _FileUploaderWidgetState extends State<FileUploaderWidget> {
  bool _isPicking = false;
  String? _fileName;
  int? _fileSizeBytes;
  String? _errorMessage;

  Future<void> _pickFile() async {
    if (_isPicking) return;

    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final extensions = widget.allowedExtensions
          .map(
            (extension) => extension.replaceFirst('.', '').trim().toLowerCase(),
          )
          .where((extension) => extension.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final type = extensions.isEmpty ? FileType.any : FileType.custom;

      // pickFile() returns null when the user closes the picker without
      // selecting anything. That is a normal cancellation, not an error.
      final pickedFile = await FilePicker.pickFile(
        type: type,
        allowedExtensions: extensions.isEmpty ? null : extensions,
      );
      if (pickedFile == null) return;

      // This is the Web-safe access path. Do not replace it with
      // pickedFile.path or dart:io File APIs.
      final Uint8List bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('The selected file is empty.');
      }

      final fileName = pickedFile.name.trim().isEmpty
          ? 'Selected file'
          : pickedFile.name;
      await _uploadFile(bytes, fileName);

      if (!mounted) return;
      setState(() {
        _fileName = fileName;
        _fileSizeBytes = bytes.length;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('File selection failed: $error\n$stackTrace');
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to read that file. Please try another file.';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// Placeholder for the eventual backend upload implementation.
  ///
  /// Keep this method byte-based so the same code works on Web, mobile, and
  /// desktop. Add authentication, content validation, and upload progress here
  /// when the backend endpoint is ready.
  Future<void> _uploadFile(Uint8List bytes, String fileName) async {
    // TODO: Upload [bytes] using [fileName] when the backend is available.
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload a file',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a file from your device to continue.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('fileUploaderButton'),
                onPressed: _isPicking ? null : _pickFile,
                icon: _isPicking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isPicking ? 'Opening files…' : 'Choose a file'),
              ),
              if (_fileName != null && _fileSizeBytes != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_fileName · ${_formatFileSize(_fileSizeBytes!)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  key: const Key('fileUploaderError'),
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
