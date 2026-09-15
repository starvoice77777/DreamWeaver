import SwiftUI
import UniformTypeIdentifiers

struct SceneSlotView: View {
    let slot: SceneSlot
    let element: SoundElement?
    let isSelectionPending: Bool
    let onDropElementID: (String) -> Void
    let onTap: () -> Void
    let onRemove: () -> Void
    @State private var targeted = false

    var body: some View {
        HStack(spacing: 14) {
            if element == nil || isSelectionPending {
                Button(action: onTap) {
                    slotContent
                }
                .buttonStyle(.plain)
            } else {
                slotContent
            }
            Spacer()
            if element != nil {
                Button("移除", systemImage: "xmark.circle.fill", action: onRemove)
                    .labelStyle(.iconOnly).foregroundStyle(.secondary)
                    .accessibilityHint("从此槽位移除声音")
            }
        }
        .padding(16)
        .background(targeted ? Color.accentColor.opacity(0.16) : Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(targeted ? Color.accentColor : .clear, lineWidth: 2))
        .onDrop(of: [UTType.text], isTargeted: $targeted) { providers in
            guard let provider = providers.first else { return false }
            if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    if let id = object as? String { DispatchQueue.main.async { onDropElementID(id) } }
                }
            } else {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    let id = (item as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? (item as? String)
                    if let id { DispatchQueue.main.async { onDropElementID(id) } }
                }
            }
            return true
        }
        .accessibilityLabel(element.map { "\(slotTitle(slot.kind))：\($0.name)" } ?? "空的\(slotTitle(slot.kind))槽位")
        .accessibilityHint(
            element == nil
                ? "点击放置已选择的声音，或拖入声音卡片"
                : (isSelectionPending ? "点击替换为已选择的声音，或拖入新的声音替换" : "使用独立移除按钮，或拖入新的声音替换")
        )
    }

    private func slotTitle(_ kind: SceneSlotKind) -> String {
        switch kind { case .environment: "环境"; case .atmosphere: "氛围"; case .anchor: "主体"; case .detail: "细节"; case .humanASMR: "ASMR"; case .event: "事件" }
    }

    @ViewBuilder private var slotContent: some View {
        Image(systemName: element?.systemImage ?? slot.systemImage).font(.title2)
            .foregroundStyle(element == nil ? .secondary : .primary)
        if let element {
            VStack(alignment: .leading, spacing: 3) {
                Text(element.name).font(.headline)
                Text(element.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        } else {
            EmptySlotView(title: slotTitle(slot.kind), subtitle: slot.subtitle, acceptedCategory: slot.acceptedCategories.first)
        }
    }
}
