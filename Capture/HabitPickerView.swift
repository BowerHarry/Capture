import SwiftUI

struct HabitPickerView: View {
    @EnvironmentObject var habitManager: HabitManager
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedHabit: Habit?
    @State private var showingCreate = false
    @State private var initialName: String? = nil
    @State private var initialCategory: String? = nil
    @State private var initialIcon: String? = nil
    @State private var initialColor: String? = nil
    @State private var sheetVersion: Int = 0
    
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a habit").font(.title3).fontWeight(.semibold)
                    Text("Start with a popular habit or create your own").font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(habitManager.availableHabits) { suggestion in
                            Button(action: {
                                initialName = suggestion.name
                                initialCategory = suggestion.category
                                initialIcon = suggestion.icon
                                initialColor = suggestion.color
                                sheetVersion &+= 1
                                DispatchQueue.main.async { showingCreate = true }
                            }) {
                                SuggestionCard(name: suggestion.name, icon: suggestion.icon, colorName: suggestion.color, category: suggestion.category)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                
                Button(action: {
                    initialName = nil
                    initialCategory = nil
                    initialIcon = nil
                    initialColor = nil
                    sheetVersion &+= 1
                    DispatchQueue.main.async { showingCreate = true }
                }) {
                    HStack(spacing: 8) {
                        Text("✨")
                        Text("Create custom habit").font(.subheadline).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Cancel") { dismiss() } } }
            .task { await habitManager.loadAvailableHabits() }
            .onChange(of: selectedHabit?.id) { newId in if newId != nil { dismiss() } }
            .sheet(isPresented: $showingCreate) {
                CustomHabitView(
                    onCreated: { habit in selectedHabit = habit },
                    initialName: initialName,
                    initialIcon: initialIcon,
                    initialCategory: initialCategory,
                    initialColor: initialColor
                ).id(sheetVersion)
            }
        }
    }
}

private struct SuggestionCard: View {
    let name: String
    let icon: String?
    let colorName: String?
    let category: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon ?? "⭐️")
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(Circle())
            VStack(spacing: 2) {
                Text(name).font(.subheadline).fontWeight(.semibold).multilineTextAlignment(.center).foregroundColor(.primary)
                Text(category).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
    
    private var color: Color {
        switch colorName?.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        default: return .blue
        }
    }
}
