import SwiftUI

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

            if let imageName {
#if canImport(UIKit) || canImport(AppKit)
                AsyncPlatformImageView(
                    imageName: imageName,
                    loader: { await QuestionAssetStore.shared.loadImageAsync(named: $0) }
                )
#endif
            }

            Text(stem)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Question")
                .accessibilityValue(stem)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
