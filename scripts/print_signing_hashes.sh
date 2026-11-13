#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYSTORE_PATH="${SCRIPT_DIR}/../mobile_app/android/app/veribite-debug.keystore"

echo "===================================================================="
echo " VeriBite Android Signing Keystore Fingerprint Diagnostic Tool"
echo "===================================================================="

KEYTOOL_CMD="keytool"
if ! command -v keytool &> /dev/null; then
    if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/keytool" ]]; then
        KEYTOOL_CMD="${JAVA_HOME}/bin/keytool"
    elif [[ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" ]]; then
        KEYTOOL_CMD="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
    else
        echo "[ERROR] keytool was not found in PATH, JAVA_HOME, or Android Studio."
        exit 1
    fi
fi

if [[ ! -f "${KEYSTORE_PATH}" ]]; then
    echo "[ERROR] Keystore file not found at: ${KEYSTORE_PATH}"
    exit 1
fi

echo "Keystore Location: ${KEYSTORE_PATH}"
echo "Key Alias:         androiddebugkey"
echo "Store Password:    android"
echo "Package Name:      com.example.mobile_app"
echo ""
echo "--------------------------------------------------------------------"
echo "Certificate Fingerprints:"
echo "--------------------------------------------------------------------"
"${KEYTOOL_CMD}" -list -v -keystore "${KEYSTORE_PATH}" -alias androiddebugkey -storepass android | grep -E "SHA1:|SHA256:"
echo "--------------------------------------------------------------------"
echo ""
echo "[DONE] Add the above SHA-1 and SHA-256 to Google Cloud Console"
echo "under: APIs & Services -> Credentials -> OAuth 2.0 Client IDs (Android)."
echo "===================================================================="

