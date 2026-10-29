// Generated from design/tokens by design/build. Do not edit by hand.
//
// Lucide icons, drawn on Lucide's 24 by 24 grid with a stroke of 2, as the
// app's icon font draws them.

import SwiftUI

enum AnchorIcon: CaseIterable {
    case hash
    case link
    case x
    case audioLines
    case loaderCircle

    var path: Path {
        var path = Path()
        switch self {
        case .hash:
            path.move(to: CGPoint(x: 4, y: 9))
            path.addLine(to: CGPoint(x: 20, y: 9))
            path.move(to: CGPoint(x: 4, y: 15))
            path.addLine(to: CGPoint(x: 20, y: 15))
            path.move(to: CGPoint(x: 10, y: 3))
            path.addLine(to: CGPoint(x: 8, y: 21))
            path.move(to: CGPoint(x: 16, y: 3))
            path.addLine(to: CGPoint(x: 14, y: 21))
        case .link:
            path.move(to: CGPoint(x: 10, y: 13))
            path.addCurve(to: CGPoint(x: 13.6466, y: 14.9923), control1: CGPoint(x: 10.869, y: 14.1617), control2: CGPoint(x: 12.1996, y: 14.8887))
            path.addCurve(to: CGPoint(x: 17.54, y: 13.54), control1: CGPoint(x: 15.0937, y: 15.096), control2: CGPoint(x: 16.5144, y: 14.566))
            path.addLine(to: CGPoint(x: 20.54, y: 10.54))
            path.addCurve(to: CGPoint(x: 20.4791, y: 3.5309), control1: CGPoint(x: 22.4349, y: 8.5781), control2: CGPoint(x: 22.4078, y: 5.4596))
            path.addCurve(to: CGPoint(x: 13.47, y: 3.47), control1: CGPoint(x: 18.5504, y: 1.6022), control2: CGPoint(x: 15.4319, y: 1.5751))
            path.addLine(to: CGPoint(x: 11.75, y: 5.18))
            path.move(to: CGPoint(x: 14, y: 11))
            path.addCurve(to: CGPoint(x: 10.3534, y: 9.0077), control1: CGPoint(x: 13.131, y: 9.8383), control2: CGPoint(x: 11.8004, y: 9.1113))
            path.addCurve(to: CGPoint(x: 6.46, y: 10.46), control1: CGPoint(x: 8.9063, y: 8.904), control2: CGPoint(x: 7.4856, y: 9.434))
            path.addLine(to: CGPoint(x: 3.46, y: 13.46))
            path.addCurve(to: CGPoint(x: 3.5209, y: 20.4691), control1: CGPoint(x: 1.5651, y: 15.4219), control2: CGPoint(x: 1.5922, y: 18.5404))
            path.addCurve(to: CGPoint(x: 10.53, y: 20.53), control1: CGPoint(x: 5.4496, y: 22.3978), control2: CGPoint(x: 8.5681, y: 22.4249))
            path.addLine(to: CGPoint(x: 12.24, y: 18.82))
        case .x:
            path.move(to: CGPoint(x: 18, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 18))
            path.move(to: CGPoint(x: 6, y: 6))
            path.addLine(to: CGPoint(x: 18, y: 18))
        case .audioLines:
            path.move(to: CGPoint(x: 2, y: 10))
            path.addLine(to: CGPoint(x: 2, y: 13))
            path.move(to: CGPoint(x: 6, y: 6))
            path.addLine(to: CGPoint(x: 6, y: 17))
            path.move(to: CGPoint(x: 10, y: 3))
            path.addLine(to: CGPoint(x: 10, y: 21))
            path.move(to: CGPoint(x: 14, y: 8))
            path.addLine(to: CGPoint(x: 14, y: 15))
            path.move(to: CGPoint(x: 18, y: 5))
            path.addLine(to: CGPoint(x: 18, y: 18))
            path.move(to: CGPoint(x: 22, y: 10))
            path.addLine(to: CGPoint(x: 22, y: 13))
        case .loaderCircle:
            path.move(to: CGPoint(x: 21, y: 12))
            path.addCurve(to: CGPoint(x: 14.7809, y: 20.5592), control1: CGPoint(x: 20.9998, y: 15.899), control2: CGPoint(x: 18.4891, y: 19.3544))
            path.addCurve(to: CGPoint(x: 4.7188, y: 17.2895), control1: CGPoint(x: 11.0727, y: 21.7639), control2: CGPoint(x: 7.0105, y: 20.4439))
            path.addCurve(to: CGPoint(x: 4.7188, y: 6.7095), control1: CGPoint(x: 2.4271, y: 14.1351), control2: CGPoint(x: 2.4271, y: 9.8638))
            path.addCurve(to: CGPoint(x: 14.781, y: 3.44), control1: CGPoint(x: 7.0106, y: 3.5552), control2: CGPoint(x: 11.0728, y: 2.2352))
        }
        return path
    }
}
