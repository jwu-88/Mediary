import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/profile_image_policy.dart';

void main() {
  test('allows Mediary Storage and Google account profile images', () {
    expect(
      isAllowedProfileImageUrl(
        'https://firebasestorage.googleapis.com/v0/b/'
        'cacapp-3a771.firebasestorage.app/o/profile.jpg?alt=media',
      ),
      isTrue,
    );
    expect(
      isAllowedProfileImageUrl('https://lh3.googleusercontent.com/photo'),
      isTrue,
    );
  });

  test(
    'rejects insecure, credentialed, and third-party profile image URLs',
    () {
      expect(isAllowedProfileImageUrl('http://example.com/photo.jpg'), isFalse);
      expect(
        isAllowedProfileImageUrl('https://user:secret@example.com/photo.jpg'),
        isFalse,
      );
      expect(
        isAllowedProfileImageUrl('https://example.com/photo.jpg'),
        isFalse,
      );
      expect(isAllowedProfileImageUrl('not a URL'), isFalse);
    },
  );
}
