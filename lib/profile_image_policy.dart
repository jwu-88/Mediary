import 'package:flutter/material.dart';

const _mediaryStorageBucket = 'cacapp-3a771.firebasestorage.app';

/// Returns whether [value] is an HTTPS profile image served by Mediary's
/// Firebase Storage bucket or Google's authenticated profile-image service.
bool isAllowedProfileImageUrl(String? value) {
  final candidate = value?.trim() ?? '';
  if (candidate.isEmpty) return false;
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return false;
  }

  final host = uri.host.toLowerCase();
  if (host == _mediaryStorageBucket ||
      host.endsWith('.googleusercontent.com')) {
    return true;
  }
  if (host != 'firebasestorage.googleapis.com') return false;

  final segments = uri.pathSegments;
  return segments.length >= 3 &&
      segments[0] == 'v0' &&
      segments[1] == 'b' &&
      segments[2] == _mediaryStorageBucket;
}

String? validateProfileImageUrl(String? value) {
  final candidate = value?.trim() ?? '';
  if (candidate.isEmpty) return null;
  return isAllowedProfileImageUrl(candidate)
      ? null
      : 'Use a Mediary Storage or Google profile image link.';
}

ImageProvider<Object>? safeProfileImageProvider(
  String? value, {
  int cacheWidth = 256,
}) {
  final candidate = value?.trim();
  if (!isAllowedProfileImageUrl(candidate)) return null;
  return ResizeImage.resizeIfNeeded(cacheWidth, null, NetworkImage(candidate!));
}
