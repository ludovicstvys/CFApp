import SwiftUI

struct FormulaCardView: View {
    let category: CFACategory
    let topic: String?
    let title: String
    let formula: String?
    let notes: String?
    let imageName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(category.shortName, systemImage: category.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let topic, !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(topic)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let formula, !formula.isEmpty {
                LatexTextView(content: formula, isBlock: true)
            }

            if let notes, !notes.isEmpty {
                LatexTextView(content: notes, isBlock: false)
                    .foregroundStyle(.secondary)
            }

            if let imageName {
#if canImport(UIKit) || canImport(AppKit)
                AsyncPlatformImageView(
                    imageName: imageName,
                    loader: { await FormulaAssetStore.shared.loadImageAsync(named: $0) }
                )
#endif
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
