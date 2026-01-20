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
                Text(formula)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let imageName,
               let image = FormulaAssetStore.shared.loadImage(named: imageName) {
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
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
