import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case today, week, month, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "7 days"
        case .month: return "30 days"
        case .all: return "All time"
        }
    }

    func start(now: Date, calendar: Calendar = .current) -> Date? {
        let day = calendar.startOfDay(for: now)
        switch self {
        case .today: return day
        case .week: return calendar.date(byAdding: .day, value: -6, to: day)
        case .month: return calendar.date(byAdding: .day, value: -29, to: day)
        case .all: return nil
        }
    }
}

enum HeatScale: String, CaseIterable, Identifiable {
    case linear, sqrt, log
    var id: String { rawValue }

    var title: String {
        switch self {
        case .linear: return "Linear"
        case .sqrt: return "Square root"
        case .log: return "Log"
        }
    }

    /// Map a count onto 0...1 relative to the largest count.
    func normalize(_ count: Int, max: Int) -> Double {
        guard count > 0, max > 0 else { return 0 }
        let ratio = Double(count) / Double(max)
        switch self {
        case .linear: return ratio
        case .sqrt: return ratio.squareRoot()
        case .log: return Foundation.log(Double(count) + 1) / Foundation.log(Double(max) + 1)
        }
    }
}

struct KeyCount: Identifiable {
    let info: KeyInfo
    let count: Int
    var id: Int { info.code }
}

struct HourCount: Identifiable {
    let hour: Int      // 0...23, local time
    let count: Int
    var id: Int { hour }
}

struct PeriodCount: Identifiable {
    let start: Date
    let count: Int
    var id: Date { start }
}

/// Everything the dashboard shows, computed for one time range.
struct Stats {
    var total = 0
    var todayTotal = 0                  // always today, regardless of range
    var allTimeTotal = 0                // everything ever recorded, regardless of range
    var perKey: [KeyCount] = []         // sorted by count, descending
    var countByCode: [Int: Int] = [:]
    var maxCount = 0
    var byHourOfDay: [HourCount] = (0..<24).map { HourCount(hour: $0, count: 0) }
    var timeline: [PeriodCount] = []
    var timelineUnit: Calendar.Component = .day
    /// Period to emphasize in the timeline (today, when the range is Today).
    var timelineHighlight: Date?
    var leftHand = 0
    var rightHand = 0
    var activeHours = 0
    var uniqueKeys = 0
    var firstDate: Date?

    var peakHour: HourCount? {
        guard let m = byHourOfDay.max(by: { $0.count < $1.count }), m.count > 0 else { return nil }
        return m
    }
    var topKey: KeyCount? { perKey.first }

    func rank(of code: Int) -> Int? {
        perKey.firstIndex { $0.info.code == code }.map { $0 + 1 }
    }

    func share(_ count: Int) -> Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    static func compute(buckets: KeyStore.Buckets, range: TimeRange, now: Date = Date()) -> Stats {
        let cal = Calendar.current
        var s = Stats()
        let startOfToday = cal.startOfDay(for: now)
        let rangeStart = range.start(now: now)

        // The timeline is always daily (weekly for long histories). Today's
        // range shows two weeks of context so today can be compared.
        let timelineWindowStart: Date? = {
            switch range {
            case .today: return cal.date(byAdding: .day, value: -13, to: startOfToday)
            case .week, .month: return rangeStart
            case .all: return nil
            }
        }()

        var counts: [Int: Int] = [:]
        var hourOfDay = [Int](repeating: 0, count: 24)
        var perBucket: [Int: Int] = [:]
        var timelineBuckets: [Int: Int] = [:]
        var minHour = Int.max
        var minHourAll = Int.max

        for (hour, keys) in buckets {
            let bucketTotal = keys.values.reduce(0, +)
            s.allTimeTotal += bucketTotal
            minHourAll = min(minHourAll, hour)
            let bucketEnd = TimeInterval(hour + 1) * 3600
            if bucketEnd > startOfToday.timeIntervalSince1970 { s.todayTotal += bucketTotal }
            if timelineWindowStart.map({ bucketEnd > $0.timeIntervalSince1970 }) ?? true {
                timelineBuckets[hour] = bucketTotal
            }
            if let rs = rangeStart, bucketEnd <= rs.timeIntervalSince1970 { continue }

            perBucket[hour] = bucketTotal
            minHour = min(minHour, hour)
            let date = Date(timeIntervalSince1970: TimeInterval(hour) * 3600)
            hourOfDay[cal.component(.hour, from: date)] += bucketTotal
            for (code, n) in keys { counts[code, default: 0] += n }
        }

        s.countByCode = counts
        s.total = counts.values.reduce(0, +)
        s.maxCount = counts.values.max() ?? 0
        s.uniqueKeys = counts.count
        s.activeHours = perBucket.count
        s.byHourOfDay = hourOfDay.enumerated().map { HourCount(hour: $0.offset, count: $0.element) }
        if minHour != Int.max {
            s.firstDate = Date(timeIntervalSince1970: TimeInterval(minHour) * 3600)
        }

        s.perKey = counts
            .map { KeyCount(info: KeyCodes.info($0.key), count: $0.value) }
            .sorted { a, b in
                a.count != b.count ? a.count > b.count : a.info.name < b.info.name
            }

        // Hands
        var left = 0, right = 0
        for (code, n) in counts {
            switch KeyCodes.info(code).hand {
            case .left: left += n
            case .right: right += n
            case .either: break
            }
        }
        s.leftHand = left
        s.rightHand = right

        // Timeline periods, zero-filled from the window start to now.
        var unit: Calendar.Component = .day
        let timelineStart: Date
        if let ws = timelineWindowStart {
            timelineStart = ws
        } else if minHourAll != Int.max {
            let first = Date(timeIntervalSince1970: TimeInterval(minHourAll) * 3600)
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: first), to: startOfToday).day ?? 0
            unit = days > 120 ? .weekOfYear : .day
            timelineStart = cal.dateInterval(of: unit, for: first)?.start ?? first
        } else {
            timelineStart = startOfToday
        }
        var periodTotals: [Date: Int] = [:]
        for (hour, n) in timelineBuckets {
            let d = Date(timeIntervalSince1970: TimeInterval(hour) * 3600)
            if let start = cal.dateInterval(of: unit, for: d)?.start {
                periodTotals[start, default: 0] += n
            }
        }
        var timeline: [PeriodCount] = []
        var cursor = cal.dateInterval(of: unit, for: timelineStart)?.start ?? timelineStart
        var steps = 0
        while cursor <= now && steps < 2000 {
            timeline.append(PeriodCount(start: cursor, count: periodTotals[cursor] ?? 0))
            guard let next = cal.date(byAdding: unit, value: 1, to: cursor) else { break }
            cursor = next
            steps += 1
        }
        s.timelineHighlight = range == .today ? startOfToday : nil
        s.timeline = timeline
        s.timelineUnit = unit
        return s
    }
}
