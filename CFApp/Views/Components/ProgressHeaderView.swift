import SwiftUI

struct ProgressHeaderView: View {
    let label: String
    let index: Int
    let total: Int
    let score: Int
    let remainingSeconds: Int?

    private var progressValue: Double {
        guard total > 0 else { return 0 }
        return Double(index) / Double(total)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(label) \(min(index + 1, total))/\(total)")
                    .font(.headline)

                Spacer()

                if let remainingSeconds {
                    Text(timeString(remainingSeconds))
                        .font(.subheadline.monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                } else {
                    Text("Score: \(score)")
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            ProgressView(value: progressValue)
        }
    }

    private func timeString(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }
}
