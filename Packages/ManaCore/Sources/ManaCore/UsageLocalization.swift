import Foundation

/// Localizes presentation only. Provider labels and cached quota values stay language-independent.
public enum UsageLocalization {
    public static func text(_ key: String, locale: Locale? = nil) -> String {
        let bundle: Bundle
        if let locale,
           let path = Bundle.module.path(forResource: locale.language.languageCode?.identifier ?? "en", ofType: "lproj")
                ?? Bundle.module.path(forResource: "en", ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            bundle = localizedBundle
        } else {
            bundle = Bundle.module
        }
        return NSLocalizedString(key, bundle: bundle, comment: "Usage presentation")
    }

    public static func compactLabel(_ label: String, locale: Locale? = nil) -> String {
        switch label {
        case "week", "Weekly": return text("Weekly", locale: locale)
        case "month": return text("Monthly", locale: locale)
        default: break
        }
        for group in ["Gemini", "Claude/GPT (Antigravity)"] {
            let prefix = group + " "
            if label.hasPrefix(prefix) {
                return group + " " + compactLabel(String(label.dropFirst(prefix.count)), locale: locale)
            }
        }
        for (suffix, key) in [("w", "%lldw"), ("d", "%lldd"), ("h", "%lldh"), ("m", "%lldm")] {
            if label.hasSuffix(suffix), let value = Int64(label.dropLast()), value > 0 {
                return String(format: text(key, locale: locale), locale: locale ?? .current, value)
            }
        }
        if label.hasPrefix("window "), let value = Int64(label.dropFirst(7)) {
            return String(format: text("Window %lld", locale: locale), locale: locale ?? .current, value)
        }
        return label
    }

    public static func quotaLabel(_ label: String, locale: Locale? = nil) -> String {
        switch label.lowercased() {
        case "5h": return text("5-hour quota", locale: locale)
        case "1w", "week": return text("Weekly quota", locale: locale)
        case "month": return text("Monthly quota", locale: locale)
        default: return compactLabel(label, locale: locale)
        }
    }

    public static func remaining(_ percent: Double, accessibility: Bool = false, locale: Locale? = nil) -> String {
        let key = accessibility ? "%lld percent remaining" : "%lld%% left"
        return String(format: text(key, locale: locale), locale: locale ?? .current, Int64(percent.rounded()))
    }

    public static func countdown(until date: Date, now: Date, locale: Locale? = nil) -> String {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return text("Reset due", locale: locale) }
        if seconds >= 86_400 {
            let days = Int64(seconds / 86_400)
            let hours = Int64((seconds - Double(days * 86_400)) / 3_600)
            return String(format: text("%lldd %lldh", locale: locale), locale: locale ?? .current, days, hours)
        }
        let hours = Int64(seconds / 3_600)
        let minutes = min(59, Int64(ceil((seconds - Double(hours * 3_600)) / 60)))
        return String(format: text("%lldh %lldm", locale: locale), locale: locale ?? .current, hours, minutes)
    }
}
