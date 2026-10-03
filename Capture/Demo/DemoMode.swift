#if DEBUG
import Foundation
import UIKit

/// Offline demo mode, used for screenshots and for running the app without a backend.
///
/// Enable it by passing the `-demoMode` launch argument. Add `-demoTab <0...4>` to open
/// on a specific tab. Everything in this folder is compiled into DEBUG builds only.
///
/// When enabled, `SupabaseManager` returns the fixtures in `DemoData` instead of calling
/// the network, and image URLs on `DemoImages.host` are served by `DemoImageProtocol`,
/// which draws placeholder artwork locally. Writes (new captures, follows, comments) are
/// not simulated and will fail as they would with no connection.
enum DemoMode {
    static let isEnabled: Bool = {
        let enabled = ProcessInfo.processInfo.arguments.contains("-demoMode")
        if enabled {
            URLProtocol.registerClass(DemoImageProtocol.self)
        }
        return enabled
    }()

    /// Tab to open on launch, from `-demoTab <index>`. Defaults to the Home tab.
    static var initialTab: Int {
        guard isEnabled else { return 0 }
        return min(4, max(0, UserDefaults.standard.integer(forKey: "demoTab")))
    }
}

// MARK: - Fixtures

enum DemoData {

    // MARK: Building blocks

    struct Kind {
        let key: String
        let name: String
        let category: String
        let symbol: String
        let hue: CGFloat
        let templateId: UUID
        let blurb: String
    }

    struct Person {
        let key: String
        let id: UUID
        let username: String
        let displayName: String
        let bio: String
    }

    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))!
    }

    static let kinds: [Kind] = [
        Kind(key: "run", name: "Morning Run", category: "Fitness", symbol: "figure.run", hue: 0.02, templateId: uuid(301), blurb: "Get outside and move before the day starts."),
        Kind(key: "read", name: "Read 20 Pages", category: "Learning", symbol: "book.fill", hue: 0.60, templateId: uuid(302), blurb: "Twenty pages a day adds up to a shelf a year."),
        Kind(key: "cook", name: "Home-Cooked Dinner", category: "Nutrition", symbol: "fork.knife", hue: 0.08, templateId: uuid(303), blurb: "Cook something from scratch instead of ordering in."),
        Kind(key: "meditate", name: "Meditate", category: "Wellness", symbol: "leaf.fill", hue: 0.38, templateId: uuid(304), blurb: "Ten quiet minutes, phone face down."),
        Kind(key: "sketch", name: "Sketchbook Page", category: "Productivity", symbol: "pencil.and.outline", hue: 0.75, templateId: uuid(305), blurb: "Fill one page, however rough."),
        Kind(key: "family", name: "Call Family", category: "Social", symbol: "phone.fill", hue: 0.14, templateId: uuid(306), blurb: "A proper catch-up, not just a text."),
        Kind(key: "gym", name: "Gym Session", category: "Fitness", symbol: "dumbbell.fill", hue: 0.97, templateId: uuid(307), blurb: "Show up and lift, even on the short days."),
        Kind(key: "guitar", name: "Practice Guitar", category: "Learning", symbol: "guitars.fill", hue: 0.56, templateId: uuid(308), blurb: "Fifteen focused minutes on one piece."),
        Kind(key: "water", name: "Drink 2L Water", category: "Health", symbol: "drop.fill", hue: 0.90, templateId: uuid(309), blurb: "Refill the bottle and snap it when it's empty.")
    ]

    private static func kind(_ key: String) -> Kind {
        kinds.first { $0.key == key }!
    }

    static let me = Person(key: "maya", id: uuid(1), username: "maya", displayName: "Maya", bio: "Small habits, photographed daily.")

    static let people: [Person] = [
        Person(key: "jonas", id: uuid(2), username: "jonas", displayName: "Jonas", bio: "Running before work, mostly."),
        Person(key: "priya", id: uuid(3), username: "priya", displayName: "Priya", bio: "Learning to cook one recipe at a time."),
        Person(key: "tomas", id: uuid(4), username: "tomas", displayName: "Tomás", bio: "Guitar, slowly."),
        Person(key: "aiko", id: uuid(5), username: "aiko", displayName: "Aiko", bio: "Mornings are for sitting still."),
        Person(key: "leah", id: uuid(6), username: "leah", displayName: "Leah", bio: "Three lifts a week.")
    ]

    // MARK: URLs

    private static func captureURL(_ kind: Kind, _ variant: Int) -> String {
        "https://\(DemoImages.host)/capture/\(kind.key)/\(abs(variant) % 6).jpg"
    }

    private static func avatarURL(_ person: Person) -> String {
        "https://\(DemoImages.host)/avatar/\(person.key).jpg"
    }

    // MARK: Dates

    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday, matching HabitManager
        return cal
    }

    /// A time on the day `daysAgo` days back, never later than a few minutes ago.
    private static func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return min(time, Date().addingTimeInterval(-300))
    }

    private static func minutesAgo(_ minutes: Int) -> Date {
        Date().addingTimeInterval(TimeInterval(-60 * minutes))
    }

    // MARK: Current user

    static var currentUser: User {
        User(
            id: me.id,
            email: "maya@example.com",
            username: me.username,
            avatar: avatarURL(me),
            bio: me.bio,
            createdAt: date(daysAgo: 160, hour: 9, minute: 0),
            updatedAt: date(daysAgo: 2, hour: 9, minute: 0),
            followersCount: 48,
            followingCount: 36,
            bestStreak: 41
        )
    }

    // MARK: Habits and captures

    private struct Tracked {
        let index: Int
        let kind: Kind
        let frequency: String
        let target: Int
        let longest: Int
        var id: UUID { DemoData.uuid(100 + index) }
    }

    private static let tracked: [Tracked] = [
        Tracked(index: 0, kind: kind("run"), frequency: "daily", target: 1, longest: 31),
        Tracked(index: 1, kind: kind("read"), frequency: "daily", target: 1, longest: 26),
        Tracked(index: 2, kind: kind("cook"), frequency: "daily", target: 1, longest: 14),
        Tracked(index: 3, kind: kind("meditate"), frequency: "daily", target: 1, longest: 41),
        Tracked(index: 4, kind: kind("sketch"), frequency: "weekly", target: 3, longest: 9),
        Tracked(index: 5, kind: kind("family"), frequency: "weekly", target: 1, longest: 15)
    ]

    static var habits: [Habit] {
        tracked.map { item in
            Habit(
                id: item.id,
                name: item.kind.name,
                category: item.kind.category,
                target: item.target,
                targetFrequency: item.frequency,
                targetCount: item.target,
                currentStreak: 0, // recomputed from captures by HabitManager
                longestStreak: item.longest,
                createdAt: date(daysAgo: 150, hour: 9, minute: 0),
                updatedAt: date(daysAgo: 0, hour: 9, minute: 0),
                userId: me.id
            )
        }
    }

    static var captures: [HabitCapture] {
        var result: [HabitCapture] = []

        func add(_ item: Tracked, daysAgo: Int, hour: Int, minute: Int) {
            guard daysAgo >= 0 else { return }
            let created = date(daysAgo: daysAgo, hour: hour, minute: minute)
            result.append(HabitCapture(
                id: uuid(10_000 + item.index * 1_000 + daysAgo),
                habitId: item.id,
                habitTemplateId: item.kind.templateId,
                userHabitId: item.id,
                userId: me.id,
                imageUrl: captureURL(item.kind, daysAgo),
                caption: nil,
                isPublic: true,
                createdAt: created,
                updatedAt: created
            ))
        }

        // Daily habits: an unbroken recent run, then a patchier history behind it.
        let history = 150
        for d in 0..<history {
            if d < 23 || (d > 23 && d % 6 != 0) { add(tracked[0], daysAgo: d, hour: 7, minute: 10) }
            if (1..<13).contains(d) || (d > 13 && d % 4 != 0) { add(tracked[1], daysAgo: d, hour: 21, minute: 30) }
            if d < 6 || (d > 7 && d % 3 != 0) { add(tracked[2], daysAgo: d, hour: 19, minute: 15) }
            if d < 41 || (d > 42 && d % 5 != 0) { add(tracked[3], daysAgo: d, hour: 6, minute: 45) }
        }

        // Weekly habits, laid out relative to the Monday of the current week.
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let daysIntoWeek = calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0
        for week in 0..<20 {
            let mondayAgo = daysIntoWeek + week * 7
            // Sketchbook: Mon/Wed/Fri, but only two so far this week.
            let sketchDays = week == 0 ? [0, 2] : [0, 2, 4]
            if week < 9 || week % 4 != 0 {
                for offset in sketchDays { add(tracked[4], daysAgo: mondayAgo - offset, hour: 18, minute: 20) }
            }
            // Call family: Tuesdays.
            if week < 15 { add(tracked[5], daysAgo: mondayAgo - 1, hour: 20, minute: 5) }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: Categories

    static let categories: [DatabaseHabitCategory] = [
        DatabaseHabitCategory(id: uuid(201), name: "Fitness", description: "Movement and training", color: "red", icon: "💪", sortOrder: 1),
        DatabaseHabitCategory(id: uuid(202), name: "Wellness", description: "Rest and mindfulness", color: "green", icon: "🧘", sortOrder: 2),
        DatabaseHabitCategory(id: uuid(203), name: "Learning", description: "Reading and practice", color: "blue", icon: "📚", sortOrder: 3),
        DatabaseHabitCategory(id: uuid(204), name: "Nutrition", description: "Food and cooking", color: "orange", icon: "🥗", sortOrder: 4),
        DatabaseHabitCategory(id: uuid(205), name: "Productivity", description: "Making and doing", color: "purple", icon: "⚡", sortOrder: 5),
        DatabaseHabitCategory(id: uuid(206), name: "Health", description: "Everyday health", color: "pink", icon: "❤️", sortOrder: 6),
        DatabaseHabitCategory(id: uuid(207), name: "Social", description: "Friends and family", color: "yellow", icon: "👥", sortOrder: 7)
    ]

    private static func categoryColor(_ name: String) -> String? {
        categories.first { $0.name == name }?.color
    }

    // MARK: Discovery

    private static let trendingOrder: [(key: String, participants: Int, avgStreak: Double, total: Int)] = [
        ("run", 34, 12.4, 187),
        ("meditate", 29, 15.1, 164),
        ("cook", 22, 6.8, 121),
        ("guitar", 17, 9.3, 88),
        ("gym", 15, 5.2, 61),
        ("water", 12, 7.9, 57)
    ]

    static var trendingHabits: [TrendingHabit] {
        trendingOrder.map { entry in
            let k = kind(entry.key)
            return TrendingHabit(
                id: k.templateId,
                name: k.name,
                category: k.category,
                categoryColor: categoryColor(k.category),
                participants: entry.participants,
                avgStreak: entry.avgStreak,
                description: k.blurb,
                captures: (0..<4).map { captureURL(k, $0) },
                totalCaptures: entry.total
            )
        }
    }

    static func trendingHabits(inCategory categoryId: UUID) -> [TrendingHabit] {
        guard let category = categories.first(where: { $0.id == categoryId }) else { return [] }
        return trendingHabits.filter { $0.category == category.name }
    }

    static var trendingCaptures: [TrendingCapture] {
        var result: [TrendingCapture] = []
        for (habitIndex, entry) in trendingOrder.enumerated() {
            let k = kind(entry.key)
            for n in 0..<4 {
                let person = people[(habitIndex + n) % people.count]
                let id = uuid(20_000 + habitIndex * 10 + n)
                result.append(TrendingCapture(
                    id: id,
                    captureId: id,
                    habitTemplateId: k.templateId,
                    userId: person.id,
                    imageUrl: captureURL(k, n),
                    caption: nil,
                    isPublic: true,
                    captureCreatedAt: minutesAgo(90 + habitIndex * 60 + n * 240),
                    habitName: k.name,
                    habitCategory: k.category,
                    habitCategoryId: categories.first { $0.name == k.category }?.id,
                    userDisplayName: person.displayName,
                    userAvatarUrl: avatarURL(person),
                    likeCount: 14 - habitIndex - n,
                    totalCaptures: entry.total,
                    trendScore: Double(entry.total)
                ))
            }
        }
        return result
    }

    static let communityStats = CommunityStats(activeUsers: 128, totalHabits: 64, totalCaptures: 2315)

    static var availableHabits: [AvailableHabit] {
        let extras: [AvailableHabit] = [
            AvailableHabit(id: uuid(401), name: "Stretch for 10 Minutes", icon: "🤸", color: "red", category: "Fitness", description: "Loosen up after sitting all day."),
            AvailableHabit(id: uuid(402), name: "Journal", icon: "📓", color: "purple", category: "Productivity", description: "Three lines about the day."),
            AvailableHabit(id: uuid(403), name: "No Phone After 10pm", icon: "🌙", color: "green", category: "Wellness", description: "Leave it charging in another room."),
            AvailableHabit(id: uuid(404), name: "Practise a Language", icon: "🗣️", color: "blue", category: "Learning", description: "One lesson or one conversation.")
        ]
        let icons = ["run": "🏃", "read": "📚", "cook": "🍳", "meditate": "🧘", "sketch": "✏️", "family": "📞", "gym": "🏋️", "guitar": "🎸", "water": "💧"]
        let fromKinds = kinds.map { k in
            AvailableHabit(id: k.templateId, name: k.name, icon: icons[k.key], color: categoryColor(k.category), category: k.category, description: k.blurb)
        }
        return (fromKinds + extras).sorted { $0.name < $1.name }
    }

    static var users: [User] {
        people.map { person in
            User(id: person.id, email: "\(person.username)@example.com", username: person.username, avatar: avatarURL(person), bio: person.bio)
        }
    }

    // MARK: Social feed

    static var socialFeedGroups: [SocialFeedGroup] {
        let entries: [(person: Person, kind: String, streak: Int, total: Int, reactions: Int, comments: Int, liked: Bool, captions: [String])] = [
            (people[0], "run", 18, 42, 12, 3, true, ["6k along the canal before the rain", "Legs heavy, went anyway", "New route through the park", "Frost on the towpath"]),
            (people[1], "cook", 9, 23, 8, 2, false, ["Dal and rice, finally got the tempering right", "Leftovers count", "First attempt at fresh pasta"]),
            (people[3], "meditate", 44, 61, 15, 1, true, ["Ten minutes on the balcony", "Rainy one today", "Day 43", "Early start"]),
            (people[2], "guitar", 27, 35, 6, 4, false, ["Bar chords are less painful this week", "Slow practice with a metronome", "Learning the intro"]),
            (people[4], "gym", 6, 17, 4, 0, false, ["Squats back up to where they were", "Short session, still counts"])
        ]

        return entries.enumerated().map { index, entry in
            let k = kind(entry.kind)
            let reactors = people.filter { $0.id != entry.person.id }.prefix(3).map {
                SocialFeedReactionUser(id: $0.id, displayName: $0.displayName, avatarUrl: avatarURL($0), username: $0.username)
            }
            let recent = entry.captions.enumerated().map { n, caption in
                SocialFeedCapture(
                    id: uuid(30_000 + index * 10 + n),
                    imageUrl: captureURL(k, n + index),
                    caption: caption,
                    createdAt: minutesAgo(35 + index * 95 + n * 1_440),
                    reactionCount: max(1, entry.reactions - n * 3),
                    commentCount: n == 0 ? entry.comments : 0,
                    isLikedByCurrentUser: n == 0 && entry.liked,
                    reactionUsers: Array(reactors)
                )
            }
            return SocialFeedGroup(
                id: "\(entry.person.id.uuidString)-\(k.templateId.uuidString)",
                userId: entry.person.id,
                habitTemplateId: k.templateId,
                habitName: k.name,
                habitCategory: k.category,
                habitCategoryColor: categoryColor(k.category),
                userDisplayName: entry.person.displayName,
                userAvatarUrl: avatarURL(entry.person),
                userUsername: entry.person.username,
                currentStreak: entry.streak,
                lastCaptureId: recent[0].id,
                lastCaptureImageUrl: recent[0].imageUrl,
                lastCaptureCreatedAt: recent[0].createdAt,
                totalCaptures: entry.total,
                reactionCount: entry.reactions,
                commentCount: entry.comments,
                isLikedByCurrentUser: entry.liked,
                recentCaptures: recent
            )
        }
    }
}

// MARK: - Placeholder artwork

/// Draws the stand-in "photos" and avatars used by demo mode, so the repository does not
/// need to ship any real photographs.
enum DemoImages {
    static let host = "demo.capture.invalid"

    private static let cache = NSCache<NSString, NSData>()

    /// Expects `/capture/<kind>/<variant>.jpg` or `/avatar/<person>.jpg`.
    static func jpegData(for url: URL) -> Data? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let type = parts.first else { return nil }
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached as Data }

        let image: UIImage?
        switch type {
        case "capture" where parts.count >= 3:
            let variant = Int(parts[2].prefix { $0.isNumber }) ?? 0
            image = DemoData.kinds.first { $0.key == parts[1] }.map { capture(kind: $0, variant: variant) }
        case "avatar" where parts.count >= 2:
            let name = String(parts[1].prefix { $0 != "." })
            let everyone = [DemoData.me] + DemoData.people
            image = everyone.firstIndex { $0.key == name }.map { avatar(person: everyone[$0], index: $0) }
        default:
            image = nil
        }

        guard let data = image?.jpegData(compressionQuality: 0.85) else { return nil }
        cache.setObject(data as NSData, forKey: key)
        return data
    }

    private static func format() -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return format
    }

    private static func fillGradient(_ context: CGContext, size: CGSize, from: UIColor, to: UIColor, angle: CGFloat) {
        let colors = [from.cgColor, to.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        let dx = cos(angle) * size.width / 2
        let dy = sin(angle) * size.height / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: center.x - dx, y: center.y - dy),
            end: CGPoint(x: center.x + dx, y: center.y + dy),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private static func capture(kind: DemoData.Kind, variant: Int) -> UIImage {
        let size = CGSize(width: 720, height: 720)
        let v = CGFloat(variant)
        return UIGraphicsImageRenderer(size: size, format: format()).image { renderer in
            let context = renderer.cgContext
            let hue = (kind.hue + v * 0.012).truncatingRemainder(dividingBy: 1)
            fillGradient(
                context,
                size: size,
                from: UIColor(hue: hue, saturation: 0.55, brightness: 0.95 - v * 0.03, alpha: 1),
                to: UIColor(hue: (hue + 0.07).truncatingRemainder(dividingBy: 1), saturation: 0.80, brightness: 0.62, alpha: 1),
                angle: .pi / 4 + v * 0.5
            )

            // Soft shapes so neighbouring tiles don't look identical.
            for i in 0..<3 {
                let t = CGFloat(i) + v * 1.7
                let radius = 150 + 60 * CGFloat(i)
                let center = CGPoint(x: size.width * (0.5 + 0.42 * cos(t * 1.9)), y: size.height * (0.5 + 0.42 * sin(t * 1.3)))
                context.setFillColor(UIColor.white.withAlphaComponent(0.09).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }

            let configuration = UIImage.SymbolConfiguration(pointSize: 230, weight: .semibold)
            if let symbol = UIImage(systemName: kind.symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2)
                context.setShadow(offset: CGSize(width: 0, height: 8), blur: 24, color: UIColor.black.withAlphaComponent(0.18).cgColor)
                symbol.draw(at: origin, blendMode: .normal, alpha: 0.95)
            }
        }
    }

    private static func avatar(person: DemoData.Person, index: Int) -> UIImage {
        let size = CGSize(width: 240, height: 240)
        let hue = (0.58 + CGFloat(index) * 0.17).truncatingRemainder(dividingBy: 1)
        return UIGraphicsImageRenderer(size: size, format: format()).image { renderer in
            fillGradient(
                renderer.cgContext,
                size: size,
                from: UIColor(hue: hue, saturation: 0.45, brightness: 0.92, alpha: 1),
                to: UIColor(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.70, brightness: 0.68, alpha: 1),
                angle: .pi / 3
            )
            let initial = String(person.displayName.prefix(1)) as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let textSize = initial.size(withAttributes: attributes)
            initial.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2), withAttributes: attributes)
        }
    }
}

/// Serves `DemoImages` artwork for requests to `DemoImages.host`, so the app's normal
/// `URLSession`-based image loading and caching paths run unchanged.
final class DemoImageProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == DemoImages.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let data = DemoImages.jpegData(for: url),
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "image/jpeg"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
#endif
