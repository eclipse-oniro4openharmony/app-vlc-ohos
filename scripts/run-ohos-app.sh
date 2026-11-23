#!/bin/bash

BUNDLE_ID="org.oniroproject.vlc"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.." || exit 1

# Copy libVLC and its plugins from vlc_install/ into entry/libs/arm64-v8a
bash "$SCRIPT_DIR/build_native.sh" stage || { echo "Staging the native libraries failed"; exit 1; }

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
