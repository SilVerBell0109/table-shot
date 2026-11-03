# Desk View 캡처 앱 — 연구/결정 기록

작성일: 2026-11-03

## 앱 개요 (디자인 브리프)
- 맥 내장 데스크 뷰 카메라로 책상(종이/아이패드)을 **캡처**하는 네이티브 맥 앱.
- 찍는 방법 3가지: ① 전역 핫키 ② 메뉴바 버튼 ③ 미리보기 창의 찍기 버튼.
- 찍으면: **클립보드 복사 + 지정 폴더에 PNG 저장** (둘 다 자동).
- 챗봇/카톡 전송은 사용자가 직접(앱은 캡처까지만). **API 연동·추가 비용 없음.**
- 배포: GitHub. (서명/배포 방식은 미확정 — 무료 우클릭→열기 vs 공증 $99)

## 확정된 결정
- 카메라 소스: **내장캠 전용** (아이폰/외장캠 소스 선택 UI 없음).
- 지원 범위: **내장 데스크 뷰가 되는 맥 전용.** 안 되는 맥은 안내 메시지만.
- "모든 웹캠 지원(커스텀 원근 보정)"은 v1 범위에서 제외(향후 확장 후보).

## 스파이크 결과 (2026-11-03, 사용자 M4 MacBook Air에서 실행)
`swift ~/Desktop/deskview-probe.swift` 출력으로 확인:
- `'MacBook Air' 데스크뷰 카메라` → deviceType `AVCaptureDeviceTypeDeskViewCamera` → **노출됨 ✅**
  - uniqueID: 6C707041-05AC-0010-000C-000000000002
- 아이폰(iPhone15,2)의 데스크뷰 카메라도 장치로 잡힘 (이번 범위에선 미사용).
- **결론: `.deskViewCamera` 장치를 `AVCaptureSession`으로 프레임 직접 캡처 가능. 화면 캡처 우회 불필요.**

## 지원 기종 조사 (Apple 공식)
내장 데스크 뷰 = **12MP 센터 스테이지 카메라** 탑재 기종:
- iMac (M4, 2024)
- MacBook Air (M4 이상, 2025~)
- MacBook Pro (M4 / M4 Pro / M4 Max 이상, 2024 말~)

미지원:
- Studio Display — 센터 스테이지만, Desk View 미지원
- Mac mini / Studio / Pro — 내장 카메라 없음
- M3 이하 구형 — 1080p 카메라

출처:
- Apple 용어집: https://support.apple.com/en-bh/guide/mac-help/aside/glos7c8cf8b7/mac
- Desk View 안내: https://support.apple.com/guide/mac-help/use-desk-view-on-mac-mchl06927be8/mac

## 엔지니어링 방침
- 모델명 하드코딩 금지. **런타임에 `.deskViewCamera` 장치 유무로 지원 판단** (신기종 자동 지원, 정확).

## "모든 웹캠에서 가능한가" 결론
- 순수 소프트웨어로 구형 내장캠에서는 **불가능**(책상이 센서에 안 찍힘 → 복원 불가).
- 책상을 물리적으로 볼 수 있는 카메라(아이폰 연속성/외장캠/거울 액세서리)가 있으면 가능.

## 다음 할 일
- 접근법 🅰️(네이티브 데스크 뷰 전용, 가볍게)로 설계 섹션 진행.
- 미확정: 배포 서명 방식(무료 vs 공증), 저장 포맷/폴더 기본값, 전역 핫키 구현(Carbon 내장 API 예정).
