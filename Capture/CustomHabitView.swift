import SwiftUI

struct CustomHabitView: View {
    @EnvironmentObject var habitManager: HabitManager
    @Environment(\.dismiss) private var dismiss
    let onCreated: (Habit) -> Void
    
    // Optional initial values to prefill from a suggestion
    var initialName: String? = nil
    var initialIcon: String? = nil
    var initialCategory: String? = nil
    var initialColor: String? = nil
    
    @State private var name: String = ""
    @State private var selectedEmoji: String? = nil
    @State private var selectedCategory: String = "Health"
    @State private var selectedColor: String = "blue"
    @State private var targetNumber: String = "1"
    @State private var period: TargetFrequency = .daily
    
    private let emojis: [String] = ["🏃‍♂️","📖","🧘‍♂️","💧","📓","🗣️","🥗","🚶‍♂️","🏊‍♂️","🎸","🧠","🧹","🛏️","📝","🧩","🕺"]
    private let colors: [String] = ["red","orange","yellow","green","blue","purple","pink","cyan"]
    private let categories: [String] = ["Health","Wellness","Fitness","Learning"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack { Spacer(); Text("Customise Your Habit").font(.headline).fontWeight(.semibold); Spacer() }
                    .padding(.top)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Habit name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Habit name").font(.subheadline).foregroundColor(.secondary)
                            TextField("e.g. Morning Workout", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Icon grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon").font(.subheadline).foregroundColor(.secondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button(action: { selectedEmoji = emoji }) {
                                        Text(emoji)
                                            .frame(width: 36, height: 36)
                                            .background(selectedEmoji == emoji ? Color.black : Color(.systemGray6))
                                            .foregroundColor(selectedEmoji == emoji ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category").font(.subheadline).foregroundColor(.secondary)
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(categories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Color grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color").font(.subheadline).foregroundColor(.secondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                                ForEach(colors, id: \.self) { color in
                                    Button(action: { selectedColor = color }) {
                                        Circle()
                                            .fill(colorToSwiftUIColor(color))
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle().stroke(Color.black, lineWidth: selectedColor == color ? 2 : 0)
                                            )
                                    }
                                }
                            }
                        }
                        
                        // Target
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Target").font(.subheadline).foregroundColor(.secondary)
                            HStack(spacing: 10) {
                                TextField("1", text: $targetNumber)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 60)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Picker("Period", selection: $period) {
                                    ForEach(TargetFrequency.allCases, id: \.self) { f in
                                        Text(f.displayName).tag(f)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        // Preview
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Preview").font(.subheadline).foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                Text(selectedEmoji ?? "⭐️")
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(colorToSwiftUIColor(selectedColor))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name.isEmpty ? "Habit name" : name)
                                        .font(.headline)
                                    Text(selectedCategory)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button(action: createHabit) {
                    Text("Create Habit")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isValid ? Color.black : Color(.systemGray5))
                        .foregroundColor(isValid ? .white : .secondary)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .disabled(!isValid)
            }
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .onAppear {
                if let initialName = initialName { name = initialName }
                if let initialIcon = initialIcon { selectedEmoji = initialIcon }
                if let initialCategory = initialCategory { selectedCategory = initialCategory }
                if let initialColor = initialColor { selectedColor = initialColor }
            }
        }
    }
    
    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard selectedEmoji != nil else { return false }
        guard Int(targetNumber) ?? 0 > 0 else { return false }
        return true
    }
    
    private func createHabit() {
        guard let count = Int(targetNumber) else { return }
        let manager = habitManager
        Task {
            if initialName != nil {
                if let habit = await manager.createTrackedHabit(name: name, category: selectedCategory, targetNumber: count, period: period) {
                    onCreated(habit)
                    dismiss()
                }
            } else {
                if let emoji = selectedEmoji, let habit = await manager.createCustomHabit(
                    name: name,
                    icon: emoji,
                    color: selectedColor,
                    category: selectedCategory,
                    targetNumber: count,
                    period: period
                ) {
                    onCreated(habit)
                    dismiss()
                }
            }
        }
    }
    
    private func colorToSwiftUIColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .blue
        }
    }
}
