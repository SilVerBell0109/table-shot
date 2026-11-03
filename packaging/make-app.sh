#!/usr/bin/env bash
# DeskShot.app 번들을 조립한다. (서명 없음 — 첫 실행 시 우클릭→열기)
set -euo pipefail

cd "$(dirname "$0")/.."

APP="DeskShot.app"
BIN_NAME="DeskShot"

echo "==> swift build -c release"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$BIN_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "실행 파일을 찾을 수 없습니다: $BIN_PATH" >&2
    exit 1
fi

echo "==> 번들 조립: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"
chmod +x "$APP/Contents/MacOS/$BIN_NAME"
cp packaging/Info.plist "$APP/Contents/Info.plist"

# ad-hoc 서명: 번들에 안정적인 코드 서명 신원을 부여해 재빌드마다 카메라 권한(TCC)이
# 초기화되는 것을 막는다. (배포 서명이 아니므로 첫 실행은 여전히 우클릭→열기)
echo "==> ad-hoc 코드 서명"
codesign --force --deep --sign - "$APP"

echo "==> 완료: $(pwd)/$APP"
echo "    첫 실행: Finder에서 $APP 우클릭 → 열기 → '열기' 확인"
