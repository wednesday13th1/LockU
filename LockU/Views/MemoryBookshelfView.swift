import SwiftUI

struct MemoryMonth: Identifiable, Hashable {
    let startDate: Date
    let memories: [MemoryRecord]
    var id: Date { startDate }
}

struct MemoryBookshelfView: View {
    @EnvironmentObject private var repository: MemoryRepository
    @State private var selectedMonthID: Date?

    private var months: [MemoryMonth] {
        let calendar = Calendar.current
        return Dictionary(grouping: repository.memories) { memory in
            calendar.date(from: calendar.dateComponents([.year, .month], from: memory.createdAt))
                ?? memory.createdAt
        }
        .map { MemoryMonth(startDate: $0.key, memories: $0.value.sorted { $0.createdAt > $1.createdAt }) }
        .sorted { $0.startDate > $1.startDate }
    }

    private var selectedMonth: MemoryMonth? {
        if let selectedMonthID,
           let selected = months.first(where: { $0.id == selectedMonthID }) {
            return selected
        }
        return months.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockUPageBackground()
                VStack(spacing: 14) {
                    header
                    if let selectedMonth {
                        memoryGrid(selectedMonth)
                    } else {
                        ContentUnavailableView(
                            "最初の思い出を残そう",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("今日の写真がここに並びます。")
                        )
                        .foregroundStyle(LockUDesign.Color.textPrimary)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if selectedMonthID == nil { selectedMonthID = months.first?.id }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("思い出")
                .font(LockUDesign.Typography.screenTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
            Spacer()
            Menu {
                ForEach(months) { month in
                    Button(month.startDate.formatted(.dateTime.month(.wide).year())) {
                        selectedMonthID = month.id
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedMonth?.startDate.formatted(.dateTime.month(.abbreviated)) ?? "Month")
                    Image(systemName: "chevron.down")
                }
                .font(LockUDesign.Typography.caption)
                .foregroundStyle(LockUDesign.Color.textPrimary)
                .frame(minWidth: 78, minHeight: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .background(LockUDesign.Color.glassWhite, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.62), lineWidth: 0.8)
                }
            }
            .accessibilityLabel("月を選択")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func memoryGrid(_ month: MemoryMonth) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 11, alignment: .top),
                    count: 3
                ),
                spacing: 15
            ) {
                ForEach(month.memories) { memory in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(memory.createdAt.formatted(.dateTime.day()))
                                .font(LockUDesign.Typography.microLabel)
                                .foregroundStyle(LockUDesign.Color.textPrimary)
                            Spacer()
                            Text(memory.createdAt.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 9))
                                .foregroundStyle(LockUDesign.Color.textSecondary)
                        }
                        LockUPhotoCard {
                            Group {
                                if memory.isDualCameraMemory {
                                    DualMemoryImageSurface(
                                        memory: memory,
                                        purpose: .detail,
                                        targetPointSize: CGSize(width: 150, height: 200)
                                    )
                                } else if let image = repository.image(for: memory, purpose: .detail, targetPointSize: CGSize(width: 150, height: 200)) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        LockUDesign.Color.surfaceMuted
                                        Image(systemName: "photo")
                                            .foregroundStyle(LockUDesign.Color.textSecondary)
                                    }
                                }
                            }
                            .aspectRatio(0.75, contentMode: .fit)
                            .clipped()
                        }
                    }
                    .padding(7)
                    .background(LockUDesign.Color.notebookPaper.opacity(0.94))
                    .rotationEffect(.degrees(rotation(for: memory.id)))
                    .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.08), radius: 8, y: 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "Memory from \(memory.createdAt.formatted(date: .long, time: .omitted))"
                    )
                    .contextMenu {
                        Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                        if let filmName = memory.dailyFilmName {
                            Label(filmName, systemImage: "camera.filters")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func rotation(for id: UUID) -> Double {
        let checksum = id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(checksum % 5 - 2) * 0.45
    }
}
