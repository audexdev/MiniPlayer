import Foundation
import AppKit

final class ArtworkProcessor {
    static let shared = ArtworkProcessor()

    private struct Processed {
        let image: NSImage
        let color: NSColor
        let isDark: Bool
    }

    private let queue = DispatchQueue(label: "app.artwork.processor", qos: .userInitiated)
    private var cache: [String: Processed] = [:]

    func process(image: NSImage?, key: String, completion: @escaping (NSImage?, NSColor?, Bool) -> Void) {
        guard let image else {
            DispatchQueue.main.async {
                completion(nil, nil, false)
            }
            return
        }

        if let cached = cache[key] {
            DispatchQueue.main.async {
                completion(cached.image, cached.color, cached.isDark)
            }
            return
        }

        let tiffData = image.tiffRepresentation
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)

        queue.async { [weak self] in
            autoreleasepool {
                guard let sourceImage = ArtworkProcessor.makeImage(tiffData: tiffData, cgImage: cgImage) else {
                    DispatchQueue.main.async {
                        completion(nil, nil, false)
                    }
                    return
                }

                guard let color = averageColor(from: sourceImage) else {
                    DispatchQueue.main.async {
                        completion(sourceImage, nil, false)
                    }
                    return
                }

                let isDark = color.isDark()
                let processed = Processed(image: sourceImage, color: color, isDark: isDark)
                self?.cache[key] = processed

                DispatchQueue.main.async {
                    completion(sourceImage, color, isDark)
                }
            }
        }
    }

    private static func makeImage(tiffData: Data?, cgImage: CGImage?) -> NSImage? {
        if let cg = cgImage {
            return NSImage(cgImage: cg, size: .zero)
        }
        if let data = tiffData {
            return NSImage(data: data)
        }
        return nil
    }
}
