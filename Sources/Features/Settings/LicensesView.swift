import SwiftUI

/// 앱에 담아 배포하는 남의 저작물을 밝히는 자리.
///
/// 알람음 20곡은 저작권이 끝난 곡을 우리가 연주해 구운 것이라 녹음의 권리자는 우리다.
/// 다만 그 연주에 쓴 사운드폰트가 MIT 이고, MIT 는 "저작권 표시와 이 허가 표시를
/// 사본이나 상당 부분에 포함해야 한다"고 요구한다. 구운 음원이 그 샘플에서 나왔으므로
/// 여기에 원문을 그대로 싣는다(`tools/alarm-tones/LICENSE-NOTES.md`).
struct LicensesView: View {
    var body: some View {
        List {
            Section {
                Text("""
                알람음 스무 곡은 저작권이 끝난 고전을 직접 연주해 담은 것입니다. \
                바흐·모차르트·베토벤·비발디·파헬벨·하이든·그리그·로시니·슈트라우스·드보르자크·엘가의 \
                곡이고, 모두 작곡가 사후 70년이 지났습니다.
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("알람음")
            }

            Section {
                Text("FluidR3 GM")
                    .font(.subheadline.weight(.semibold))
                Text(Self.fluidNotice)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                Text("연주에 쓴 사운드폰트")
            } footer: {
                Text("사운드폰트 파일 자체는 앱에 들어 있지 않습니다. 미리 구워 둔 음원만 담았습니다.")
            }
        }
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 저작권 표시와 MIT 전문. 번역하지 않는다 — 원문을 싣는 것이 조건이다.
    private static let fluidNotice = """
        Copyright (c) 2000-2002, 2008 Frank Wen <getfrank@gmail.com>

        Permission is hereby granted, free of charge, to any person obtaining a copy of \
        this software and associated documentation files (the "Software"), to deal in the \
        Software without restriction, including without limitation the rights to use, \
        copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the \
        Software, and to permit persons to whom the Software is furnished to do so, \
        subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS \
        FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR \
        COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN \
        AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION \
        WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
}
