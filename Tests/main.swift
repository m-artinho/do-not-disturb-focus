import Foundation

// Run with ./test.sh — compiles Sources/Parse.swift together with this file.

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Europe/Lisbon")!

func at(_ day: Int, _ h: Int, _ m: Int) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))!
}

var failures = 0
func check<T: Equatable>(_ label: String, _ got: T, _ want: T) {
    if got != want {
        failures += 1
        print("FAIL \(label): got \(String(describing: got)), want \(String(describing: want))")
    }
}

// Now = Fri 20 Nov, 11:00
let now = at(20, 11, 0)
let untilCases: [(String, Date?)] = [
    ("14:30", at(20, 14, 30)),
    ("2:30pm", at(20, 14, 30)),
    ("2:30 PM", at(20, 14, 30)),
    ("2:30 p.m.", at(20, 14, 30)),
    ("2:30", at(20, 14, 30)),        // ambiguous → next one
    ("2pm", at(20, 14, 0)),
    ("2p", at(20, 14, 0)),
    ("10", at(20, 22, 0)),           // 10:00 passed → 22:00
    ("10am", at(21, 10, 0)),         // explicit am → tomorrow
    ("10:00 AM", at(21, 10, 0)),
    ("23h", at(20, 23, 0)),
    ("23", at(20, 23, 0)),
    ("14h30", at(20, 14, 30)),
    ("9.15", at(20, 21, 15)),
    ("09:30", at(21, 9, 30)),        // leading zero = 24h → tomorrow morning
    ("0930", at(21, 9, 30)),
    ("1430", at(20, 14, 30)),
    ("00:15", at(21, 0, 15)),
    ("12", at(20, 12, 0)),
    ("12pm", at(20, 12, 0)),
    ("12am", at(21, 0, 0)),
    ("11:30", at(20, 11, 30)),
    ("11", at(20, 23, 0)),           // 11:00 is now → next is 23:00
    ("13pm", nil),
    ("25", nil),
    ("10:75", nil),
    ("abc", nil),
    ("", nil),
]
for (input, want) in untilCases {
    check("until '\(input)' @11:00", Parse.until(input, now: now, calendar: cal), want)
}

// The "it's 23:00 and I type 22h" case → tomorrow 22:00, 23 hours away.
let late = at(20, 23, 0)
check("until 22h @23:00", Parse.until("22h", now: late, calendar: cal), at(21, 22, 0))
check("duration 22h @23:00", Fmt.duration(Parse.until("22h", now: late, calendar: cal)!.timeIntervalSince(late)), "23h")
check("until 10pm @23:00", Parse.until("10pm", now: late, calendar: cal), at(21, 22, 0))
check("until 1 @23:00", Parse.until("1", now: late, calendar: cal), at(21, 1, 0))

let minuteCases: [(String, Int?)] = [
    ("25", 25), ("25m", 25), ("25 min", 25), ("90 minutes", 90),
    ("1h30", 90), ("1h 30m", 90), ("2h", 120), ("1h75", nil), ("x", nil), ("", nil),
]
for (input, want) in minuteCases {
    check("minutes '\(input)'", Parse.minutes(input), want)
}

check("fmt 25m", Fmt.duration(1500), "25m")
check("fmt 1h30", Fmt.duration(5400), "1h 30m")
check("fmt 2h", Fmt.duration(7200), "2h")
check("fmt rounds up", Fmt.duration(1), "1m")

print(failures == 0 ? "All tests passed" : "\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
