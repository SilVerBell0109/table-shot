# DeskShot (Desk View 캡처 앱) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 맥 내장 데스크 뷰 카메라로 책상을 찍어 PNG 저장 + 클립보드 복사까지 자동으로 해주는 네이티브 맥 앱을 만든다.

**Architecture:** 테스트 가능한 순수 로직은 `DeskShotKit` 라이브러리로, 카메라/핫키/UI 같은 플랫폼 의존 코드는 `DeskShot` 실행 타깃으로 분리한다. 실행 타깃은 라이브러리를 조립해 쓰고, 배포는 SPM 릴리스 빌드를 `.app` 번들로 감싸는 스크립트로 만든다.

**Tech Stack:** Swift, SwiftUI(`MenuBarExtra`), AVFoundation, ImageIO, Carbon(`RegisterEventHotKey`). 외부 패키지 의존성 없음. Swift Package Manager.

**Spec:** `docs/2026-11-03-deskview-capture-design.md`

## Global Constraints
- 배포 대상 **macOS 14.0+** (`Package.swift` platforms, `LSMinimumSystemVersion`).
- 외부 패키지 의존성 **0**. API 연동 **없음**.
- 카메라 소스는 내장 **`.deskViewCamera`** 전용. 모델명 하드코딩 금지 — 런타임 장치 탐지로 판별.
- 저장 포맷 **PNG**. 저장 폴더 기본 **`~/Pictures/DeskShots`**. 파일명 **`desk-YYYYMMDD-HHmmss.png`**.
- 전역 핫키 기본 **⌘⇧2**.
- 배포 **서명 없음(무료)**. `NSCameraUsageDescription`은 **한글** 문구.
- 앱은 메뉴바 중심(`LSUIElement = true`, Dock 아이콘 없음).

## Review Focus
- **세션 준비 전 캡처(최신 프레임 아직 없음)** → 저장하지 않고 명확히 실패해야 함. (Task 3 `test_capture_noFrame_throws`)
- **저장 폴더 쓰기 실패** → 클립보드 복사는 그래도 수행하고 오류를 알림. (Task 3 `test_capture_saveFailure_stillCopiesClipboard`)
- **저장 폴더가 아직 없음** → 자동 생성 후 저장. (Task 3 `test_capture_createsFolderIfMissing`)
- **미지원 맥(데스크 뷰 장치 없음)** → 안내 화면, 캡처 불가. (Task 1 `test_unsupported_whenAbsent` + Task 4 수동 확인)
- **카메라 권한 거부** → 설정 열기 안내 메시지. (Task 4 수동 확인 — 하드웨어/권한 의존이라 단위 테스트 불가)

---

## File Structure
```
Package.swift
Sources/
  DeskShotKit/              # 순수 로직 (단위 테스트 대상)
    DeskViewSupport.swift   # isDeskViewSupported(...)
    SettingsStore.swift     # UserDefaults 기반 설정
    CaptureService.swift    # 캡처 1회 오케스트레이션
    PngEncoder.swift        # CGImage -> PNG Data
    Ports.swift             # FileWriting / Clipboarding / Clock 프로토콜 + 에러
  DeskShot/                 # 앱/플랫폼 의존 (수동 검증)
    DeskShotApp.swift       # @main, MenuBarExtra, 지원 분기, 권한
    CameraManager.swift     # AVCaptureSession, 미리보기, 최신 프레임
    HotkeyManager.swift     # Carbon 전역 핫키
    CaptureCoordinator.swift# 실제 포트 주입 + 피드백
    PreviewWindow.swift     # 라이브 미리보기 + 찍기 버튼
    UnsupportedView.swift   # 미지원 안내
    SettingsView.swift      # 저장 폴더/핫키
    PlatformPorts.swift     # FileWriting/Clipboarding/Clock 실제 구현
Tests/
  DeskShotKitTests/
    DeskViewSupportTests.swift
    SettingsStoreTests.swift
    CaptureServiceTests.swift
    PngEncoderTests.swift
packaging/
  Info.plist
  make-app.sh
README.md
```

---

## Task 1: 패키지 골격 + 지원 판별 로직

**Files:**
- Create: `Package.swift`, `Sources/DeskShotKit/DeskViewSupport.swift`
- Test: `Tests/DeskShotKitTests/DeskViewSupportTests.swift`

**Interfaces:**
- Produces: `func isDeskViewSupported(availableDeviceTypeIDs: [String]) -> Bool`
  — `AVCaptureDevice.DeviceType.deskViewCamera.rawValue`(= `"AVCaptureDeviceTypeDeskViewCamera"`)가 목록에 있으면 `true`.

- [ ] **Step 1: 실패 테스트 작성** — `DeskViewSupportTests`
```swift
func test_supported_whenDeskViewTypePresent() {
    XCTAssertTrue(isDeskViewSupported(availableDeviceTypeIDs: [
        "AVCaptureDeviceTypeBuiltInWideAngleCamera",
        "AVCaptureDeviceTypeDeskViewCamera"]))
}
func test_unsupported_whenAbsent() {
    XCTAssertFalse(isDeskViewSupported(availableDeviceTypeIDs: [
        "AVCaptureDeviceTypeBuiltInWideAngleCamera"]))
}
```
- [ ] **Step 2: 실패 확인** — `swift test --filter DeskViewSupportTests` → 컴파일/심볼 없음으로 FAIL
- [ ] **Step 3: 구현** — `Package.swift`(platforms macOS 14, 타깃 `DeskShotKit`/`DeskShotKitTests`)와 `isDeskViewSupported(availableDeviceTypeIDs:)` 작성. 내부는 `contains("AVCaptureDeviceTypeDeskViewCamera")`.
- [ ] **Step 4: 통과 확인** — `swift test --filter DeskViewSupportTests` → PASS
- [ ] **Step 5: 커밋** — `feat: SPM 골격 + 데스크뷰 지원 판별`

---

## Task 2: 설정 저장소

**Files:**
- Create: `Sources/DeskShotKit/SettingsStore.swift`
- Test: `Tests/DeskShotKitTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct HotkeySpec: Equatable { var keyCode: UInt32; var modifiers: UInt32 }` + `static var defaultCapture: HotkeySpec` (⌘⇧2).
  - `final class SettingsStore { init(defaults: UserDefaults); var saveFolderURL: URL; var hotkey: HotkeySpec }` — 값 변경 시 `defaults`에 영속화.

- [ ] **Step 1: 실패 테스트 작성**
```swift
func test_defaultSaveFolder_isPicturesDeskShots() {
    let s = SettingsStore(defaults: makeEphemeralDefaults())
    XCTAssertEqual(s.saveFolderURL.lastPathComponent, "DeskShots")
    XCTAssertTrue(s.saveFolderURL.path.contains("/Pictures/"))
}
func test_persistsSaveFolder() {
    let d = makeEphemeralDefaults()
    SettingsStore(defaults: d).saveFolderURL = URL(fileURLWithPath: "/tmp/x")
    XCTAssertEqual(SettingsStore(defaults: d).saveFolderURL.path, "/tmp/x")
}
func test_defaultHotkey_isCmdShift2() {
    XCTAssertEqual(SettingsStore(defaults: makeEphemeralDefaults()).hotkey,
                   HotkeySpec.defaultCapture)
}
```
(`makeEphemeralDefaults` = `UserDefaults(suiteName: UUID().uuidString)!` 헬퍼)
- [ ] **Step 2: 실패 확인** — `swift test --filter SettingsStoreTests` → FAIL
- [ ] **Step 3: 구현** — `HotkeySpec`(⌘⇧2: keyCode `0x13`, modifiers = cmd|shift Carbon 값), `SettingsStore`. 기본 폴더는 `FileManager`의 Pictures 디렉터리 + `DeskShots`.
- [ ] **Step 4: 통과 확인** — PASS
- [ ] **Step 5: 커밋** — `feat: UserDefaults 기반 설정 저장소`

---

## Task 3: 캡처 서비스 (핵심)

**Files:**
- Create: `Sources/DeskShotKit/Ports.swift`, `Sources/DeskShotKit/PngEncoder.swift`, `Sources/DeskShotKit/CaptureService.swift`
- Test: `Tests/DeskShotKitTests/PngEncoderTests.swift`, `Tests/DeskShotKitTests/CaptureServiceTests.swift`

**Interfaces:**
- Consumes: `SettingsStore`(Task 2).
- Produces:
  - `protocol FileWriting { func ensureFolder(_ url: URL) throws; func write(_ data: Data, to url: URL) throws }`
  - `protocol Clipboarding { func writePNG(_ data: Data) }`
  - `protocol Clock { func now() -> Date }`
  - `enum CaptureError: Error, Equatable { case noFrame; case encodeFailed; case saveFailed }`
  - `enum PngEncoder { static func encode(_ image: CGImage) -> Data? }`
  - `final class CaptureService { init(frameProvider: @escaping () -> CGImage?, fileWriter: FileWriting, clipboard: Clipboarding, settings: SettingsStore, clock: Clock); func capture() throws -> URL }`
  - 캡처 순서: 프레임 획득(없으면 `noFrame`) → PNG 인코딩(실패 시 `encodeFailed`) → **클립보드 복사 먼저** → 폴더 보장 + 파일 쓰기(실패 시 `saveFailed`) → 저장 URL 반환. 파일명 `desk-yyyyMMdd-HHmmss.png`.

- [ ] **Step 1: 실패 테스트 작성** — `PngEncoderTests`
```swift
func test_encode_producesPngSignature() {
    let data = PngEncoder.encode(make1x1CGImage())
    XCTAssertNotNil(data)
    XCTAssertEqual(Array(data!.prefix(4)), [0x89, 0x50, 0x4E, 0x47]) // \x89PNG
}
```
- [ ] **Step 2: 실패 확인** — `swift test --filter PngEncoderTests` → FAIL
- [ ] **Step 3: 구현** — `PngEncoder.encode`는 ImageIO `CGImageDestinationCreateWithData(..., UTType.png ...)`로 인코딩. `make1x1CGImage()` 헬퍼는 `CGContext`로 1x1 생성.
- [ ] **Step 4: 통과 확인** — PASS
- [ ] **Step 5: 실패 테스트 작성** — `CaptureServiceTests` (스파이 `FileWriting`/`Clipboarding`, 고정 `Clock`, 임시 `SettingsStore`)
```swift
func test_capture_savesAndCopies_returnsExpectedURL() throws {
    let url = try sut.capture()   // clock = 2026-11-03 17:19:00, folder=/tmp/ds
    XCTAssertEqual(url.lastPathComponent, "desk-20261103-171900.png")
    XCTAssertTrue(fileSpy.wrote(to: url))
    XCTAssertTrue(clipSpy.called)
}
func test_capture_noFrame_throws() {
    sutWithNilFrame()
    XCTAssertThrowsError(try sut.capture()) { XCTAssertEqual($0 as? CaptureError, .noFrame) }
    XCTAssertFalse(fileSpy.anyWrite); XCTAssertFalse(clipSpy.called)
}
func test_capture_saveFailure_stillCopiesClipboard() {
    fileSpy.failOnWrite = true
    XCTAssertThrowsError(try sut.capture()) { XCTAssertEqual($0 as? CaptureError, .saveFailed) }
    XCTAssertTrue(clipSpy.called) // 저장 실패해도 클립보드는 시도됨
}
func test_capture_createsFolderIfMissing() throws {
    _ = try sut.capture()
    XCTAssertTrue(fileSpy.ensuredFolders.contains(settings.saveFolderURL))
}
```
- [ ] **Step 6: 실패 확인** — `swift test --filter CaptureServiceTests` → FAIL
- [ ] **Step 7: 구현** — `Ports.swift`, `CaptureService.capture()`를 위 순서대로. 파일명 포맷터는 `"yyyyMMdd-HHmmss"`(POSIX 로캘, 로컬 타임존).
- [ ] **Step 8: 통과 확인** — `swift test` 전체 PASS
- [ ] **Step 9: 커밋** — `feat: PNG 인코더 + 캡처 서비스(저장/클립보드/에러)`

---

## Task 4: 앱 골격 + 지원 분기 + 권한

**Files:**
- Create: `Sources/DeskShot/DeskShotApp.swift`, `Sources/DeskShot/UnsupportedView.swift`, `packaging/Info.plist`; Modify: `Package.swift`(실행 타깃 `DeskShot` 추가, `DeskShotKit` 의존)
- Test: 자동 테스트 없음 — **수동 검증**(하드웨어/권한/UI 의존)

**Interfaces:**
- Consumes: `isDeskViewSupported`(Task 1).
- Produces: 실행 가능한 앱. 시작 시 AVFoundation `DiscoverySession(.deskViewCamera)`로 장치 타입 ID 수집 → `isDeskViewSupported` 분기. 미지원이면 `UnsupportedView`, 지원이면 메뉴바(`MenuBarExtra`)로 진입. 카메라 권한 `AVCaptureDevice.requestAccess` 요청.

- [ ] **Step 1: 구현** — `Package.swift`에 `executableTarget(name: "DeskShot", dependencies: ["DeskShotKit"])`. `DeskShotApp`(@main, `MenuBarExtra`), 지원 분기, 권한 요청. `UnsupportedView`(안내 문구 + 종료). `Info.plist`(CFBundleIdentifier `com.silverbell.deskshot`, `NSCameraUsageDescription` 한글, `LSUIElement`=true, `LSMinimumSystemVersion` 14.0).
- [ ] **Step 2: 수동 검증** — `swift build` 성공. (전체 번들 실행은 Task 8의 `make-app.sh` 후 M4에서 확인)
- [ ] **Step 3: 커밋** — `feat: 앱 골격 + 지원 분기 + 카메라 권한`

---

## Task 5: CameraManager (세션/미리보기/최신 프레임)

**Files:**
- Create: `Sources/DeskShot/CameraManager.swift`
- Test: 수동 검증

**Interfaces:**
- Produces: `final class CameraManager { func start(); func stop(); var previewLayer: AVCaptureVideoPreviewLayer; func latestFrame() -> CGImage? }`
  — `.deskViewCamera` 입력 + `AVCaptureVideoDataOutput`(BGRA). 델리게이트가 최신 `CVPixelBuffer`를 스레드 안전하게 보관, `latestFrame()`은 `CIContext`로 `CGImage` 변환.

- [ ] **Step 1: 구현** — 위 인터페이스대로. 데스크 뷰 장치 입력 연결, 미리보기 레이어, 최신 프레임 보관(락/시리얼 큐).
- [ ] **Step 2: 수동 검증** — Task 7의 미리보기 창에서 라이브 영상 확인(선행 빌드만 여기서).
- [ ] **Step 3: 커밋** — `feat: CameraManager 세션/미리보기/프레임 캡처`

---

## Task 6: HotkeyManager (전역 핫키)

**Files:**
- Create: `Sources/DeskShot/HotkeyManager.swift`
- Test: 수동 검증

**Interfaces:**
- Consumes: `HotkeySpec`(Task 2).
- Produces: `final class HotkeyManager { func register(_ spec: HotkeySpec, onTrigger: @escaping () -> Void); func unregister() }` — Carbon `RegisterEventHotKey` + `InstallEventHandler`.

- [ ] **Step 1: 구현** — 위 인터페이스대로. 기본 ⌘⇧2 등록, 콜백 호출.
- [ ] **Step 2: 수동 검증** — 다른 앱이 떠 있어도 핫키로 캡처가 호출되는지(Task 7 연결 후).
- [ ] **Step 3: 커밋** — `feat: Carbon 전역 핫키`

---

## Task 7: 미리보기 창 + 캡처 트리거 배선

**Files:**
- Create: `Sources/DeskShot/CaptureCoordinator.swift`, `Sources/DeskShot/PreviewWindow.swift`, `Sources/DeskShot/SettingsView.swift`, `Sources/DeskShot/PlatformPorts.swift`; Modify: `Sources/DeskShot/DeskShotApp.swift`(메뉴 항목/창 연결)
- Test: 수동 검증

**Interfaces:**
- Consumes: `CaptureService`(Task 3), `CameraManager`(Task 5), `HotkeyManager`(Task 6), `SettingsStore`(Task 2).
- Produces:
  - `PlatformPorts`: `FileWriting`(FileManager), `Clipboarding`(NSPasteboard — PNG 데이터 + NSImage 둘 다 기록), `Clock`(시스템 시간) 실제 구현.
  - `CaptureCoordinator`: `CaptureService`를 실제 포트로 조립, `func trigger()`가 캡처 + **피드백(셔터음 `NSSound` + 간단 알림/가장자리 플래시)** 수행, 실패 시 사용자 알림.
  - `PreviewWindow`: `previewLayer`를 `NSViewRepresentable`로 래핑 + 큰 "찍기" 버튼 → `coordinator.trigger()`.
  - 메뉴바 항목: 찍기 / 미리보기 열기 / 저장 폴더 열기 / 설정 / 종료.
  - 핫키·메뉴바·버튼 세 경로 모두 `coordinator.trigger()`로 수렴.

- [ ] **Step 1: 구현** — 위 구성 요소 작성 및 세 트리거 배선. `SettingsView`(폴더 선택, 핫키 표시).
- [ ] **Step 2: 수동 검증** — (Task 8 번들 후) 미리보기 영상 표시, 세 경로 모두 캡처 → `~/Pictures/DeskShots`에 PNG 생성 + ⌘V 붙여넣기 동작(카톡/챗봇).
- [ ] **Step 3: 커밋** — `feat: 미리보기 창 + 세 경로 캡처 배선 + 피드백`

---

## Task 8: .app 패키징 + README

**Files:**
- Create: `packaging/make-app.sh`, `README.md`
- Test: 수동 검증

**Interfaces:**
- Consumes: 모든 선행 타깃.
- Produces: `make-app.sh`가 `swift build -c release` 후 `DeskShot.app/Contents/{MacOS,Resources}`를 조립(실행 파일 + `Info.plist` 복사). `README`에 빌드/설치/첫 실행 우클릭→열기/카메라 권한/핫키 안내.

- [ ] **Step 1: 구현** — `make-app.sh`(번들 조립, 실행 권한), `README.md`(한글 안내).
- [ ] **Step 2: 수동 검증** — `./packaging/make-app.sh` → `DeskShot.app` 생성. M4 Air에서 우클릭→열기 → 권한 허용 → Task 4~7의 수동 검증 항목 전체 통과.
- [ ] **Step 3: 커밋** — `feat: .app 패키징 스크립트 + README`

---

## 비고 (실행 특성)
- Task 1~3은 완전 자동 테스트(TDD). Task 4~8은 카메라/핫키/UI 하드웨어 의존이라 **사용자 M4에서 수동 검증**이 필수. 서브에이전트는 실제 카메라 테스트 불가.
