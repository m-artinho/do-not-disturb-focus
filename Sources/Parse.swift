import Foundation

/// Input parsing and formatting. Kept free of AppKit so it can be unit-tested.
enum Parse {
    /// "25", "25m", "25 min", "1h30", "1h 30m", "2h" → minutes.
    static func minutes(_ raw: String) -> Int? {
        let s = raw.lowercased().replacingOccurrences(of: " ", with: "")
        if let m = match(#"^(\d{1,5})(m|min|mins|minute|minutes)?$"#, s) {
            return Int(m[1]!)
        }
        if let m = match(#"^(\d{1,3})h(?:(\d{1,2})(?:m|min|mins)?)?$"#, s) {
            let h = Int(m[1]!)!
            let mm = m[2].flatMap { Int($0) } ?? 0
            guard mm < 60 else { return nil }
            return h * 60 + mm
        }
        return nil
    }

    /// Resolves a clock time to its *next* occurrence after `now`.
    ///
    /// Accepts 24h ("14:30", "23h", "14h30", "9.15", "0930") and 12h ("2:30pm", "2pm", "2:30 p.m.").
    /// An hour from 1–12 with no am/pm and no leading zero is ambiguous ("2:30" could be
    /// 02:30 or 14:30), so whichever of the two comes first is used.
    static func until(_ raw: String, now: Date, calendar: Calendar = .current) -> Date? {
        var s = raw.lowercased()
            .replacingOccurrences(of: "a.m.", with: "am")
            .replacingOccurrences(of: "p.m.", with: "pm")
            .replacingOccurrences(of: " ", with: "")

        if s.hasSuffix("hrs") { s.removeLast(3) }

        let hourText: String
        let minute: Int
        let suffix: String?
        if let m = match(#"^(\d{1,2})(?:[:.h](\d{2})?)?(am|pm|a|p)?$"#, s) {
            hourText = m[1]!
            minute = m[2].flatMap { Int($0) } ?? 0
            suffix = m[3]
        } else if let m = match(#"^(\d{1,2})(\d{2})(am|pm|a|p)?$"#, s) {
            hourText = m[1]!
            minute = Int(m[2]!)!
            suffix = m[3]
        } else {
            return nil
        }

        guard let hour = Int(hourText), (0..<60).contains(minute) else { return nil }
        let leadingZero = hourText.count == 2 && hourText.hasPrefix("0")

        let hours: [Int]
        if let suffix {
            guard (1...12).contains(hour) else { return nil }
            hours = [hour % 12 + (suffix.hasPrefix("p") ? 12 : 0)]
        } else if (1...12).contains(hour) && !leadingZero {
            hours = [hour % 12, hour % 12 + 12]
        } else if (0...23).contains(hour) {
            hours = [hour]
        } else if hour == 24 && minute == 0 {
            hours = [0]
        } else {
            return nil
        }

        return hours.compactMap {
            calendar.nextDate(after: now,
                              matching: DateComponents(hour: $0, minute: minute, second: 0),
                              matchingPolicy: .nextTime)
        }.min()
    }

    private static func match(_ pattern: String, _ s: String) -> [String?]? {
        let re = try! NSRegularExpression(pattern: pattern)
        guard let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: s).map { String(s[$0]) }
        }
    }
}

enum Fmt {
    /// 1500s → "25m", 5400s → "1h 30m", 7200s → "2h". Rounds up to the minute.
    static func duration(_ seconds: TimeInterval) -> String {
        let mins = max(0, Int((seconds / 60).rounded(.up)))
        let h = mins / 60, m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// "14:30", "tomorrow 14:30", "Mon 14:30" — follows the system 12h/24h setting.
    static func end(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        let time = f.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let next = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: next) {
            return "tomorrow \(time)"
        }
        f.setLocalizedDateFormatFromTemplate("EEE")
        return "\(f.string(from: date)) \(time)"
    }
}
