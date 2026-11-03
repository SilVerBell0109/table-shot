import SwiftUI

/// 데스크 뷰 미지원 맥에서 보여 주는 안내 화면.
struct UnsupportedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("데스크 뷰를 사용할 수 없습니다")
                .font(.title2).bold()
            Text("""
            DeskShot은 데스크 뷰(Desk View) 카메라가 있는 맥에서만 동작합니다.
            12MP 센터 스테이지 내장 카메라를 갖춘 M4 이상 맥북 에어/프로, iMac(2024)에서 사용하세요.
            """)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Button("종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 420)
    }
}
