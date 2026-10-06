import Foundation

extension Date {

    /// "14:35" — used inside chat bubbles
    var timeString: String {
        formatted(date: .omitted, time: .shortened)
    }

    /// "Today" / "Yesterday" / "12/10/24" — used in conversation list
    var conversationLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self)     { return timeString }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return formatted(.dateTime.day().month().year(.twoDigits))
    }

    /// Full readable stamp for message detail
    var fullLabel: String {
        formatted(date: .abbreviated, time: .shortened)
    }

    /// Relative "2 min ago" style — used in presence subtitles
    var relativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }

    /// Whether two dates are on the same calendar day (for section headers)
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
