import SwiftUI

struct MemoryMonth: Identifiable, Hashable {
    let startDate: Date
    let memories: [MemoryRecord]
    var id: Date { startDate }
}

struct MemoryBookshelfView: View {
    @EnvironmentObject private var repository: MemoryRepository

    private var months: [MemoryMonth] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: repository.memories) { memory in
            calendar.date(from: calendar.dateComponents([.year, .month], from: memory.createdAt))
                ?? memory.createdAt
        }
        return groups
            .map { MemoryMonth(startDate: $0.key, memories: $0.value) }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if months.isEmpty {
                    ContentUnavailableView(
                        "Your first chapter is waiting",
                        systemImage: "book.closed",
                        description: Text("Save today's photo and it will appear here.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 145), spacing: 18)],
                        spacing: 22
                    ) {
                        ForEach(months) { month in
                            NavigationLink(value: month) {
                                MonthBookCover(month: month)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Memory Book")
            .navigationDestination(for: MemoryMonth.self) { month in
                MemoryMonthView(month: month)
            }
        }
    }
}

private struct MonthBookCover: View {
    let month: MemoryMonth

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Text(month.startDate.formatted(.dateTime.month(.wide)))
                .font(.title2.bold())
            Text(month.startDate.formatted(.dateTime.year()))
                .font(.subheadline)
            Text("\(month.memories.count) memories")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(LockUDesign.Color.ink)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 205, alignment: .leading)
        .background(
            LinearGradient(
                colors: [LockUDesign.Color.cream, LockUDesign.Color.lavender.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(.black.opacity(0.12)).frame(width: 7)
        }
        .shadow(color: LockUDesign.shadow, radius: 12, x: 4, y: 7)
    }
}

private struct MemoryMonthView: View {
    @EnvironmentObject private var repository: MemoryRepository
    let month: MemoryMonth

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 4)],
                spacing: 4
            ) {
                ForEach(month.memories.sorted { $0.createdAt > $1.createdAt }) { memory in
                    if let image = repository.image(for: memory) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                            .overlay(alignment: .bottomLeading) {
                                Text(memory.createdAt.formatted(.dateTime.day()))
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.35), in: Circle())
                                    .padding(6)
                            }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle(month.startDate.formatted(.dateTime.month(.wide).year()))
        .navigationBarTitleDisplayMode(.inline)
    }
}
