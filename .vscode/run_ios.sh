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

# 2. Get the ID of the booted simulator, or find/boot a default one
echo "Checking for active simulator..."
BOOTED_SIM=$(xcrun simctl list devices | grep "Booted" | head -n 1 | sed -E 's/.* \(([0-9A-F-]+)\) \(Booted\)/\1/')

if [ -z "$BOOTED_SIM" ]; then
    # No simulator is booted. Let's look for a standard iPhone simulator (e.g. iPhone 15 or 16)
    echo "No booted simulator found. Searching for available simulators..."
    DEFAULT_SIM=$(xcrun simctl list devices | grep -E "iPhone (15|16|17|SE)" | grep -v "unavailable" | head -n 1 | sed -E 's/.* \(([0-9A-F-]+)\) .*/\1/')
    
    if [ -z "$DEFAULT_SIM" ]; then
        # Fallback to any available simulator device
        DEFAULT_SIM=$(xcrun simctl list devices | grep -E "\(" | grep -v "unavailable" | grep -v "Device Types" | grep -v "Booted" | head -n 1 | sed -E 's/.* \(([0-9A-F-]+)\) .*/\1/')
    fi
    
    if [ -n "$DEFAULT_SIM" ]; then
        echo "Booting simulator (ID: $DEFAULT_SIM)..."
        xcrun simctl boot "$DEFAULT_SIM"
        BOOTED_SIM="$DEFAULT_SIM"
    else
        echo "Error: No available iOS simulator found. Please open Xcode and install a simulator."
        exit 1
    fi
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
