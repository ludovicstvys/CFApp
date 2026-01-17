import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct QuestionCardView: View {
    let category: CFACategory
    let subcategory: String?
    let stem: String
    let imageName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(category.shortName, systemImage: category.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let sub = subcategory, !sub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(sub)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }
            }

            if let imageName, let image = QuestionAssetStore.shared.loadImage(named: imageName) {
#if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#endif
            }

            Text(stem)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
