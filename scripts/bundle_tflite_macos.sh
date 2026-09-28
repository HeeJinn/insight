#!/bin/sh
# Xcode build phase (Runner target): copies tflite_flutter's prebuilt
# TensorFlow Lite C library into the app's Contents/Resources, which is where
# its Dart bindings open it on macOS. The plugin's podspec doesn't bundle it,
# so without this the face models fail to load at runtime.
set -e

PACKAGE_CONFIG="$PROJECT_DIR/../.dart_tool/package_config.json"
if [ ! -f "$PACKAGE_CONFIG" ]; then
  echo "error: $PACKAGE_CONFIG not found. Run 'flutter pub get' first." >&2
  exit 1
fi

ROOT_URI=$(awk '
  /"name": "tflite_flutter"/ { found = 1; next }
  found && /"rootUri"/ {
    sub(/.*"rootUri": "/, ""); sub(/".*/, ""); print; exit
  }
' "$PACKAGE_CONFIG")
PACKAGE_DIR=${ROOT_URI#file://}
case "$PACKAGE_DIR" in
  /*) ;;
  # Relative rootUris resolve against the .dart_tool directory.
  *) PACKAGE_DIR="$PROJECT_DIR/../.dart_tool/$PACKAGE_DIR" ;;
esac

SOURCE="$PACKAGE_DIR/macos/libtensorflowlite_c-mac.dylib"
if [ ! -f "$SOURCE" ]; then
  echo "error: TensorFlow Lite library not found at $SOURCE" >&2
  exit 1
fi

DEST_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$DEST_DIR"
cp -f "$SOURCE" "$DEST_DIR/"
codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --timestamp=none \
  "$DEST_DIR/libtensorflowlite_c-mac.dylib"
