import Foundation
import Testing
import ManaCore

@Test(arguments: [
    ("en", "Weekly quota", "5h", "75% left", "2d 3h"),
    ("de", "Wochenkontingent", "5 Std.", "75% übrig", "2 T. 3 Std."),
    ("es", "Cuota semanal", "5 h", "75% restante", "2 d 3 h"),
    ("fr", "Quota hebdomadaire", "5 h", "75% restants", "2 j 3 h")
])
func usagePresentationUsesRequestedLanguage(language: String, weekly: String, hours: String, remaining: String, countdown: String) {
    let locale = Locale(identifier: language)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(UsageLocalization.quotaLabel("1w", locale: locale) == weekly)
    #expect(UsageLocalization.quotaLabel("week", locale: locale) == weekly)
    #expect(UsageLocalization.compactLabel("5h", locale: locale) == hours)
    #expect(UsageLocalization.remaining(75, locale: locale) == remaining)
    #expect(UsageLocalization.countdown(until: now.addingTimeInterval(2 * 86_400 + 3 * 3_600), now: now, locale: locale) == countdown)
}

@Test func localizationSupportsRegionalLanguagesAndEnglishFallback() {
    #expect(UsageLocalization.quotaLabel("month", locale: Locale(identifier: "de_CH")) == "Monatskontingent")
    #expect(UsageLocalization.quotaLabel("month", locale: Locale(identifier: "ja_JP")) == "Monthly quota")
    #expect(UsageLocalization.compactLabel("Gemini Weekly", locale: Locale(identifier: "fr_FR")) == "Gemini Hebdomadaire")
    #expect(UsageLocalization.compactLabel("Claude/GPT (Antigravity) 5h", locale: Locale(identifier: "de")) == "Claude/GPT (Antigravity) 5 Std.")
    #expect(UsageLocalization.compactLabel("window 2", locale: Locale(identifier: "es")) == "Periodo 2")
    #expect(UsageLocalization.compactLabel("Future provider label", locale: Locale(identifier: "fr")) == "Future provider label")
}

@Test func localizedCountdownPreservesBoundaryRounding() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let cases: [(TimeInterval, String, String)] = [
        (-60.0, "Reset due", "Zurücksetzung fällig"),
        (0, "Reset due", "Zurücksetzung fällig"),
        (59, "0h 1m", "0 Std. 1 Min."),
        (3_600, "1h 0m", "1 Std. 0 Min."),
        (3_601, "1h 1m", "1 Std. 1 Min."),
        (86_399, "23h 59m", "23 Std. 59 Min."),
        (86_400, "1d 0h", "1 T. 0 Std."),
        (86_401, "1d 0h", "1 T. 0 Std."),
        (2 * 86_400 + 3 * 3_600 + 59 * 60, "2d 3h", "2 T. 3 Std.")
    ]
    for (seconds, english, german) in cases {
        let reset = now.addingTimeInterval(seconds)
        #expect(UsageLocalization.countdown(until: reset, now: now, locale: Locale(identifier: "en")) == english)
        #expect(UsageLocalization.countdown(until: reset, now: now, locale: Locale(identifier: "de")) == german)
    }
}

@Test func localizedAccessibilityAndErrorsKeepFormatArguments() {
    #expect(UsageLocalization.remaining(75, accessibility: true, locale: Locale(identifier: "fr")) == "75 pour cent restants")
    let format = UsageLocalization.text("Rate limited. Try again in %lld seconds.", locale: Locale(identifier: "de"))
    #expect(String(format: format, Int64(2_147_483_648)) == "Anfragelimit erreicht. Versuche es in 2147483648 Sekunden erneut.")
    #expect(UsageLocalization.text("agy executable path", locale: Locale(identifier: "es")) == "Ruta del ejecutable agy")
}

@Test(arguments: [
    ("en", "Rate limited. Try again in 1 second."),
    ("de", "Anfragelimit erreicht. Versuche es in 1 Sekunde erneut."),
    ("es", "Límite de solicitudes alcanzado. Inténtalo de nuevo en 1 segundo."),
    ("fr", "Limite de requêtes atteinte. Réessayez dans 1 seconde.")
])
func retryMessagesUseSingularSeconds(language: String, expected: String) {
    let locale = Locale(identifier: language)
    let format = UsageLocalization.text("Rate limited. Try again in %lld seconds.", locale: locale)
    #expect(String(format: format, locale: locale, Int64(1)) == expected)
}
