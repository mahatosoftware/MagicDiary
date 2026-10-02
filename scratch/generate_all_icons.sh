#!/bin/bash
SRC_IMAGE="/Users/debasishmahato/.gemini/antigravity/brain/5e190818-0e27-4a17-9a69-285f374c7ec1/.user_uploaded/media_1790693301264.png"
PROJECT_DIR="/Volumes/DebasishApple/DeveloperExt/Apps/MagicDiary"

echo "Generating icons from $SRC_IMAGE..."

# 1. In-App Assets
mkdir -p "$PROJECT_DIR/assets/images"
sips -z 512 512 "$SRC_IMAGE" --out "$PROJECT_DIR/assets/images/app_logo.png"

# 2. Android Mipmaps
RES_DIR="$PROJECT_DIR/android/app/src/main/res"

mkdir -p "$RES_DIR/mipmap-mdpi"
sips -z 48 48 "$SRC_IMAGE" --out "$RES_DIR/mipmap-mdpi/ic_launcher.png"
sips -z 48 48 "$SRC_IMAGE" --out "$RES_DIR/mipmap-mdpi/ic_launcher_round.png"

mkdir -p "$RES_DIR/mipmap-hdpi"
sips -z 72 72 "$SRC_IMAGE" --out "$RES_DIR/mipmap-hdpi/ic_launcher.png"
sips -z 72 72 "$SRC_IMAGE" --out "$RES_DIR/mipmap-hdpi/ic_launcher_round.png"

mkdir -p "$RES_DIR/mipmap-xhdpi"
sips -z 96 96 "$SRC_IMAGE" --out "$RES_DIR/mipmap-xhdpi/ic_launcher.png"
sips -z 96 96 "$SRC_IMAGE" --out "$RES_DIR/mipmap-xhdpi/ic_launcher_round.png"

mkdir -p "$RES_DIR/mipmap-xxhdpi"
sips -z 144 144 "$SRC_IMAGE" --out "$RES_DIR/mipmap-xxhdpi/ic_launcher.png"
sips -z 144 144 "$SRC_IMAGE" --out "$RES_DIR/mipmap-xxhdpi/ic_launcher_round.png"

mkdir -p "$RES_DIR/mipmap-xxxhdpi"
sips -z 192 192 "$SRC_IMAGE" --out "$RES_DIR/mipmap-xxxhdpi/ic_launcher.png"
sips -z 192 192 "$SRC_IMAGE" --out "$RES_DIR/mipmap-xxxhdpi/ic_launcher_round.png"

# 3. iOS Icons
IOS_DIR="$PROJECT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$IOS_DIR"

sips -z 20 20 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-20x20@1x.png"
sips -z 40 40 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-20x20@2x.png"
sips -z 60 60 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-20x20@3x.png"
sips -z 29 29 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-29x29@1x.png"
sips -z 58 58 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-29x29@2x.png"
sips -z 87 87 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-29x29@3x.png"
sips -z 40 40 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-40x40@1x.png"
sips -z 80 80 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-40x40@2x.png"
sips -z 120 120 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-40x40@3x.png"
sips -z 120 120 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-60x60@2x.png"
sips -z 180 180 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-60x60@3x.png"
sips -z 76 76 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-76x76@1x.png"
sips -z 152 152 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-76x76@2x.png"
sips -z 167 167 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-83.5x83.5@2x.png"
sips -z 1024 1024 "$SRC_IMAGE" --out "$IOS_DIR/Icon-App-1024x1024@1x.png"

# 4. Web Icons
WEB_DIR="$PROJECT_DIR/web/icons"
mkdir -p "$WEB_DIR"

sips -z 192 192 "$SRC_IMAGE" --out "$WEB_DIR/Icon-192.png"
sips -z 512 512 "$SRC_IMAGE" --out "$WEB_DIR/Icon-512.png"
sips -z 192 192 "$SRC_IMAGE" --out "$WEB_DIR/Icon-maskable-192.png"
sips -z 512 512 "$SRC_IMAGE" --out "$WEB_DIR/Icon-maskable-512.png"
sips -z 64 64 "$SRC_IMAGE" --out "$PROJECT_DIR/web/favicon.png"

echo "All app launcher icons generated successfully!"
