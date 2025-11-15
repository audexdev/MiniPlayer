extension NSColor {
    func isDark(threshold: CGFloat = 0.5) -> Bool {
        let ns = self.usingColorSpace(.deviceRGB) ?? self
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        ns.getRed(&r, green: &g, blue: &b, alpha: &a)

        let luminance = 0.299*r + 0.587*g + 0.114*b
        return luminance < threshold
    }
}
