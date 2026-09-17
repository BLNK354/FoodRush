#!/usr/bin/env bash
# FoodRush web build — used by Vercel (and handy locally).
# Reads the six FIREBASE_* variables from the environment.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.35.2}"
FLUTTER_HOME="${HOME}/.flutter-sdk"

# Install a pinned Flutter SDK if it isn't already available.
if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
    echo "==> Installing Flutter ${FLUTTER_VERSION}..."
    mkdir -p "${FLUTTER_HOME}"
    curl -fsSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ --strip-components=1 -C "${FLUTTER_HOME}"
  fi
  export PATH="${FLUTTER_HOME}/bin:${PATH}"
fi

echo "==> Using $(flutter --version | head -n 1)"

flutter config --enable-web >/dev/null
flutter pub get

echo "==> Building web (release)..."
flutter build web --release \
  --dart-define="FIREBASE_API_KEY=${FIREBASE_API_KEY:-}" \
  --dart-define="FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-}" \
  --dart-define="FIREBASE_APP_ID=${FIREBASE_APP_ID:-}" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID:-}" \
  --dart-define="FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define="FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET:-}"

echo "==> Done. Output in build/web"
