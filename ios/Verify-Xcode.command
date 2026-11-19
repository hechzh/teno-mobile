#!/bin/bash
# Local, unsigned compilation only. Does not upload data, install apps, change
# the selected Xcode globally, or require a Flutter installation.
set -u
set -o pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
project_dir="$PWD"
result_dir="$project_dir/CompatibilityChecks/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$result_dir" || exit 1

selected_developer=""
if [ -n "${DEVELOPER_DIR:-}" ]; then
  candidates=("$DEVELOPER_DIR")
else
  active_developer="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
  candidates=("$active_developer" "/Applications/Xcode.app/Contents/Developer"
    "/Applications/Xcode_14.3.1.app/Contents/Developer"
    "$HOME/Downloads/Xcode.app/Contents/Developer"
    "$HOME/Downloads/Xcode_14.3.1.app/Contents/Developer")
fi
for candidate in "${candidates[@]}"; do
  if [ -x "$candidate/usr/bin/xcodebuild" ]; then
    version="$(DEVELOPER_DIR="$candidate" "$candidate/usr/bin/xcodebuild" -version 2>/dev/null || true)"
    if [[ "$version" == 'Xcode 14.3.1'* ]]; then selected_developer="$candidate"; break; fi
  fi
done
if [ -z "$selected_developer" ]; then
  printf '%s\n' '未找到 Xcode 14.3.1。请先启动一次 Xcode 完成组件安装。' \
    '若安装在其他目录，可运行：DEVELOPER_DIR="实际 Xcode.app/Contents/Developer 路径" /bin/bash "本脚本路径"' | tee "$result_dir/summary.txt"
  exit 2
fi
export DEVELOPER_DIR="$selected_developer"
export FLUTTER_ROOT=/not-installed
xcodebuild -version > "$result_dir/xcode-version.txt" 2>&1
xcrun swiftc --version > "$result_dir/swift-version.txt" 2>&1
xcodebuild -showsdks > "$result_dir/sdks.txt" 2>&1
sw_vers > "$result_dir/macos-version.txt"

printf '%s\n' '正在读取工程，然后编译 iPhone 和 Intel 模拟器版本。首次运行需要几分钟。'
xcodebuild -project "$project_dir/Teno.xcodeproj" -list -json > "$result_dir/project.json" 2> "$result_dir/project-errors.txt"
project_status=$?
device_status=125
simulator_status=125
if [ "$project_status" -eq 0 ]; then
  xcodebuild -project "$project_dir/Teno.xcodeproj" -scheme Teno -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$result_dir/DerivedData" \
    CODE_SIGNING_ALLOWED=NO build > "$result_dir/device-build.log" 2>&1
  device_status=$?
  xcodebuild -project "$project_dir/Teno.xcodeproj" -scheme Teno -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$result_dir/DerivedData" \
    ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build > "$result_dir/intel-simulator-build.log" 2>&1
  simulator_status=$?
fi
{
  printf 'Teno iOS 1.2.0 / Build17 — Xcode 14.3.1 实际编译检查\n\n'
  cat "$result_dir/xcode-version.txt" "$result_dir/swift-version.txt" "$result_dir/macos-version.txt"
  printf '\n工程读取退出码：%s\niPhone 编译退出码：%s\nIntel 模拟器编译退出码：%s\n' "$project_status" "$device_status" "$simulator_status"
  printf '\n0 表示通过；125 表示上一步失败而未运行。\n结果目录：%s\n' "$result_dir"
  printf '\n本检查不包含 Apple 签名、iPhone 安装、实体录音卡或后台行为验收。\n'
} | tee "$result_dir/summary.txt"
for log in "$result_dir/project-errors.txt" "$result_dir/device-build.log" "$result_dir/intel-simulator-build.log"; do
  if [ -f "$log" ]; then
    /usr/bin/grep -n -E 'error:|BUILD FAILED|BUILD SUCCEEDED' "$log" | /usr/bin/head -30 || true
  fi
done
/usr/bin/open -R "$result_dir/summary.txt"
if [ "$project_status" -eq 0 ] && [ "$device_status" -eq 0 ] && [ "$simulator_status" -eq 0 ]; then exit 0; else exit 1; fi
