#!/bin/sh
set -eu
# Use an isolated Flutter test Chrome profile with a synthetic video device.
# Override MEDIARY_CHROME_BINARY and FLUTTER_BIN on other operating systems.
export MEDIARY_CHROME_BINARY="${MEDIARY_CHROME_BINARY:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
mediary_camera_test_dir=$(mktemp -d)
trap 'rm -rf "$mediary_camera_test_dir"' EXIT HUP INT TERM
cat > "$mediary_camera_test_dir/chrome" <<'CHROME'
#!/bin/sh
exec "$MEDIARY_CHROME_BINARY" --use-fake-device-for-media-stream --use-fake-ui-for-media-stream "$@"
CHROME
chmod +x "$mediary_camera_test_dir/chrome"
CHROME_EXECUTABLE="$mediary_camera_test_dir/chrome" "${FLUTTER_BIN:-flutter}" test   --platform chrome --dart-define=MEDIARY_SYNTHETIC_CAMERA_TEST=true   test/web_camera_capture_test.dart
