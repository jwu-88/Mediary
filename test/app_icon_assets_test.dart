import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const icons = {
    'assets/icon/Mediary App.png': 1024,
    'assets/icon/Mediary App Dark.png': 1024,
    'web/favicon.png': 16,
    'web/favicon-dark.png': 16,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  };

  for (final icon in icons.entries) {
    test(
      '${icon.key} decodes with intact PNG chunks and no personal metadata',
      () async {
        final bytes = await File(icon.key).readAsBytes();
        _expectValidPng(bytes);

        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          try {
            expect(frame.image.width, icon.value);
            expect(frame.image.height, icon.value);
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      },
      skip: kIsWeb ? 'validates repository files on the host' : false,
    );
  }
}

void _expectValidPng(Uint8List bytes) {
  expect(bytes.length, greaterThanOrEqualTo(8));
  expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(bytes);
  var offset = 8;
  var hasImageData = false;
  var hasEnd = false;

  while (offset < bytes.length) {
    expect(offset + 12, lessThanOrEqualTo(bytes.length));
    final length = data.getUint32(offset);
    final end = offset + length + 12;
    expect(end, lessThanOrEqualTo(bytes.length));
    final kind = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    expect(
      data.getUint32(offset + length + 8),
      _crc32(bytes, offset + 4, offset + length + 8),
      reason: '$kind chunk checksum must match its contents',
    );
    expect(
      const {'eXIf', 'iTXt', 'tEXt', 'zTXt', 'tIME'},
      isNot(contains(kind)),
      reason: 'app icons must not carry personal or editing metadata',
    );
    hasImageData = hasImageData || kind == 'IDAT';
    if (kind == 'IEND') {
      hasEnd = true;
      expect(length, 0);
      expect(end, bytes.length);
    }
    offset = end;
  }

  expect(hasImageData, isTrue);
  expect(hasEnd, isTrue);
}

int _crc32(Uint8List bytes, int start, int end) {
  var checksum = 0xffffffff;
  for (var index = start; index < end; index++) {
    checksum ^= bytes[index];
    for (var bit = 0; bit < 8; bit++) {
      checksum = (checksum >>> 1) ^ ((checksum & 1) == 1 ? 0xedb88320 : 0);
    }
  }
  return (checksum ^ 0xffffffff) & 0xffffffff;
}
