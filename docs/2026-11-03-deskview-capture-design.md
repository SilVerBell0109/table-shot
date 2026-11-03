# Desk View 캡처 앱 — 설계 문서

작성일: 2026-11-03
상태: 승인됨 (사용자 설계 승인 완료, 구현 계획 작성 전)

## 1. 목적 / 성공 기준
맥 **내장 데스크 뷰 카메라**로 책상 위 종이·아이패드를 빠르게 찍어서,
**클립보드에 복사 + 지정 폴더에 PNG 저장**까지 자동으로 해주는 네이티브 맥 앱.
찍은 뒤 사용자가 챗봇·카톡 등에 직접 붙여넣어 활용한다.

**성공 기준**
- 핫키/메뉴바/미리보기 창 버튼 중 어느 것으로든 1초 내 캡처가 끝난다.
- 캡처 즉시 ⌘V로 다른 앱에 바로 붙여넣을 수 있다.
- 지정 폴더에 PNG 파일이 남는다.
- 지원 안 되는 맥에서는 혼란 없이 안내 메시지가 뜬다.

## 2. 범위
### 포함 (v1)
- 내장 데스크 뷰 카메라 전용.
- 캡처 트리거 3종: 전역 핫키 / 메뉴바 버튼 / 미리보기 창 버튼.
- 캡처 동작: PNG 폴더 저장 + 클립보드 복사 (둘 다).
- 라이브 미리보기 창.
- 설정: 저장 폴더, 핫키.
- 지원 여부 자동 판별 + 미지원 안내.

### 제외 (비목표)
- LLM/챗봇 API 연동 (전부 수동).
- 카톡 직접 전송 (공유 시트/클립보드로 대체, 사용자가 수동).
- 아이폰 연속성·외장캠 소스 선택.
- 커스텀 원근 보정(모든 웹캠 지원) — **향후 확장 후보**로만 기록.
- OCR, PDF 묶음, 자동 감지 촬영.

## 3. 지원 기종 / 판별 방식
내장 데스크 뷰 = 12MP 센터 스테이지 카메라 탑재 맥
(iMac M4, MacBook Air M4+, MacBook Pro M4/Pro/Max+).

**모델명 하드코딩 금지.** 실행 시 `AVCaptureDevice.DiscoverySession`으로
`.deskViewCamera` 타입 장치 존재 여부로 판별한다. (신기종 자동 지원, 정확)
스파이크로 사용자 M4 Air에서 장치 노출 확인 완료.

## 4. 기술 스택
- Swift + SwiftUI. 배포 대상 **macOS 14.0+** (지원 기종 전부 충족).
- 외부 패키지 의존성 없음.
- 전역 핫키: macOS 내장 **Carbon `RegisterEventHotKey`** (Accessibility 권한 불필요).
- 메뉴바: `MenuBarExtra`. 앱은 메뉴바 중심(`LSUIElement = true`, Dock 아이콘 없음).

## 5. 구성 요소 (단일 책임 + 인터페이스)
각 요소는 독립적으로 이해·테스트 가능해야 한다.

### 5.1 `DeskViewAvailability`
- 역할: `.deskViewCamera` 장치를 찾아 반환. 없으면 nil.
- 인터페이스: `func builtInDeskViewDevice() -> AVCaptureDevice?`
- 의존: AVFoundation. (테스트 위해 장치 조회를 프로토콜로 추상화)

### 5.2 `CameraManager`
- 역할: 세션 수명 관리. 데스크 뷰 장치를 입력으로 세션 구동,
  라이브 미리보기 레이어 제공, 최신 프레임 1장을 스레드 안전하게 보관.
- 구성: `AVCaptureSession` + `AVCaptureDeviceInput` + `AVCaptureVideoPreviewLayer`(미리보기)
  + `AVCaptureVideoDataOutput`(BGRA, 델리게이트가 최신 `CVPixelBuffer` 보관).
- 인터페이스: `start()`, `stop()`, `previewLayer`, `func latestFrame() -> CGImage?`
- 비고: 데스크 뷰는 비디오 전용 장치일 수 있어 `AVCapturePhotoOutput` 대신
  VideoDataOutput의 최신 프레임을 스냅샷하는 방식으로 캡처(안정적).

### 5.3 `CaptureService`
- 역할: 캡처 1회 실행. 최신 프레임을 받아 PNG 인코딩 → 폴더 저장 + 클립보드 복사 → 피드백.
- 인터페이스: `func capture() throws -> URL` (저장된 파일 경로 반환)
- 세부:
  - PNG 인코딩: `CGImage` → `CGImageDestination`(또는 `NSBitmapImageRep`).
  - 저장: `<저장폴더>/desk-YYYYMMDD-HHmmss.png`. 폴더 없으면 생성.
  - 클립보드: `NSPasteboard.general` 비우고 **PNG 데이터 + NSImage(TIFF)** 둘 다 기록
    (카톡·ChatGPT 등 앱 호환성 최대화).
  - 피드백: 셔터음(`NSSound`/시스템 사운드) + 간단 알림 또는 화면 가장자리 플래시.
- 의존: CameraManager(최신 프레임), Settings(저장 폴더). 파일 쓰기·클립보드는 주입 가능하게.

### 5.4 `HotkeyManager`
- 역할: 전역 핫키 등록/해제, 눌리면 콜백.
- 기본값: **⌘⇧2** (설정에서 변경 가능, v1은 기본값 + 간단 변경).
- 구현: Carbon `RegisterEventHotKey` + 이벤트 핸들러.
- 인터페이스: `func register(onTrigger: @escaping () -> Void)`, `func unregister()`

### 5.5 UI
- `MenuBarExtra`: 찍기 / 미리보기 열기 / 저장 폴더 열기 / 설정 / 종료.
- `PreviewWindow`(SwiftUI): 라이브 미리보기(previewLayer 래핑) + 큰 "찍기" 버튼.
- `UnsupportedView`: 미지원 맥에서 안내 + 종료.
- `SettingsView`: 저장 폴더 선택, 핫키 표시/변경.

### 5.6 `Settings`
- 역할: 사용자 설정 영속화(`UserDefaults`).
- 항목: 저장 폴더(기본 `~/Pictures/DeskShots`), 핫키(기본 ⌘⇧2).

## 6. 데이터 흐름
1. 실행 → `DeskViewAvailability` 확인. 없으면 `UnsupportedView` 후 종료.
2. 있으면 카메라 권한 요청(첫 실행 1회) → `CameraManager.start()`.
3. 미리보기 창/메뉴바에서 라이브 표시. VideoDataOutput이 최신 프레임 계속 갱신.
4. 트리거(핫키/메뉴바/버튼) → `CaptureService.capture()`:
   최신 프레임 스냅샷 → PNG 저장 + 클립보드 복사 → 피드백.
5. 사용자가 다른 앱에서 ⌘V로 붙여넣기(수동).

## 7. 권한 / 보안
- `Info.plist`에 `NSCameraUsageDescription` (한글 안내 문구).
- 첫 캡처/실행 시 카메라 권한 시스템 프롬프트 1회(불가피).
- 저장 폴더가 `~/Pictures` 밖이면 추후 폴더 접근 권한 고려(v1 기본은 Pictures 내).

## 8. 오류 처리
- 데스크 뷰 장치 없음 → 안내 화면.
- 카메라 권한 거부 → 설정 열기 안내 메시지.
- 아직 프레임 없음(세션 준비 전 캡처) → "잠시 후 다시" 안내, 저장 안 함.
- 저장 폴더 쓰기 실패 → 오류 알림, 클립보드 복사는 시도.

## 9. 배포
- **무료, 서명 없음.** GitHub 릴리스에 빌드된 `.app`(zip) 업로드.
- README: 첫 실행 시 **우클릭 → 열기**(Gatekeeper 1회 우회) 안내 + 카메라 권한 안내.
- 소스도 공개 → Xcode로 직접 빌드 가능.
- (공증 $99는 하지 않음.)

## 10. 테스트 전략
- **단위 테스트(TDD)**
  - `CaptureService`: 가짜 CGImage 주입 → PNG 바이트 생성, 파일명 규칙(`desk-YYYYMMDD-HHmmss`),
    클립보드 기록 호출, 저장 경로 반환 검증(파일 쓰기·클립보드는 목으로 주입).
  - `DeskViewAvailability`: 가짜 장치 공급자로 지원/미지원 분기.
  - `Settings`: 기본값·영속화.
- **수동 테스트(사용자 M4 Air)**: 실제 촬영 품질, 핫키 전역 동작, 붙여넣기 호환(카톡/챗봇).

## 11. 향후 확장 (비목표, 기록용)
- 아이폰 연속성·외장캠 소스 선택 + Vision 문서 감지 기반 커스텀 원근 보정
  → "책상을 볼 수 있는 카메라가 있으면 모든 맥 지원".
- 공유 시트 버튼, OCR, 세션별 PDF 묶기.

## 12. 미해결 항목
- 없음 (v1 기본값·배포 방식 확정됨).
