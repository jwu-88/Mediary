#!/bin/sh
set -eu
# use an isolated flutter test chrome profile with a synthetic video device.
# override mediary_chrome_binary and flutter_bin on other operating systems.
export MEDIARY_CHROME_BINARY="${MEDIARY_CHROME_BINARY:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
mediary_camera_test_dir=$(mktemp -d)
trap 'rm -rf "$mediary_camera_test_dir"' EXIT HUP INT TERM
cat > "$mediary_camera_test_dir/chrome" <<'CHROME'
#!/bin/sh
exec "$MEDIARY_CHROME_BINARY" --use-fake-device-for-media-stream --use-fake-ui-for-media-stream "$@"
CHROME
chmod +x "$mediary_camera_test_dir/chrome"
CHROME_EXECUTABLE="$mediary_camera_test_dir/chrome" "${FLUTTER_BIN:-flutter}" test   --platform chrome --dart-define=MEDIARY_SYNTHETIC_CAMERA_TEST=true   test/web_camera_capture_test.dart
