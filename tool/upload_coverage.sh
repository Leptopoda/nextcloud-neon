#!/bin/bash
# DO NOT enable -x as it will leak the `CODECOV_TOKEN` secret
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -v GITHUB_REPOSITORY ]; then
    exit
fi

if [ ! -f codecov ]; then
    curl https://keybase.io/codecovsecurity/pgp_keys.asc | gpg --no-default-keyring --keyring trustedkeys.gpg --import
    curl -Os https://uploader.codecov.io/latest/linux/codecov
    curl -Os https://uploader.codecov.io/latest/linux/codecov.SHA256SUM
    curl -Os https://uploader.codecov.io/latest/linux/codecov.SHA256SUM.sig
    gpgv codecov.SHA256SUM.sig codecov.SHA256SUM

    shasum -a 256 -c codecov.SHA256SUM
    chmod +x codecov
fi

./codecov --verbose upload-process --fail-on-error -F $MELOS_PACKAGE_NAME -f "$MELOS_PACKAGE_PATH/coverage/lcov.info" -t $CODECOV_TOKEN
