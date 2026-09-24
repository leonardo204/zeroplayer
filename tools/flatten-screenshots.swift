import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// 알파 채널이 든 PNG 를 흰 바탕 위에 눌러 불투명 PNG 로 다시 쓴다.
// App Store Connect 는 알파가 있는 스크린샷을 받지 않는다.
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        print("읽기 실패: \(path)"); continue
    }
    let w = image.width, h = image.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        print("컨텍스트 실패: \(path)"); continue
    }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let out = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("쓰기 실패: \(path)"); continue
    }
    CGImageDestinationAddImage(dest, out, nil)
    CGImageDestinationFinalize(dest)
}
