#!/usr/bin/env bash
# FoodRush web build — used by Vercel (and handy locally).
# The Firebase web config is compiled in (lib/core/constants.dart), so no
# environment variables are required. Any FIREBASE_* variable that IS set
# overrides its compiled-in value (e.g. to point a build at another project).
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
      | tar -xJ --no-same-owner --strip-components=1 -C "${FLUTTER_HOME}"
  fi
  # The SDK is a git checkout. On Vercel the build runs as root while the
  # files (from the archive, or a cached earlier build) belong to another
  # uid, so git refuses it ("dubious ownership") and flutter can't even
  # report its version. Trust this one directory explicitly.
  git config --global --add safe.directory "${FLUTTER_HOME}"
  export PATH="${FLUTTER_HOME}/bin:${PATH}"
fi

echo "==> Using $(flutter --version | head -n 1)"

flutter config --enable-web >/dev/null
flutter pub get

echo "==> Building web (release)..."
# Only pass variables that are actually set: passing an empty one would
# replace the real compiled-in value with "" (a blank, broken site).
defines=()
for var in FIREBASE_API_KEY FIREBASE_PROJECT_ID FIREBASE_APP_ID \
           FIREBASE_MESSAGING_SENDER_ID FIREBASE_AUTH_DOMAIN \
           FIREBASE_STORAGE_BUCKET; do
  if [ -n "${!var:-}" ]; then
    defines+=("--dart-define=${var}=${!var}")
    echo "==> Using ${var} from the environment"
  fi
done

flutter build web --release ${defines[@]+"${defines[@]}"}

# Give this release's assets their own URL (/v/<id>/assets/..., mapped back
# to /assets/ by vercel.json) so cached files from an older release are
# never reused. See web/flutter_bootstrap.js.
ASSET_VERSION="${VERCEL_GIT_COMMIT_SHA:-$(date +%s)}"
ASSET_VERSION="${ASSET_VERSION:0:12}"
sed -i "s/__FR_ASSET_VERSION__/${ASSET_VERSION}/" build/web/flutter_bootstrap.js
grep -q "/v/' + frAssetVersion" build/web/flutter_bootstrap.js   && grep -q "'${ASSET_VERSION}'" build/web/flutter_bootstrap.js   || { echo "!! asset version was not stamped into flutter_bootstrap.js"; exit 1; }
echo "==> Asset version ${ASSET_VERSION}"

echo "==> Done. Output in build/web"
