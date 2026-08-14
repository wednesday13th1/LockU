import SwiftUI
import UIKit

struct ThenNowView: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var reflectionRepository: MemoryReflectionRepository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let pair: ThenNowMemoryPair
    @State private var appeared = false
    @State private var showsReflection = false
    @State private var reflectionText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .center, spacing: 18) { memoryColumn("THEN", pair.thenMemory); gapLabel; memoryColumn("NOW", pair.nowMemory) }
                    } else {
                        VStack(spacing: 25) { memoryColumn("THEN", pair.thenMemory); gapLabel; memoryColumn("NOW", pair.nowMemory) }
                    }
                    if !showsReflection {
                        Text("少し変わった？")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.72))
                            .padding(.top, 4)
                    }
                    reflectionSection
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 24).padding(.vertical, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: reduceMotion || appeared ? 0 : 8)
            }
            .background(LockUPageBackground())
            .navigationTitle("THEN & NOW")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
        .onAppear { if reduceMotion { appeared = true } else { withAnimation(.easeOut(duration: 0.34)) { appeared = true } } }
        .onChange(of: reflectionText) { _, value in if value.count > MemoryReflectionPolicy.maximumLength { reflectionText = String(value.prefix(MemoryReflectionPolicy.maximumLength)) } }
        .alert("LockU", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func memoryColumn(_ label: String, _ memory: MemoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(.system(size: 11, weight: .semibold)).tracking(2).foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.62))
            ThenNowMemoryImage(memory: memory).aspectRatio(0.82, contentMode: .fit).frame(maxWidth: 310).clipped().shadow(color: .black.opacity(0.11), radius: 4, y: 2)
            if let emoji = memory.moodEmoji { Text(emoji).font(.system(size: 22)) }
            if let note = memory.memoryNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(note).font(LockUDesign.Typography.body).foregroundStyle(LockUDesign.Color.softInk).lineLimit(3)
            }
            Text(memory.memoryDate.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(LockUDesign.Color.softInkSecondary)
        }
        .frame(maxWidth: 320, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var gapLabel: some View {
        Text(gapText).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.3).foregroundStyle(LockUDesign.Color.softInkSecondary)
            .accessibilityLabel("\(pair.dayGap)日間")
    }

    private var gapText: String {
        if pair.dayGap >= 365, pair.dayGap % 365 < 45 { return "\(max(1, pair.dayGap / 365)) YEAR\(pair.dayGap / 365 == 1 ? "" : "S")" }
        if pair.dayGap >= 60 { return "\(max(2, Int((Double(pair.dayGap) / 30).rounded()))) MONTHS" }
        return "\(pair.dayGap) DAYS"
    }

    @ViewBuilder private var reflectionSection: some View {
        if showsReflection {
            VStack(alignment: .leading, spacing: 12) {
                Text("あの時の自分に、今ならなんて言う？").font(LockUDesign.Typography.body)
                ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(quickResponses, id: \.self) { response in Button(response) { reflectionText = response }.buttonStyle(.bordered) } } }
                TextEditor(text: $reflectionText).frame(minHeight: 80).scrollContentBackground(.hidden).background(LockUDesign.Color.notebookPaper.opacity(0.4))
                HStack { Button("今回は残さない") { showsReflection = false; reflectionText = "" }; Spacer(); Button("残す", action: saveReflection).disabled(reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.frame(maxWidth: 650)
        } else {
            Button("ひとこと残す") { showsReflection = true }.font(.system(size: 12, weight: .medium)).foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.7)).frame(minHeight: 44)
        }
    }

    private var quickResponses: [String] { ["よくやってた", "大丈夫だったよ", "懐かしい", "ちゃんと進んでた", "この頃も好き"] }
    private func saveReflection() {
        do {
            try CompleteRevisitWorkflow(memoryRepository: memoryRepository, reflectionRepository: reflectionRepository).execute(memoryID: pair.thenMemory.id, reflectionText: reflectionText)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showsReflection = false; reflectionText = ""
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct ThenNowMemoryImage: View {
    @EnvironmentObject private var repository: MemoryRepository
    @State private var image: UIImage?
    let memory: MemoryRecord
    var body: some View {
        Group {
            if memory.isDualCameraMemory { DualMemoryImageSurface(memory: memory, purpose: .detail, targetPointSize: CGSize(width: 420, height: 520)) }
            else if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Color.gray.opacity(0.28).overlay(ProgressView()) }
        }
        .task(id: memory.id) { if !memory.isDualCameraMemory { image = await repository.imageAsync(for: memory, purpose: .detail, targetPointSize: CGSize(width: 420, height: 520)) } }
        .onDisappear { image = nil }
    }
}
