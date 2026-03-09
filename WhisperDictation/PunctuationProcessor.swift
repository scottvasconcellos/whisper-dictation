import Foundation

/// Post-processes whisper transcripts to replace spoken punctuation commands with symbols.
/// Applied after transcription, before paste — so the user gets clean text in their field.
enum PunctuationProcessor {

    // Ordered: multi-word phrases first, then single words.
    // Patterns are case-insensitive word-boundary matches.
    private static let replacements: [(pattern: String, replacement: String)] = [
        // Layout commands (unambiguous)
        ("\\bnew paragraph\\b",     "\n\n"),
        ("\\bnew line\\b",          "\n"),
        // Quotes
        ("\\bopen quote\\b",        "\u{201C}"),
        ("\\bclose quote\\b",       "\u{201D}"),
        ("\\bopen quotes\\b",       "\u{201C}"),
        ("\\bclose quotes\\b",      "\u{201D}"),
        // Parens
        ("\\bopen paren\\b",        "("),
        ("\\bclose paren\\b",       ")"),
        // Multi-word punctuation names
        ("\\bquestion mark\\b",     "?"),
        ("\\bexclamation point\\b", "!"),
        ("\\bexclamation mark\\b",  "!"),
        ("\\bdot dot dot\\b",       "…"),
        ("\\bellipsis\\b",          "…"),
        ("\\bsemicolon\\b",         ";"),
        // Single-word punctuation (applied last to avoid clobbering multi-word matches above)
        ("\\bperiod\\b",            "."),
        ("\\bcomma\\b",             ","),
        ("\\bcolon\\b",             ":"),
        ("\\bdash\\b",              "—"),
        ("\\bhyphen\\b",            "-"),
    ]

    static func process(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
        }
        // Remove any space that landed immediately before a punctuation mark.
        // e.g. "hello , world" → "hello, world"
        if let cleanup = try? NSRegularExpression(pattern: "\\s+([.,;:!?…—])", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = cleanup.stringByReplacingMatches(in: result, range: range, withTemplate: "$1")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
