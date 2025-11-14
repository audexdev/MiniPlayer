import CoreImage

func averageColor(from image: NSImage) -> NSColor? {
    guard let rep = NSBitmapImageRep(data: image.tiffRepresentation!) else {
            return NSColor.windowBackgroundColor
        }

        let width = rep.pixelsWide
        let height = rep.pixelsHigh

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var totalWeight: CGFloat = 0

        for x in stride(from: 0, to: width, by: 4) {
            for y in stride(from: 0, to: height, by: 4) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }

                var h: CGFloat = 0
                var s: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0

                color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

                let weight = (s * 0.7) + (b * 0.3)

                totalR += color.redComponent * weight
                totalG += color.greenComponent * weight
                totalB += color.blueComponent * weight

                totalWeight += weight
            }
        }

        let r = totalR / totalWeight
        let g = totalG / totalWeight
        let b = totalB / totalWeight

        var final = NSColor(red: r, green: g, blue: b, alpha: 1.0)

        var h: CGFloat = 0
        var s: CGFloat = 0
        var br: CGFloat = 0
        var a: CGFloat = 0

        final.getHue(&h, saturation: &s, brightness: &br, alpha: &a)

        s *= 0.75
        br = min(br * 1.15, 1.0)

        final = NSColor(hue: h, saturation: s, brightness: br, alpha: 1.0)

        if br < 0.35 {
            final = final.blended(withFraction: 0.45, of: .white)!
        } else {
            final = final.blended(withFraction: 0.18, of: .white)!
        }

        final = final.withAlphaComponent(0.94)

        return final
}
