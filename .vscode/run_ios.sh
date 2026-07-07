#!/bin/bash
set -e

# Change directory to the workspace root
cd "$(dirname "$0")/.."

echo "=========================================="
echo "Starting iOS Build and Run Process..."
echo "=========================================="

# 1. Start the Simulator application in the background
echo "Opening iOS Simulator app..."
open -a Simulator

# 2. Get the ID of a booted or available simulator that meets the deployment target
MIN_VERSION=$(grep "IPHONEOS_DEPLOYMENT_TARGET" frontend/Life-XP-iOS.xcodeproj/project.pbxproj | head -n 1 | sed -E 's/.*= ([0-9.]+);/\1/')
if [ -z "$MIN_VERSION" ]; then
    MIN_VERSION="26.2"
fi

echo "Minimum iOS version required: $MIN_VERSION"
echo "Searching for a compatible simulator..."

BOOTED_SIM=$(xcrun simctl list devices -j | python3 -c "
import json, sys
min_ver_str = '$MIN_VERSION'
def parse_version(runtime_key):
    parts = runtime_key.split('.')[-1].replace('iOS-', '').split('-')
    try:
        return tuple(int(p) for p in parts if p.isdigit())
    except:
        return (0,)
min_ver = tuple(int(p) for p in min_ver_str.split('.'))
try:
    data = json.load(sys.stdin)
    devices = data.get('devices', {})
    booted_compatible = []
    shutdown_compatible = []
    for runtime, dev_list in devices.items():
        if 'SimRuntime.iOS' not in runtime:
            continue
        ver = parse_version(runtime)
        if ver < min_ver:
            continue
        for dev in dev_list:
            if not dev.get('isAvailable', False):
                continue
            is_iphone = 'iPhone' in dev.get('name', '')
            item = (is_iphone, ver, dev.get('udid'), dev.get('name'))
            if dev.get('state') == 'Booted':
                booted_compatible.append(item)
            else:
                shutdown_compatible.append(item)
    booted_compatible.sort(key=lambda x: (x[0], x[1]), reverse=True)
    shutdown_compatible.sort(key=lambda x: (x[0], x[1]), reverse=True)
    if booted_compatible:
        print(booted_compatible[0][2])
    elif shutdown_compatible:
        print(shutdown_compatible[0][2])
    else:
        print('')
except Exception as e:
    sys.stderr.write(f'Error: {e}\n')
")

if [ -z "$BOOTED_SIM" ]; then
    echo "Error: No available iOS simulator found that supports iOS $MIN_VERSION or higher."
    exit 1
fi

# Boot the simulator if it is not currently booted
if ! xcrun simctl list devices | grep "$BOOTED_SIM" | grep -q "Booted"; then
    echo "Booting simulator (ID: $BOOTED_SIM)..."
    xcrun simctl boot "$BOOTED_SIM"
fi

echo "Using active simulator: $BOOTED_SIM"

# 3. Build the iOS app for the simulator
echo "Building iOS App using xcodebuild..."
xcodebuild \
    -project frontend/Life-XP-iOS.xcodeproj \
    -scheme Life-XP-iOS \
    -sdk iphonesimulator \
    -configuration Debug \
    -derivedDataPath frontend/build/DerivedData \
    -quiet

# 4. Install the app on the booted simulator
APP_PATH="frontend/build/DerivedData/Build/Products/Debug-iphonesimulator/Life-XP-iOS.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Built app not found at $APP_PATH"
    exit 1
fi

echo "Installing app onto simulator..."
xcrun simctl install "$BOOTED_SIM" "$APP_PATH"

# 5. Launch the app on the booted simulator
BUNDLE_ID="blc.Life-XP-iOS"
echo "Launching app ($BUNDLE_ID) on simulator..."
xcrun simctl launch "$BOOTED_SIM" "$BUNDLE_ID"

echo "=========================================="
echo "Successfully launched Life-XP-iOS!"
echo "=========================================="
