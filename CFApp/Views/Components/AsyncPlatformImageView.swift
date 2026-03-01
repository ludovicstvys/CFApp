import SwiftUI

#if canImport(UIKit) || canImport(AppKit)
struct AsyncPlatformImageView: View {
    let imageName: String
    let loader: (String) async -> PlatformImage?
    var cornerRadius: CGFloat = 12

    @State private var image: PlatformImage? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                platformImageView(image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .task(id: imageName) {
            isLoading = true
            image = await loader(imageName)
            isLoading = false
        }
    }

    private func platformImageView(_ image: PlatformImage) -> Image {
#if canImport(UIKit)
        Image(uiImage: image)
#elseif canImport(AppKit)
        Image(nsImage: image)
#endif
    }
}
#endif
