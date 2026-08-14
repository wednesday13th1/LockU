import SwiftUI

struct SelfDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let moment: SelfDiscoveryMoment
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Text("こんな日もあった")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.58))

                    if horizontalSizeClass == .regular {
                        HStack(alignment: .center, spacing: 24) {
                            ForEach(Array(moment.memories.enumerated()), id: \.element.id) { index, memory in
                                memoryPrint(memory, index: index)
                            }
                        }
                    } else {
                        VStack(spacing: 24) {
                            memoryPrint(moment.memories[0], index: 0)
                            HStack(alignment: .top, spacing: 14) {
                                memoryPrint(moment.memories[1], index: 1)
                                memoryPrint(moment.memories[2], index: 2)
                            }
                        }
                    }

                    Text(moment.prompt)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                        .padding(.top, 4)
                }
                .frame(maxWidth: 820)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: reduceMotion || appeared ? 0 : 8)
            }
            .background(LockUPageBackground())
            .navigationTitle("MEMORY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(.easeOut(duration: 0.34)) { appeared = true } }
        }
    }

    private func memoryPrint(_ memory: MemoryRecord, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SelfDiscoveryMemoryImage(memory: memory)
                .aspectRatio(0.82, contentMode: .fit)
                .frame(maxWidth: index == 0 ? 300 : 245)
                .clipped()
                .rotationEffect(.degrees([-0.8, 1.1, -1.3][index]))
                .shadow(color: .black.opacity(0.11), radius: 4, y: 2)
            if let emoji = memory.moodEmoji { Text(emoji).font(.system(size: 22)) }
            if let note = memory.memoryNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(note)
                    .font(LockUDesign.Typography.body)
                    .foregroundStyle(LockUDesign.Color.softInk)
                    .lineLimit(2)
            }
            Text(memory.memoryDate.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
        }
        .frame(maxWidth: 300, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct SelfDiscoveryMemoryImage: View {
    @EnvironmentObject private var repository: MemoryRepository
    @State private var image: UIImage?
    let memory: MemoryRecord

    var body: some View {
        Group {
            if memory.isDualCameraMemory {
                DualMemoryImageSurface(memory: memory, purpose: .detail, targetPointSize: CGSize(width: 380, height: 480))
            } else if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.26).overlay(ProgressView())
            }
        }
        .task(id: memory.id) {
            guard !memory.isDualCameraMemory else { return }
            image = await repository.imageAsync(for: memory, purpose: .detail, targetPointSize: CGSize(width: 380, height: 480))
        }
        .onDisappear { image = nil }
    }
}
