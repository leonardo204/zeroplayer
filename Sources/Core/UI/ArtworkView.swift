import SwiftUI

/// 방송국·에피소드 썸네일 한 자리.
///
/// 미니 플레이어와 재생 화면이 같은 규칙으로 그리게 하려고 한 곳에 모았다.
/// 주소가 없거나 그림을 못 받으면 이름 첫 글자로 타일을 그린다. 방송국 절반은
/// radio-browser 에 썸네일이 아예 없고, 있어도 이미 지워진 주소가 섞여 있다.
struct ArtworkView: View {
    let url: URL?
    let title: String
    let size: CGFloat
    var cornerRadius: CGFloat = 8
    /// 이름이 비었을 때 대신 쓰는 기호. 에피소드는 `mic` 을 준다.
    var symbolName: String = "waveform"

    var body: some View {
        Group {
            if let url {
                AsyncImage(
                    url: url,
                    transaction: Transaction(animation: .easeInOut(duration: 0.18))
                ) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        // 받는 중이든 실패든 같은 타일을 보여 준다.
                        // 작은 썸네일에 회전자를 돌리면 깜빡임만 는다.
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: - 이름 타일

    private var fallback: some View {
        LinearGradient(
            colors: [tint.opacity(0.85), tint.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            if let initial {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    /// 이름 맨 앞의 글자나 숫자 하나. 한글은 한 글자, 영문은 대문자로 세운다.
    private var initial: String? {
        let cleaned = title
            // 앞에 붙은 제공자 표기와 기호를 건너뛴다 — '(BSOD) KBS' 의 B 를 세우지 않는다.
            .replacingOccurrences(of: #"^\s*[\(\[][^\)\]]{1,12}[\)\]]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first(where: { $0.isLetter || $0.isNumber }) else { return nil }
        return String(first).uppercased()
    }

    /// 같은 이름이면 늘 같은 색이 나오게 한다.
    ///
    /// `hashValue` 는 실행할 때마다 값이 달라져서 쓰지 않는다. 껐다 켤 때마다
    /// 방송국 색이 바뀌면 목록이 다른 곳처럼 보인다.
    private var tint: Color {
        var hash: UInt64 = 5381
        for scalar in title.unicodeScalars {
            hash = hash &* 33 &+ UInt64(scalar.value)
        }
        // 노랑 근처(0.13~0.18)는 흰 글자가 안 읽혀 건너뛴다.
        let hue = Double(hash % 360) / 360
        let safeHue = (hue > 0.11 && hue < 0.19) ? hue + 0.12 : hue
        return Color(hue: safeHue, saturation: 0.52, brightness: 0.62)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            ArtworkView(url: nil, title: "KBS Classic FM", size: 56, cornerRadius: 8)
            ArtworkView(url: nil, title: "(BSOD) MBC mini", size: 56, cornerRadius: 8)
            ArtworkView(url: nil, title: "국악방송", size: 56, cornerRadius: 8)
            ArtworkView(url: nil, title: "101 SMOOTH JAZZ", size: 56, cornerRadius: 8)
        }
        ArtworkView(url: nil, title: "Listen.moe Kpop", size: 160, cornerRadius: 16)
    }
    .padding()
}
