# Swift Code Updates for Habit Template System

## Overview
This document outlines the necessary changes to the Swift codebase to support the new habit template system where trending and discovery are based on habit templates rather than individual habits.

## 1. Update Models.swift

### Add HabitTemplate Model
```swift
// Add to Models.swift
struct HabitTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let category: String
    let targetFrequency: String
    let targetCount: Int?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case targetFrequency = "target_frequency"
        case targetCount = "target_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### Update HabitCapture Model
```swift
// Update HabitCapture in Models.swift
struct HabitCapture: Identifiable, Codable {
    let id: UUID
    let habitId: UUID?           // Keep for user-specific operations
    let habitTemplateId: UUID?   // NEW: For trending and discovery
    let userId: UUID
    let imageUrl: String?
    let caption: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case habitTemplateId = "habit_template_id"  // NEW
        case userId = "user_id"
        case imageUrl = "image_url"
        case caption
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### Update TrendingCapture Model
```swift
// Update TrendingCapture in Models.swift
struct TrendingCapture: Identifiable, Codable {
    let id: UUID
    let captureId: UUID
    let habitTemplateId: UUID    // Changed from habitId
    let userId: UUID
    let imageUrl: String?
    let caption: String?
    let isPublic: Bool
    let captureCreatedAt: Date
    let habitName: String
    let habitCategory: String
    let userDisplayName: String?
    let userAvatarUrl: String?
    let likeCount: Int
    let totalCaptures: Int
    let trendScore: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case captureId = "capture_id"
        case habitTemplateId = "habit_template_id"  // Changed
        case userId = "user_id"
        case imageUrl = "image_url"
        case caption
        case isPublic = "is_public"
        case captureCreatedAt = "capture_created_at"
        case habitName = "habit_name"
        case habitCategory = "habit_category"
        case userDisplayName = "user_display_name"
        case userAvatarUrl = "user_avatar_url"
        case likeCount = "like_count"
        case totalCaptures = "total_captures"
        case trendScore = "trend_score"
    }
}
```

## 2. Update SupabaseManager.swift

### Update insertCapture Method
```swift
// Update in SupabaseManager.swift
func insertCapture(habitId: String, userId: UUID, imageUrl: String, caption: String?, isPublic: Bool) async throws -> HabitCapture {
    NSLog("[SupabaseManager] insertCapture: starting with habitId=%@, userId=%@", habitId, userId.uuidString)
    
    // Validate habitId format
    guard let habitUUID = UUID(uuidString: habitId) else {
        NSLog("[SupabaseManager] insertCapture: ERROR - Invalid habitId format: %@", habitId)
        throw NSError(domain: "ValidationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid habit ID format"])
    }
    
    // Get habit template ID from user_habits
    let userHabits: [UserHabit] = try await client.database
        .from("user_habits")
        .select("habit_template_id")
        .eq("id", value: habitUUID)
        .limit(1)
        .execute()
        .value
    
    guard let userHabit = userHabits.first else {
        throw NSError(domain: "ValidationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit not found"])
    }
    
    struct InsertCapture: Encodable {
        let habit_id: UUID
        let habit_template_id: UUID  // NEW
        let user_id: UUID
        let image_url: String
        let caption: String?
        let is_public: Bool
    }
    
    let payload = InsertCapture(
        habit_id: habitUUID,
        habit_template_id: userHabit.habitTemplateId,  // NEW
        user_id: userId, 
        image_url: imageUrl, 
        caption: caption, 
        is_public: isPublic
    )
    
    NSLog("[SupabaseManager] insertCapture: created payload with habit_id=%@, habit_template_id=%@", 
          payload.habit_id.uuidString, payload.habit_template_id.uuidString)
    
    do {
        let rows: [HabitCapture] = try await client.database
            .from("captures")
            .insert(payload)
            .select()
            .limit(1)
            .execute()
            .value
        
        guard let row = rows.first else {
            NSLog("[SupabaseManager] insertCapture: ERROR - No rows returned from insert")
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create capture"])
        }
        
        NSLog("[SupabaseManager] insertCapture: successfully inserted capture %@", row.id.uuidString)
        return row
    } catch {
        NSLog("[SupabaseManager] insertCapture: ERROR during database operation: %@", error.localizedDescription)
        throw error
    }
}
```

### Update createHabitDirect Method
```swift
// Update in SupabaseManager.swift
func createHabitDirect(name: String, description: String?, category: String, targetFrequency: String, targetCount: Int? = nil) async throws -> Habit {
    let session = try await client.auth.session
    
    // First, try to find an existing habit template with the same name and category
    let existingTemplates: [HabitTemplate] = try await client.database
        .from("habit_templates")
        .select()
        .eq("name", value: name)
        .eq("category", value: category)
        .eq("is_active", value: true)
        .limit(1)
        .execute()
        .value
    
    // If template exists, check if user already has this habit
    if let existingTemplate = existingTemplates.first {
        let existingUserHabits: [UserHabit] = try await client.database
            .from("user_habits")
            .select()
            .eq("user_id", value: session.user.id)
            .eq("habit_template_id", value: existingTemplate.id)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        
        if let existingUserHabit = existingUserHabits.first {
            // User already has this habit, return the existing one
            NSLog("[SupabaseManager] createHabitDirect: user already has habit %@ for template %@", 
                  existingUserHabit.id.uuidString, existingTemplate.id.uuidString)
            
            return Habit(
                id: existingUserHabit.id,
                name: existingTemplate.name,
                icon: nil,
                color: nil,
                category: existingTemplate.category,
                target: existingTemplate.targetCount ?? 1,
                targetFrequency: existingTemplate.targetFrequency,
                targetCount: existingTemplate.targetCount,
                currentStreak: existingUserHabit.currentStreak,
                longestStreak: 0,
                isActive: existingUserHabit.isActive,
                createdAt: existingUserHabit.createdAt,
                updatedAt: existingUserHabit.updatedAt,
                userId: existingUserHabit.userId
            )
        }
    }
    
    // Find or create the habit template
    let template: HabitTemplate
    
    if let existingTemplate = existingTemplates.first {
        // Reuse existing template
        NSLog("[SupabaseManager] createHabitDirect: reusing existing template %@ for habit '%@'", 
              existingTemplate.id.uuidString, name)
        template = existingTemplate
    } else {
        // Create new habit template
        struct CreateHabitTemplate: Encodable {
            let name: String
            let description: String?
            let category: String
            let target_frequency: String
            let target_count: Int?
            let is_active: Bool
        }
        
        let templatePayload = CreateHabitTemplate(
            name: name, 
            description: description, 
            category: category, 
            target_frequency: targetFrequency, 
            target_count: targetCount,
            is_active: true
        )
        
        let templateRows: [HabitTemplate] = try await client.database
            .from("habit_templates")
            .insert(templatePayload)
            .select()
            .limit(1)
            .execute()
            .value
        
        guard let newTemplate = templateRows.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create habit template"])
        }
        
        NSLog("[SupabaseManager] createHabitDirect: created new template %@ for habit '%@'", 
              newTemplate.id.uuidString, name)
        template = newTemplate
    }
    
    // Create the user habit instance
    struct CreateUserHabit: Encodable {
        let habit_template_id: UUID
        let user_id: UUID
        let current_streak: Int
        let is_active: Bool
    }
    
    let userHabitPayload = CreateUserHabit(
        habit_template_id: template.id,
        user_id: session.user.id,
        current_streak: 0,
        is_active: true
    )
    
    let userHabitRows: [UserHabit] = try await client.database
        .from("user_habits")
        .insert(userHabitPayload)
        .select()
        .limit(1)
        .execute()
        .value
    
    guard let userHabit = userHabitRows.first else {
        throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create user habit"])
    }
    
    // Convert to legacy Habit format for backward compatibility
    return Habit(
        id: userHabit.id,
        name: template.name,
        icon: nil,
        color: nil,
        category: template.category,
        target: targetCount ?? 1,
        targetFrequency: template.targetFrequency,
        targetCount: template.targetCount,
        currentStreak: userHabit.currentStreak,
        longestStreak: 0,
        isActive: userHabit.isActive,
        createdAt: userHabit.createdAt,
        updatedAt: userHabit.updatedAt,
        userId: userHabit.userId
    )
}
```

## 3. Update HabitManager.swift

### Add Method to Create Habit from Template
```swift
// Add to HabitManager.swift
func createHabitFromTemplate(templateId: UUID) async throws -> Habit {
    guard let currentUser = AuthManager.shared.currentUser else {
        throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
    }
    
    // Check if user already has this habit template
    let existingUserHabits: [UserHabit] = try await supabaseClient.client
        .from("user_habits")
        .select()
        .eq("user_id", value: currentUser.id)
        .eq("habit_template_id", value: templateId)
        .eq("is_active", value: true)
        .limit(1)
        .execute()
        .value
    
    if let existingUserHabit = existingUserHabits.first {
        // User already has this habit, return existing one
        let template: [HabitTemplate] = try await supabaseClient.client
            .from("habit_templates")
            .select()
            .eq("id", value: templateId)
            .limit(1)
            .execute()
            .value
        
        guard let habitTemplate = template.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit template not found"])
        }
        
        return Habit(
            id: existingUserHabit.id,
            name: habitTemplate.name,
            icon: nil,
            color: nil,
            category: habitTemplate.category,
            target: habitTemplate.targetCount ?? 1,
            targetFrequency: habitTemplate.targetFrequency,
            targetCount: habitTemplate.targetCount,
            currentStreak: existingUserHabit.currentStreak,
            longestStreak: 0,
            isActive: existingUserHabit.isActive,
            createdAt: existingUserHabit.createdAt,
            updatedAt: existingUserHabit.updatedAt,
            userId: existingUserHabit.userId
        )
    }
    
    // Create new user habit from template
    struct CreateUserHabit: Encodable {
        let habit_template_id: UUID
        let user_id: UUID
        let current_streak: Int
        let is_active: Bool
    }
    
    let userHabitPayload = CreateUserHabit(
        habit_template_id: templateId,
        user_id: currentUser.id,
        current_streak: 0,
        is_active: true
    )
    
    let userHabitRows: [UserHabit] = try await supabaseClient.client
        .from("user_habits")
        .insert(userHabitPayload)
        .select()
        .limit(1)
        .execute()
        .value
    
    guard let userHabit = userHabitRows.first else {
        throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create user habit"])
    }
    
    // Get template details
    let template: [HabitTemplate] = try await supabaseClient.client
        .from("habit_templates")
        .select()
        .eq("id", value: templateId)
        .limit(1)
        .execute()
        .value
    
    guard let habitTemplate = template.first else {
        throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit template not found"])
    }
    
    let newHabit = Habit(
        id: userHabit.id,
        name: habitTemplate.name,
        icon: nil,
        color: nil,
        category: habitTemplate.category,
        target: habitTemplate.targetCount ?? 1,
        targetFrequency: habitTemplate.targetFrequency,
        targetCount: habitTemplate.targetCount,
        currentStreak: userHabit.currentStreak,
        longestStreak: 0,
        isActive: userHabit.isActive,
        createdAt: userHabit.createdAt,
        updatedAt: userHabit.updatedAt,
        userId: userHabit.userId
    )
    
    // Add to local habits array
    habits.append(newHabit)
    
    return newHabit
}
```

## 4. Update DiscoveryView.swift

### Update Habit Capture Action
```swift
// Update in DiscoveryView.swift - TrendingHabitsSection
.onTapGesture {
    Task {
        // Create habit from template instead of just the name
        await habitManager.createHabitFromTemplate(templateId: habit.id)
    }
}
```

### Update TrendingHabit Model
```swift
// Update TrendingHabit in Models.swift to include template ID
struct TrendingHabit: Identifiable, Codable {
    let id: UUID  // This is now the habit_template_id
    let name: String
    let category: String
    let participants: Int
    let avgStreak: Double
    let description: String
    let captures: [String]?
    let totalCaptures: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case participants
        case avgStreak = "avg_streak"
        case description
        case captures
        case totalCaptures = "total_captures"
    }
}
```

## 5. Update CameraCaptureView.swift

### Update Capture Creation
```swift
// The existing code should work as-is since it uses habitId
// The SupabaseManager.insertCapture method will now automatically
// add the habit_template_id based on the habitId
```

## 6. Update SocialFeedView.swift

### Update Social Feed Models
```swift
// Update SocialFeedPost in Models.swift
struct SocialFeedPost: Identifiable, Codable {
    let captureId: UUID
    let habitId: UUID?           // Keep for backward compatibility
    let habitTemplateId: UUID?   // NEW: For trending and discovery
    let captureUserId: UUID
    let imageUrl: String?
    let caption: String?
    let isPublic: Bool
    let captureCreatedAt: Date
    let habitName: String
    let habitCategory: String
    let userDisplayName: String?
    let userAvatarUrl: String?
    let likeCount: Int
    let likedByUserIds: [UUID]
    let isLikedByCurrentUser: Bool
    
    var id: UUID { captureId }
    
    enum CodingKeys: String, CodingKey {
        case captureId = "capture_id"
        case habitId = "habit_id"
        case habitTemplateId = "habit_template_id"  // NEW
        case captureUserId = "capture_user_id"
        case imageUrl = "image_url"
        case caption
        case isPublic = "is_public"
        case captureCreatedAt = "capture_created_at"
        case habitName = "habit_name"
        case habitCategory = "habit_category"
        case userDisplayName = "user_display_name"
        case userAvatarUrl = "user_avatar_url"
        case likeCount
        case likedByUserIds
        case isLikedByCurrentUser
    }
}
```

## 7. Testing Checklist

### Database Migration
- [ ] Run `migrate_to_habit_templates.sql` in Supabase
- [ ] Verify `captures` table has `habit_template_id` column
- [ ] Verify existing captures have `habit_template_id` populated
- [ ] Test trending views return data correctly

### Swift Code Updates
- [ ] Update Models.swift with new structures
- [ ] Update SupabaseManager.swift with new insertCapture logic
- [ ] Update HabitManager.swift with createHabitFromTemplate method
- [ ] Update DiscoveryView.swift to use template IDs
- [ ] Test habit creation from discovery
- [ ] Test habit creation from home screen
- [ ] Test custom habit creation
- [ ] Verify trending data shows correctly
- [ ] Verify social feed works correctly

### Key Benefits
1. **Unified Trending**: All users tracking the same habit template contribute to trending
2. **Better Discovery**: Users can see how many people are tracking each habit template
3. **Consistent Data**: Habit descriptions and metadata come from templates
4. **Scalable**: New users automatically join existing habit templates
5. **Backward Compatible**: Existing user-specific operations still work with habit IDs

## 8. Migration Notes

- **Existing Data**: All existing captures will be updated to include `habit_template_id`
- **Backward Compatibility**: User-specific operations (streaks, progress) still use `habit_id`
- **Performance**: Trending queries will be faster due to direct template relationships
- **User Experience**: Users will see more meaningful trending data from all users tracking the same habits
