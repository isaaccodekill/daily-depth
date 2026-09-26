import Foundation
struct Growth {
    static func days(_ dates: [Date], calendar: Calendar = .current) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }
    static func streak(_ dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let completed = days(dates, calendar: calendar)
        var day = calendar.startOfDay(for: now)
        if !completed.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while completed.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
    static func lastDays(_ count: Int, now: Date = Date()) -> [Date] {
        let today = Calendar.current.startOfDay(for: now)
        return (0..<count).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
    }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(secondsFromGMT: 0)!
let today = cal.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 12))!
func ago(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
assert(Growth.streak([], now: today, calendar: cal) == 0)
assert(Growth.streak([today, today, ago(1), ago(2)], now: today, calendar: cal) == 3)
assert(Growth.streak([ago(1), ago(2)], now: today, calendar: cal) == 2)
assert(Growth.streak([ago(2)], now: today, calendar: cal) == 0)
assert(Growth.streak([today, ago(2)], now: today, calendar: cal) == 1)
assert(Growth.days([today,today,ago(1)], calendar: cal).count == 2)
print("PASS: duplicate entries, today/yesterday grace, missed-day reset, empty state.")
