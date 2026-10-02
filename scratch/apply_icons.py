import os
import shutil
import sys

project_dir = "/Volumes/DebasishApple/DeveloperExt/Apps/MagicDiary"
icons_dir = os.path.join(project_dir, "app_icons")

if not os.path.exists(icons_dir):
    print(f"Error: {icons_dir} does not exist. Please copy easyappicon folder there first.")
    sys.exit(1)

print(f"Scanning {icons_dir}...")

# Check for android icons
android_res_dir = os.path.join(project_dir, "android/app/src/main/res")
ios_assets_dir = os.path.join(project_dir, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
web_icons_dir = os.path.join(project_dir, "web/icons")
web_favicon = os.path.join(project_dir, "web/favicon.png")

# Find Android mipmap folders
found_android = False
found_ios = False

for root, dirs, files in os.walk(icons_dir):
    # Android mipmaps
    if any(d.startswith("mipmap-") for d in dirs):
        for d in dirs:
            if d.startswith("mipmap-"):
                src_mipmap = os.path.join(root, d)
                dst_mipmap = os.path.join(android_res_dir, d)
                os.makedirs(dst_mipmap, exist_ok=True)
                for item in os.listdir(src_mipmap):
                    s = os.path.join(src_mipmap, item)
                    d_file = os.path.join(dst_mipmap, item)
                    if os.path.isfile(s):
                        shutil.copy2(s, d_file)
                        print(f"Copied Android icon: {item} -> {d}")
                        found_android = True

    # iOS AppIcon.appiconset
    if os.path.basename(root) == "AppIcon.appiconset":
        os.makedirs(ios_assets_dir, exist_ok=True)
        for item in os.listdir(root):
            s = os.path.join(root, item)
            d_file = os.path.join(ios_assets_dir, item)
            if os.path.isfile(s):
                shutil.copy2(s, d_file)
                print(f"Copied iOS icon: {item}")
                found_ios = True

    # Web icons / 512.png / 192.png / favicon.png
    for f in files:
        if "512" in f and f.endswith(".png"):
            os.makedirs(web_icons_dir, exist_ok=True)
            shutil.copy2(os.path.join(root, f), os.path.join(web_icons_dir, "Icon-512.png"))
            shutil.copy2(os.path.join(root, f), web_favicon)
            print(f"Copied Web icon (512x512): {f}")
        elif "192" in f and f.endswith(".png"):
            os.makedirs(web_icons_dir, exist_ok=True)
            shutil.copy2(os.path.join(root, f), os.path.join(web_icons_dir, "Icon-192.png"))
            print(f"Copied Web icon (192x192): {f}")

print("Icon application script finished.")
