import SwiftUI

// LockU presentation rule:
// Locker shows how that day felt. Peek holds what that day said.
// moodEmoji -> Locker + Peek / memoryNote -> Peek THEN / reflection -> Peek NOW
enum PeekContext: Equatable {
    case normal
    case memory(MemoryRecord)
    case revisit(RevisitPresentation)
}

struct PeekView: View {
    @EnvironmentObject private var revisitCoordinator: RevisitCoordinator
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var reflectionRepository: MemoryReflectionRepository
    @EnvironmentObject private var demoClock: LockUDemoClock
    @State private var code = ""
    @State private var hasStarted = false
    @State private var submittedCode: String?
    @State private var presentedSelfDiscovery: SelfDiscoveryMoment?
    @State private var presentedThenNowPair: ThenNowMemoryPair?
    private let reflectionTraceService = MemoryReflectionTraceService()
    let contextOverride: PeekContext?
    let onCompleteRevisit: (RevisitPresentation, String) -> Void

    init(
        context: PeekContext? = nil,
        onCompleteRevisit: @escaping (RevisitPresentation, String) -> Void = { _, _ in }
    ) {
        contextOverride = context
        self.onCompleteRevisit = onCompleteRevisit
    }

    var body: some View {
        Group {
            switch resolvedContext {
            case .normal:
                normalPeek
            case .memory(let memory):
                DualMemoryPeekView(
                    memory: memory,
                    onClose: {
                        appModel.peekMemory = nil
                        appModel.selectedTab = .locker
                    },
                    onReflect: { text in
                        let completedAt = Date()
                        try CompleteRevisitWorkflow(
                            memoryRepository: memoryRepository,
                            reflectionRepository: reflectionRepository
                        ).execute(
                            memoryID: memory.id,
                            reflectionText: text,
                            completedAt: completedAt
                        )
                        reflectionTraceService.recordReflection(memoryID: memory.id, at: completedAt)
                    }
                )
            case .revisit(let presentation):
                RevisitExperienceView(
                    presentation: presentation,
                    onClose: {
                        appModel.refreshTimeDependentState()
                        appModel.selectedTab = .locker
                    },
                    onSkip: {
                        if appModel.demoClock.isLive {
                            try CompleteRevisitWorkflow(
                                memoryRepository: memoryRepository,
                                reflectionRepository: reflectionRepository
                            ).execute(
                                memoryID: presentation.memoryID,
                                reflectionText: "",
                                completedAt: .now
                            )
                        }
                        appModel.refreshTimeDependentState()
                        appModel.selectedTab = .locker
                    },
                    onComplete: { reflection in
                        if appModel.demoClock.isLive {
                            let completedAt = Date()
                            try CompleteRevisitWorkflow(
                                memoryRepository: memoryRepository,
                                reflectionRepository: reflectionRepository
                            ).execute(
                                memoryID: presentation.memoryID,
                                reflectionText: reflection,
                                completedAt: completedAt
                            )
                            reflectionTraceService.recordReflection(memoryID: presentation.memoryID, at: completedAt)
                        }
                        onCompleteRevisit(presentation, reflection)
                    }
                )
            }
        }
    }

    private var resolvedContext: PeekContext {
        if let contextOverride { return contextOverride }
        if let memory = appModel.peekMemory { return .memory(memory) }
        return revisitCoordinator.presentation.map(PeekContext.revisit) ?? .normal
    }

    private var normalPeek: some View {
        ZStack {
            LockUPageBackground()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.46))
                Text("過去の自分に、また会う。")
                    .font(LockUDesign.Typography.screenTitle)
                    .foregroundStyle(LockUDesign.Color.schoolNavy)
                if let moment = currentSelfDiscovery {
                    Button("こんな日もあった") { presentedSelfDiscovery = moment }
                        .buttonStyle(LockUPrimaryButtonStyle())
                } else if let pair = currentThenNowPair {
                    Button("この頃と、今") { presentedThenNowPair = pair }
                        .buttonStyle(LockUPrimaryButtonStyle())
                } else {
                    Text("忘れた頃に、\n今日にまた会える。")
                        .font(LockUDesign.Typography.body)
                        .foregroundStyle(LockUDesign.Color.softInkSecondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .sheet(item: $presentedSelfDiscovery) { SelfDiscoveryView(moment: $0) }
        .sheet(item: $presentedThenNowPair) { ThenNowView(pair: $0) }
    }

    private var currentSelfDiscovery: SelfDiscoveryMoment? {
        SelfDiscoveryService().moment(for: demoClock.now, memories: memoryRepository.memories)
    }

    private var currentThenNowPair: ThenNowMemoryPair? {
        ThenNowPairingService().pair(for: demoClock.now, memories: memoryRepository.memories)
    }

    private var invitationCard: some View {
        SummerGlassCard {
            VStack(spacing: 18) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LockUDesign.Color.ramuneBlue)
                Text("誰かの青春を\n少しだけ覗いてみる")
                    .font(LockUDesign.Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LockUDesign.Color.schoolNavy)
                avatarStack
                Button("はじめる") {
                    withAnimation(.easeInOut(duration: 0.22)) { hasStarted = true }
                }
                .buttonStyle(LockUPrimaryButtonStyle())
            }
            .padding(24)
        }
    }

    private var avatarStack: some View {
        HStack(spacing: -9) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(avatarColor(index))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(LockUDesign.Color.textSecondary)
                    )
                    .overlay(Circle().stroke(LockUDesign.Color.surface, lineWidth: 3))
            }
        }
        .accessibilityLabel("友達3人")
    }

    private func avatarColor(_ index: Int) -> Color {
        switch index {
        case 0: return LockUDesign.Color.accentSoft
        case 1: return LockUDesign.Color.mutedLavender.opacity(0.55)
        default: return LockUDesign.Color.warmAccent.opacity(0.35)
        }
    }

    private var codeEntry: some View {
        SummerGlassCard {
            VStack(spacing: 16) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(LockUDesign.Color.ramuneBlue)
                Text("友だちから届いたコードを入力してね")
                    .font(LockUDesign.Typography.sectionTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LockUDesign.Color.schoolNavy)
                TextField("LOCK-24", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.75)))
                    .accessibilityLabel("ロッカーコード")
                Button("ロッカーをのぞく") {
                    submittedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .buttonStyle(LockUPrimaryButtonStyle())
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("コードは友だちの共有画面に表示されています")
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
            }
            .padding(24)
        }
    }

    private func preview(code: String) -> some View {
        SummerGlassCard {
            VStack(spacing: 15) {
                Image(systemName: "eye.fill")
                    .font(.title2)
                    .foregroundStyle(LockUDesign.Color.ramuneBlue)
                Text("今日のプレビュー")
                    .font(LockUDesign.Typography.caption)
                    .tracking(2)
                Text("ロッカー \(code)")
                    .font(LockUDesign.Typography.screenTitle)
                Text("Haruのロッカー")
                    .font(LockUDesign.Typography.body)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
                VStack(spacing: 8) {
                    LinearGradient(
                        colors: [
                            LockUDesign.Color.summerSkyTop,
                            LockUDesign.Color.sunsetPeach.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 68))
                            .foregroundStyle(.white.opacity(0.78))
                            .padding()
                    }
                    .aspectRatio(4 / 3, contentMode: .fit)
                    Text("夏休みまであと3日")
                        .font(LockUDesign.Typography.caption)
                        .foregroundStyle(LockUDesign.Color.softInk)
                }
                .padding(10)
                .background(LockUDesign.Color.notebookPaper)
                .rotationEffect(.degrees(-1))
                .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.1), radius: 8, y: 4)
                Button("このロッカーをのぞく") {}
                    .buttonStyle(LockUPrimaryButtonStyle())
                Button("別のコードを試す") {
                    submittedCode = nil
                    self.code = ""
                }
                .buttonStyle(LockUSecondaryButtonStyle())
            }
            .foregroundStyle(LockUDesign.Color.schoolNavy)
            .padding(24)
        }
    }
}

private struct DualMemoryPeekView: View {
    private enum Perspective { case whatYouSaw, you }

    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var reflectionRepository: MemoryReflectionRepository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let memory: MemoryRecord
    let onClose: () -> Void
    let onReflect: (String) throws -> Void
    @State private var perspective: Perspective = .whatYouSaw
    @State private var reflectionText = ""
    @State private var isEditingReflection = false
    @State private var reflectionError: String?
    @FocusState private var reflectionFocused: Bool

    var body: some View {
        ZStack {
            LockUPageBackground()
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Memoryを閉じる")
                        Spacer()
                    }

                    Text("PEEK")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(LockUDesign.Color.textSecondary)
                        .padding(.top, 4)
                    peekDate
                        .padding(.top, 8)

                    Group {
                        if hasBothPerspectives {
                            DualMemoryImageSurface(
                                memory: memory,
                                purpose: .peek,
                                targetPointSize: CGSize(width: 500, height: 625),
                                mainCamera: perspective == .whatYouSaw ? .back : .front
                            )
                            .id(perspective == .whatYouSaw ? 0 : 1)
                            .transition(.opacity)
                            .onTapGesture { toggle() }
                            .accessibilityLabel(perspective == .whatYouSaw ? "その時に見ていた景色" : "その時の自分")
                        } else if let image = displayedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                        .aspectRatio(4 / 5, contentMode: .fit)
                        .frame(maxWidth: 500, maxHeight: 520)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .shadow(color: .black.opacity(0.11), radius: 5, y: 3)
                        .padding(.top, 24)

                    if hasBothPerspectives {
                        HStack(spacing: 9) {
                            Text("WHAT YOU SAW").opacity(perspective == .whatYouSaw ? 0.9 : 0.38)
                            Text("·").opacity(0.45)
                            Text("YOU").opacity(perspective == .you ? 0.9 : 0.38)
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .padding(.top, 12)
                        .onTapGesture { toggle() }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(perspective == .whatYouSaw ? "現在はその時に見ていた景色。タップしてその時の自分を表示" : "現在はその時の自分。タップして見ていた景色を表示")
                        .accessibilityAddTraits(.isButton)
                    }

                    thenSection
                        .padding(.top, 24)
                    nowSection
                        .padding(.top, normalizedMemoryNote == nil ? 24 : 28)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(LockUDesign.Color.schoolNavy)
        .onChange(of: reflectionText) { _, value in
            if value.count > MemoryReflectionPolicy.maximumLength {
                reflectionText = String(value.prefix(MemoryReflectionPolicy.maximumLength))
            }
        }
    }

    private var peekDate: some View {
        HStack(spacing: 7) {
            Text(memory.memoryDate.formatted(.dateTime.year().month(.abbreviated).day()).uppercased())
            if let emoji = memory.moodEmoji {
                Text("·")
                Text(emoji)
                    .accessibilityLabel(MemoryMoodEmoji(rawValue: emoji)?.accessibilityLabel ?? emoji)
            }
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .tracking(1.1)
        .foregroundStyle(LockUDesign.Color.textSecondary)
    }

    @ViewBuilder
    private var thenSection: some View {
        if let note = normalizedMemoryNote {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("THEN", accessibilityLabel: "あの日に残した言葉")
                Text(note)
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(LockUDesign.Color.textPrimary)
            }
            .frame(maxWidth: 500, alignment: .leading)
        }
    }

    private var nowSection: some View {
        let reflections = reflectionRepository.reflections(for: memory.id)
        return VStack(alignment: .leading, spacing: 12) {
            sectionLabel("NOW", accessibilityLabel: "今の自分からの振り返り")
            if let latest = reflections.first {
                Text(latest.createdAt.formatted(.dateTime.year().month(.abbreviated).day()).uppercased())
                    .font(LockUDesign.Typography.microLabel)
                    .foregroundStyle(LockUDesign.Color.textSecondary)
                Text(latest.text)
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(LockUDesign.Color.textPrimary)
                    .transition(.opacity)
                ForEach(reflections.dropFirst().prefix(2)) { reflection in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(reflection.createdAt.formatted(.dateTime.year().month(.abbreviated).day()).uppercased())
                            .font(LockUDesign.Typography.microLabel)
                            .foregroundStyle(LockUDesign.Color.textSecondary)
                        Text(reflection.text)
                            .font(LockUDesign.Typography.body)
                            .foregroundStyle(LockUDesign.Color.textPrimary.opacity(0.82))
                    }
                    .padding(.top, 8)
                }
            }

            if isEditingReflection {
                reflectionEditor
                    .transition(.opacity)
            } else {
                Text("この日の自分に、今なら何て言う？")
                    .font(LockUDesign.Typography.body)
                    .foregroundStyle(LockUDesign.Color.textSecondary)
                    .padding(.top, reflections.isEmpty ? 0 : 10)
                Button(reflections.isEmpty ? "ひとこと残す" : "今の言葉を重ねる") {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                        isEditingReflection = true
                        reflectionFocused = true
                    }
                }
                .buttonStyle(LockUSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: reflections.count)
    }

    private var reflectionEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("この日の自分に、今なら何て言う？")
                .font(LockUDesign.Typography.body)
                .foregroundStyle(LockUDesign.Color.textPrimary)
            TextEditor(text: $reflectionText)
                .font(LockUDesign.Typography.body)
                .scrollContentBackground(.hidden)
                .focused($reflectionFocused)
                .frame(minHeight: 86, maxHeight: 120)
                .padding(8)
                .background(LockUDesign.Color.notebookPaper.opacity(0.42), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("この日の自分へのメッセージ")
            HStack {
                Text("\(reflectionText.count) / \(MemoryReflectionPolicy.maximumLength)")
                    .font(LockUDesign.Typography.microLabel)
                    .foregroundStyle(LockUDesign.Color.textSecondary)
                Spacer()
                Button("残す", action: saveReflection)
                    .buttonStyle(LockUPrimaryButtonStyle())
                    .disabled(reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let reflectionError {
                Text(reflectionError)
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.warning)
            }
        }
    }

    private func sectionLabel(_ title: String, accessibilityLabel: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(LockUDesign.Color.textSecondary)
            .accessibilityLabel(accessibilityLabel)
    }

    private func saveReflection() {
        reflectionError = nil
        do {
            try onReflect(reflectionText)
            reflectionText = ""
            reflectionFocused = false
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                isEditingReflection = false
            }
        } catch {
            reflectionError = error.localizedDescription
        }
    }

    private var displayedImage: UIImage? {
        let target = CGSize(width: 500, height: 760)
        if perspective == .you, let front = memoryRepository.frontImage(for: memory, purpose: .peek, targetPointSize: target) { return front }
        return memoryRepository.backImage(for: memory, purpose: .peek, targetPointSize: target)
            ?? memoryRepository.frontImage(for: memory, purpose: .peek, targetPointSize: target)
    }

    private var hasBothPerspectives: Bool {
        memoryRepository.hasFrontImage(for: memory)
            && memoryRepository.hasBackImage(for: memory)
    }

    private var normalizedMemoryNote: String? {
        guard let note = memory.memoryNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }
        return note
    }

    private func toggle() {
        guard hasBothPerspectives else { return }
        let change = { perspective = perspective == .whatYouSaw ? .you : .whatYouSaw }
        if reduceMotion { change() }
        else { withAnimation(.easeInOut(duration: 0.24)) { change() } }
    }
}

private struct RevisitExperienceView: View {
    @EnvironmentObject private var lockerCanvasRepository: LockerCanvasRepository
    private enum DualPerspective: Hashable { case whatYouSaw, you }
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var reflectionRepository: MemoryReflectionRepository
    @EnvironmentObject private var demoClock: LockUDemoClock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let presentation: RevisitPresentation
    let onClose: () -> Void
    let onSkip: () throws -> Void
    let onComplete: (String) throws -> Void

    @State private var reflectionText = ""
    @State private var appeared = false
    @State private var isCompletingRevisit = false
    @State private var completionError: String?
    @State private var dualPerspective: DualPerspective = .whatYouSaw
    @State private var isReflectionEditorPresented = false
    @State private var didCompleteReflection = false
    @State private var presentedThenNowPair: ThenNowMemoryPair?
    @FocusState private var reflectionFocused: Bool

    private let reflectionLimit = MemoryReflectionPolicy.maximumLength

    var body: some View {
        ZStack {
            LockUPageBackground()
            ScrollView {
                VStack(spacing: 0) {
                    header
                    revisitContext
                        .padding(.top, 14)
                    memoryImage
                        .padding(.top, 24)
                    if hasFrontPerspective {
                        perspectiveSelector
                            .padding(.top, 12)
                    }
                    originalContext
                        .padding(.top, 18)
                    if let pair = anchoredThenNowPair {
                        Button("この頃と、今を見る") {
                            presentedThenNowPair = pair
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.68))
                        .frame(minHeight: 44)
                        .accessibilityLabel("あの時と今を見る")
                    }
                    nowReflections
                        .padding(.top, 28)
                    reflectionSection
                        .padding(.top, 22)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.34)) { appeared = true }
            }
        }
        .onChange(of: reflectionText) { _, value in
            if value.count > reflectionLimit {
                reflectionText = String(value.prefix(reflectionLimit))
            }
        }
        .sheet(item: $presentedThenNowPair) { pair in
            ThenNowView(pair: pair)
        }
    }

    private var anchoredThenNowPair: ThenNowMemoryPair? {
        ThenNowPairingService().pair(
            anchoredAt: presentation.memory,
            for: demoClock.now,
            memories: memoryRepository.memories
        )
    }

    private var header: some View {
        HStack {
            Button(action: closeRevisit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("振り返りを閉じる")
            Spacer()
        }
        .foregroundStyle(LockUDesign.Color.schoolNavy)
        .padding(.top, 4)
    }

    private var revisitContext: some View {
        VStack(spacing: 7) {
            Text("PEEK")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.7)
                .foregroundStyle(LockUDesign.Color.textSecondary)
            HStack(spacing: 7) {
                Text(presentation.capturedAt.formatted(.dateTime.year().month(.abbreviated).day()).uppercased())
                if let emoji = presentation.memory.moodEmoji {
                    Text("·")
                    Text(emoji)
                        .accessibilityLabel(MemoryMoodEmoji(rawValue: emoji)?.accessibilityLabel ?? emoji)
                }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(LockUDesign.Color.textSecondary)
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var memoryImage: some View {
        if hasFrontPerspective {
            DualMemoryImageSurface(
                memory: presentation.memory,
                purpose: .peek,
                targetPointSize: CGSize(width: 500, height: 625),
                mainCamera: dualPerspective == .whatYouSaw ? .back : .front
            )
                .aspectRatio(4 / 5, contentMode: .fit)
                .frame(maxWidth: 500, maxHeight: 520)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.11), radius: 5, y: 3)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(reduceMotion || appeared ? 1 : 0.985)
                .contentShape(Rectangle())
                .onTapGesture { togglePerspective() }
                .id(dualPerspective)
                .transition(.opacity)
                .brightness(didCompleteReflection ? 0.025 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.34), value: didCompleteReflection)
        } else if let image = displayedMemoryImage {
            let aspectRatio = max(0.55, min(1.8, image.size.width / max(image.size.height, 1)))
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxWidth: 500, maxHeight: 520)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.11), radius: 5, y: 3)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(reduceMotion || appeared ? 1 : 0.985)
                .contentShape(Rectangle())
                .onTapGesture { togglePerspective() }
                .id(dualPerspective)
                .transition(.opacity)
                .accessibilityLabel(isShowingFront ? "その時の自分" : "その時に見ていた景色")
                .brightness(didCompleteReflection ? 0.025 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.34), value: didCompleteReflection)
        } else {
            ZStack {
                LockUDesign.Color.notebookPaper.opacity(0.55)
                Image(systemName: "photo")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(LockUDesign.Color.softInkSecondary.opacity(0.55))
            }
            .frame(maxWidth: 500)
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityLabel("思い出の写真を表示できません")
        }
    }

    private var displayedMemoryImage: UIImage? {
        let target = CGSize(width: 500, height: 760)
        if dualPerspective == .you, let front = memoryRepository.frontImage(for: presentation.memory, purpose: .peek, targetPointSize: target) {
            return front
        }
        return memoryRepository.backImage(for: presentation.memory, purpose: .peek, targetPointSize: target)
            ?? memoryRepository.frontImage(for: presentation.memory, purpose: .peek, targetPointSize: target)
    }

    private var hasFrontPerspective: Bool {
        presentation.memory.isDualCameraMemory
            && memoryRepository.hasBackImage(for: presentation.memory)
            && memoryRepository.hasFrontImage(for: presentation.memory)
    }

    private var isShowingFront: Bool {
        dualPerspective == .you || !memoryRepository.hasBackImage(for: presentation.memory)
    }

    private var perspectiveSelector: some View {
        HStack(spacing: 9) {
            Text("WHAT YOU SAW")
                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(dualPerspective == .whatYouSaw ? 0.86 : 0.38))
            Text("·").foregroundStyle(LockUDesign.Color.softInkSecondary.opacity(0.5))
            Text("YOU")
                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(dualPerspective == .you ? 0.86 : 0.38))
        }
        .font(.system(size: 10, weight: .semibold))
        .tracking(1.2)
        .onTapGesture { togglePerspective() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dualPerspective == .whatYouSaw ? "現在はその時に見ていた景色。タップしてその時の自分を表示" : "現在はその時の自分。タップして見ていた景色を表示")
        .accessibilityAddTraits(.isButton)
    }

    private func togglePerspective() {
        guard hasFrontPerspective else { return }
        let change = {
            dualPerspective = dualPerspective == .whatYouSaw ? .you : .whatYouSaw
        }
        if reduceMotion { change() }
        else { withAnimation(.easeInOut(duration: 0.24)) { change() } }
    }

    @ViewBuilder
    private var originalContext: some View {
        if let note = presentation.memory.memoryNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
            Text("THEN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(LockUDesign.Color.textSecondary)
                .accessibilityLabel("あの日に残した言葉")
                Text(note)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(LockUDesign.Color.textPrimary)
                    .lineSpacing(5)
            }
            .frame(maxWidth: 500, alignment: .leading)
        }
    }

    @ViewBuilder
    private var reflectionSection: some View {
        if isReflectionEditorPresented {
            reflectionEditor
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if didCompleteReflection {
            Button("ロッカーへ戻る", action: onClose)
                .buttonStyle(LockUSecondaryButtonStyle())
                .frame(maxWidth: 500)
        } else {
            VStack(spacing: 12) {
                Text("この日の自分に、今なら何て言う？")
                    .font(LockUDesign.Typography.body)
                    .foregroundStyle(LockUDesign.Color.softInk)
                    .multilineTextAlignment(.center)
                Button("ひとこと残す") {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                        isReflectionEditorPresented = true
                    }
                }
                .buttonStyle(LockUPrimaryButtonStyle())
                Button("ロッカーに残す") {
                    do {
                        try lockerCanvasRepository.addMemory(presentation.memory.id)
                    } catch {
                        completionError = error.localizedDescription
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.72))
                .frame(minHeight: 44)
                .accessibilityLabel("ロッカーに残す")
                Button("今回は残さない") { skipRevisit() }
                    .buttonStyle(.plain)
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: 500)
        }
    }

    private var reflectionEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("この日の自分に、今なら何て言う？")
                .font(LockUDesign.Typography.sectionTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                ForEach(quickResponses, id: \.self) { response in
                    Button(response) { reflectionText = response }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.82))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            LockUDesign.Color.notebookPaper.opacity(0.72),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityLabel("返す言葉、\(response)")
                }
            }

            ZStack(alignment: .topLeading) {
                if reflectionText.isEmpty {
                    Text("あの時の自分へ…")
                        .font(LockUDesign.Typography.body)
                        .foregroundStyle(LockUDesign.Color.softInkSecondary.opacity(0.62))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $reflectionText)
                    .font(LockUDesign.Typography.body)
                    .foregroundStyle(LockUDesign.Color.softInk)
                    .scrollContentBackground(.hidden)
                    .focused($reflectionFocused)
                    .frame(minHeight: 82, maxHeight: 112)
                    .padding(.horizontal, -1)
                    .background(LockUDesign.Color.notebookPaper.opacity(0.28))
                    .accessibilityLabel("この日の自分へのメッセージ")
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(LockUDesign.Color.schoolNavy.opacity(reflectionFocused ? 0.34 : 0.14))
                    .frame(height: 1)
            }

            if reflectionText.count >= 130 {
                Text("\(reflectionText.count) / \(reflectionLimit)")
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let completionError {
                Text(completionError)
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.warning)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel(completionError)
            }

            Button {
                completeRevisit()
            } label: {
                if isCompletingRevisit {
                    HStack(spacing: 8) { ProgressView(); Text("保存しています…") }
                } else {
                    Text("残す")
                }
            }
            .buttonStyle(LockUPrimaryButtonStyle())
            .disabled(isCompletingRevisit || reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(isCompletingRevisit ? "振り返りを保存中" : "振り返りを完了する")

            Button("戻る") {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    isReflectionEditorPresented = false
                    reflectionFocused = false
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(LockUDesign.Color.softInkSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .frame(maxWidth: 500, alignment: .leading)
    }

    @ViewBuilder
    private var nowReflections: some View {
        let reflections = reflectionRepository.reflections(for: presentation.memoryID)
        if !reflections.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("NOW · \(reflections[0].createdAt.formatted(.dateTime.year().month(.abbreviated).day()).uppercased())")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(LockUDesign.Color.textSecondary)
                    .accessibilityLabel("今の自分からの振り返り")
                ForEach(Array(reflections.prefix(3).enumerated()), id: \.element.id) { index, reflection in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(reflection.text)
                            .font(index == 0 ? .system(size: 16, weight: .regular) : LockUDesign.Typography.body)
                            .foregroundStyle(LockUDesign.Color.textPrimary.opacity(index == 0 ? 1 : 0.82))
                            .lineSpacing(index == 0 ? 5 : 3)
                        if index > 0 {
                            Text(reflection.createdAt.formatted(.dateTime.year().month(.abbreviated).day()).uppercased())
                                .font(LockUDesign.Typography.microLabel)
                                .foregroundStyle(LockUDesign.Color.textSecondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: 500, alignment: .leading)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.34), value: reflections.count)
        }
    }

    private var quickResponses: [String] {
        ["よくやってた", "大丈夫だったよ", "懐かしい", "この頃も好き", "自分なりに頑張ってた", "意外と楽しそう", "ちゃんと進んでた", "あの時は大変だったね"]
    }

    private func completeRevisit() {
        guard !isCompletingRevisit else { return }
        isCompletingRevisit = true
        completionError = nil
        do {
            try onComplete(reflectionText)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            reflectionFocused = false
            isCompletingRevisit = false
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.34)) {
                isReflectionEditorPresented = false
                didCompleteReflection = true
            }
        } catch {
            isCompletingRevisit = false
            completionError = "振り返りを保存できませんでした。もう一度試してください。"
            LockULog.error(.workflow, "Revisit completion failed: \(error.localizedDescription)")
        }
    }

    private func skipRevisit() {
        guard !isCompletingRevisit else { return }
        isCompletingRevisit = true
        do {
            try onSkip()
        } catch {
            isCompletingRevisit = false
            completionError = "振り返りを閉じられませんでした。もう一度試してください。"
        }
    }

    private func closeRevisit() {
        if didCompleteReflection {
            onClose()
        } else {
            skipRevisit()
        }
    }
}
