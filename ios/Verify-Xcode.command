#!/bin/bash
# Local, unsigned compilation only. Does not upload data, install apps, change
# the selected Xcode globally, or require a Flutter installation.
set -u
set -o pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
project_dir="$PWD"
result_dir="$project_dir/CompatibilityChecks/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$result_dir" || exit 1

minimum_major=26
selected_developer=""
best_major=0
best_minor=0
candidates=()
if [ -n "${DEVELOPER_DIR:-}" ]; then
  candidates+=("$DEVELOPER_DIR")
fi
active_developer="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
if [ -n "$active_developer" ]; then
  candidates+=("$active_developer")
fi
candidates+=("/Applications/Xcode.app/Contents/Developer")
for app in /Applications/Xcode_*.app; do
  if [ -d "$app/Contents/Developer" ]; then
    candidates+=("$app/Contents/Developer")
  fi
done
candidates+=("$HOME/Downloads/Xcode.app/Contents/Developer")

for candidate in "${candidates[@]}"; do
  if [ ! -x "$candidate/usr/bin/xcodebuild" ]; then continue; fi
  version="$(DEVELOPER_DIR="$candidate" "$candidate/usr/bin/xcodebuild" -version 2>/dev/null || true)"
  if [[ "$version" =~ ^Xcode\ ([0-9]+)\.([0-9]+) ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
  else
    continue
  fi
  if [ "$major" -lt "$minimum_major" ]; then continue; fi
  if [ "$major" -gt "$best_major" ] || { [ "$major" -eq "$best_major" ] && [ "$minor" -gt "$best_minor" ]; }; then
    selected_developer="$candidate"
    best_major="$major"
    best_minor="$minor"
  fi
done

if [ -z "$selected_developer" ]; then
  printf '%s\n' '未找到 Xcode 26 或更新版本（建议 Xcode 27）。' \
    '自 2026-04-28 起，App Store 上传要求 Xcode 26 或更新版本与 iOS 26 SDK 或更新版本。' \
    '请先安装 Xcode 26/27 并打开一次完成组件安装。' \
    '若安装在其他目录，可运行：DEVELOPER_DIR="实际 Xcode.app/Contents/Developer 路径" /bin/bash "本脚本路径"' \
    | tee "$result_dir/summary.txt"
  exit 2
fi
export DEVELOPER_DIR="$selected_developer"
export FLUTTER_ROOT=/not-installed
xcodebuild -version > "$result_dir/xcode-version.txt" 2>&1
xcrun swiftc --version > "$result_dir/swift-version.txt" 2>&1
xcodebuild -showsdks > "$result_dir/sdks.txt" 2>&1
sw_vers > "$result_dir/macos-version.txt"

sdk_major="$(/usr/bin/grep -Eo 'iphoneos[0-9]+' "$result_dir/sdks.txt" | /usr/bin/sed 's/^iphoneos//' | /usr/bin/sort -n | /usr/bin/tail -1)"
sdk_line="$(/usr/bin/grep -E "iphoneos${sdk_major}" "$result_dir/sdks.txt" | /usr/bin/tail -1)"
sdk_status=0
if [ -z "$sdk_major" ] || [ "$sdk_major" -lt "$minimum_major" ]; then
  sdk_status=1
fi
host_arch="$(/usr/bin/uname -m)"

framework_status=0
if [ -d "$project_dir/Frameworks" ]; then
  {
    for container in "$project_dir/Frameworks"/*.xcframework; do
      [ -d "$container" ] || continue
      printf '== %s ==\n' "$(basename "$container")"
      /usr/bin/codesign -dv --verbose=4 "$container" 2>&1
      /usr/bin/codesign --verify --strict --verbose=2 "$container" 2>&1
      for inner in "$container"/*/*.framework; do
        [ -d "$inner" ] || continue
        printf -- '-- %s --\n' "$(basename "$inner")"
        /usr/bin/codesign -dv --verbose=4 "$inner" 2>&1 | /usr/bin/grep -E 'Identifier|TeamIdentifier|Authority' || true
        /usr/bin/codesign --verify --strict --verbose=2 "$inner" 2>&1
      done
    done
  } > "$result_dir/framework-signatures.txt" 2>&1
  # Every Flutter inner slice must still carry Google's publisher signature.
  for inner in "$project_dir/Frameworks/Flutter.xcframework"/*/*.framework; do
    [ -d "$inner" ] || continue
    if ! /usr/bin/codesign --verify --strict "$inner" >/dev/null 2>&1; then
      framework_status=1
    fi
  done
  if ! /usr/bin/codesign --verify --strict "$project_dir/Frameworks/Flutter.xcframework" >/dev/null 2>&1; then
    framework_status=1
  fi
fi

printf '%s\n' '正在读取工程，然后编译 iPhone 和 Apple Silicon 模拟器版本。首次运行需要几分钟。'
xcodebuild -project "$project_dir/Teno.xcodeproj" -list -json > "$result_dir/project.json" 2> "$result_dir/project-errors.txt"
project_status=$?
device_status=125
simulator_status=125
simulator_note=''
if [ "$project_status" -eq 0 ]; then
  xcodebuild -project "$project_dir/Teno.xcodeproj" -scheme Teno -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$result_dir/DerivedData" \
    CODE_SIGNING_ALLOWED=NO build > "$result_dir/device-build.log" 2>&1
  device_status=$?
  if [ "$host_arch" = 'arm64' ]; then
    xcodebuild -project "$project_dir/Teno.xcodeproj" -scheme Teno -configuration Debug \
      -destination 'generic/platform=iOS Simulator' -derivedDataPath "$result_dir/DerivedData" \
      ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build > "$result_dir/simulator-build.log" 2>&1
    simulator_status=$?
  else
    # The shipped Flutter simulator slice is arm64-only (built on the arm64
    # Xcode 27 runner), so an Intel Mac can build for iPhone but not run it.
    simulator_status=0
    simulator_note='已跳过：包内 Flutter 模拟器切片仅含 arm64'
    printf '%s\n' "$simulator_note" > "$result_dir/simulator-build.log"
  fi
fi
{
  printf 'Teno iOS 1.0 / Build15 — Xcode 26+ 实际编译检查\n\n'
  cat "$result_dir/xcode-version.txt" "$result_dir/swift-version.txt" "$result_dir/macos-version.txt"
  printf '\n本机架构：%s\niPhone SDK：%s\n' "$host_arch" "$(printf '%s' "$sdk_line" | /usr/bin/sed -E 's/^[[:space:]]*//')"
  printf '工程读取退出码：%s\niPhone 编译退出码：%s\nApple Silicon 模拟器编译退出码：%s%s\n' \
    "$project_status" "$device_status" "$simulator_status" "${simulator_note:+（$simulator_note）}"
  printf 'iPhone SDK 版本检查：%s（0 通过，1 失败）\n' "$sdk_status"
  printf 'Flutter 框架签名检查：%s（0 通过，1 失败）\n' "$framework_status"
  printf '\n0 表示通过；125 表示上一步失败而未运行。\n结果目录：%s\n' "$result_dir"
  printf '\n本检查不包含 Apple 签名、iPhone 安装、实体录音卡或后台行为验收。\n'
} | tee "$result_dir/summary.txt"
for log in "$result_dir/project-errors.txt" "$result_dir/device-build.log" "$result_dir/simulator-build.log" "$result_dir/framework-signatures.txt"; do
  if [ -f "$log" ]; then
    /usr/bin/grep -n -E 'error:|BUILD FAILED|BUILD SUCCEEDED|invalid signature|not signed' "$log" | /usr/bin/head -30 || true
  fi
done
/usr/bin/open -R "$result_dir/summary.txt" >/dev/null 2>&1 || true
if [ "$project_status" -eq 0 ] && [ "$device_status" -eq 0 ] && [ "$simulator_status" -eq 0 ] \
  && [ "$sdk_status" -eq 0 ] && [ "$framework_status" -eq 0 ]; then exit 0; else exit 1; fi
