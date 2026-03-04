#!/bin/bash

BUNDLE_ID="org.oniroproject.vlc"
GREP_FILTER=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --grep)
      GREP_FILTER="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      shift
      ;;
  esac
done

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.." || exit 1

# Prepare libs
mkdir -p "$SCRIPT_DIR/../entry/libs/arm64-v8a"
cp -rL "$SCRIPT_DIR/../vlc_install/lib/libvlc.so"* "$SCRIPT_DIR/../entry/libs/arm64-v8a/"
cp -rL "$SCRIPT_DIR/../vlc_install/lib/libvlccore.so"* "$SCRIPT_DIR/../entry/libs/arm64-v8a/"
cp -rL "$SCRIPT_DIR/../vlc_install/lib/vlc/plugins"/*/* "$SCRIPT_DIR/../entry/libs/arm64-v8a/" 2>/dev/null || true

# Build
hvigorw assembleHap --mode module -p product=default -p module=entry -p buildMode=debug --stacktrace --no-parallel --no-daemon || { echo "Build failed"; exit 1; }

# Install and Clear Logs
echo "Installing the app..."
hdc install entry/build/default/outputs/default/entry-default-signed.hap
hdc shell hilog -r
hdc shell aa start -a EntryAbility -b "$BUNDLE_ID"

echo "Starting the app..."

# Give the app a moment to spin up
sleep 1 

# Extract PID
pid=$(hdc shell ps -ef | grep "$BUNDLE_ID" | grep -v grep | awk '{print $2}')

if [ -z "$pid" ]; then
    echo "Error: Could not find PID for $BUNDLE_ID. Did the app crash?"
    exit 1
fi

echo "App running PID: $pid"
echo "Streaming logs..."

# Execute Log Stream
if [ -n "$GREP_FILTER" ]; then
    # Note: Using -D to filter by domain or -T for tags is also helpful in hilog
    hdc shell hilog -P "$pid" | grep -E "$GREP_FILTER"
else
    hdc shell hilog -P "$pid"
fi
