import SwiftUI

struct EmptySlotView: View {
    let title: String
    let subtitle: String
    let acceptedCategory: SoundCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text("拖入\(acceptedCategory.map(categoryName) ?? "合适的")声音 · \(subtitle)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func categoryName(_ category: SoundCategory) -> String {
        switch category { case .atmosphere: "氛围"; case .anchor: "主体"; case .detail: "细节"; case .humanASMR: "ASMR"; case .event: "事件"; case .environment: "环境" }
    }
}
