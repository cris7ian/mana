#!/usr/bin/env python3
"""Check language coverage and format arguments; optionally audit compiler-extracted keys."""

import argparse
from collections import Counter
import json
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("en", "de", "es", "fr")
TABLES = (ROOT / "Mana", ROOT / "ios/Shared", ROOT / "Packages/ManaCore/Sources/ManaCore/Resources")
ENTRY = re.compile(r'^\s*("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");\s*$')
FORMAT = re.compile(r"%%|%(?:\d+\$)?(?:[-+0 #]*\d*(?:\.\d+)?)(?:lld|ld|d|u|@|f|lf)")
CALL = re.compile(r'(?:String\(localized:\s*|NSLocalizedString\(\s*|(?:Text|Label|Button|Picker|Toggle|TextField|SecureField|Section|LocalizedStringKey|IntentDescription)\(\s*|\.(?:help|accessibilityLabel|accessibilityHint|navigationTitle|configurationDisplayName|description)\(\s*|(?:settingsCard\(title:|statusPill\()\s*)("(?:[^"\\]|\\.)*")')


def load(path):
    values = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("//"):
            continue
        match = ENTRY.fullmatch(line)
        if not match:
            raise ValueError(f"{path.relative_to(ROOT)}:{number}: invalid strings entry")
        key, value = map(json.loads, match.groups())
        if key in values:
            raise ValueError(f"{path.relative_to(ROOT)}:{number}: duplicate key {key!r}")
        values[key] = value
    return values


def formats(value):
    return Counter(re.sub(r"^%\d+\$", "%", token) for token in FORMAT.findall(value) if token != "%%")


def text_only_format(key):
    return not re.search(r"[A-Za-z]", FORMAT.sub("", key))


def table_for_source(source):
    if source.is_relative_to(ROOT / "Mana"):
        return TABLES[0]
    if source.is_relative_to(ROOT / "ios/Mana") or source.is_relative_to(ROOT / "ios/ManaWidgets") or source.is_relative_to(ROOT / "ios/Shared"):
        return TABLES[1]
    if source.is_relative_to(ROOT / "Packages/ManaCore/Sources"):
        return TABLES[2]
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extracted", type=Path, action="append", default=[], help="Xcode intermediates directory containing .stringsdata files")
    args = parser.parse_args()
    errors = []
    english = {}
    for table in TABLES:
        english[table] = load(table / "en.lproj/Localizable.strings")
        for language in LANGUAGES:
            values = load(table / f"{language}.lproj/Localizable.strings")
            missing = english[table].keys() - values.keys()
            extra = values.keys() - english[table].keys()
            if missing or extra:
                errors.append(f"{table.relative_to(ROOT)}/{language}: missing={sorted(missing)}, extra={sorted(extra)}")
            for key, value in values.items():
                if not value.strip() or formats(key) != formats(value) or key.count("%%") != value.count("%%"):
                    errors.append(f"{table.relative_to(ROOT)}/{language}: empty translation or incompatible format for {key!r}")
        plural_path = table / "en.lproj/Localizable.stringsdict"
        if plural_path.exists():
            base_plurals = plistlib.loads(plural_path.read_bytes())
            for language in LANGUAGES:
                path = table / f"{language}.lproj/Localizable.stringsdict"
                plurals = plistlib.loads(path.read_bytes())
                if plurals.keys() != base_plurals.keys():
                    errors.append(f"{path.relative_to(ROOT)}: plural keys differ from English")
                for key, entry in plurals.items():
                    if key not in english[table]:
                        errors.append(f"{path.relative_to(ROOT)}: plural key missing from English table: {key!r}")
                    for name, rule in entry.items():
                        if name == "NSStringLocalizedFormatKey":
                            continue
                        if rule.get("NSStringFormatSpecTypeKey") != "NSStringPluralRuleType" or rule.get("NSStringFormatValueTypeKey") != "lld":
                            errors.append(f"{path.relative_to(ROOT)}: invalid plural format: {key!r}")
                        for category in ("one", "other"):
                            if not rule.get(category) or formats(rule[category]) != formats(key):
                                errors.append(f"{path.relative_to(ROOT)}: missing or invalid {category} plural: {key!r}")
    # This static check covers literal calls. Xcode's optional extraction audit also covers interpolations and App Intents.
    for directory in (ROOT / "Mana", ROOT / "ios/Mana", ROOT / "ios/ManaWidgets", ROOT / "ios/Shared", ROOT / "Packages/ManaCore/Sources"):
        for source in directory.rglob("*.swift"):
            table = table_for_source(source)
            for match in CALL.finditer(source.read_text()):
                if "\\(" in match[1]:
                    continue
                key = json.loads(match[1])
                if not text_only_format(key) and key not in english[table]:
                    errors.append(f"{source.relative_to(ROOT)}: untranslated key {key!r}")
    for directory in args.extracted:
        for path in directory.rglob("*.stringsdata"):
            data = json.loads(path.read_text())
            source = Path(data.get("source", ""))
            table = table_for_source(source)
            if table is None:
                continue
            for entry in data.get("tables", {}).get("Localizable", []):
                key = entry["key"]
                if not text_only_format(key) and key not in english[table]:
                    errors.append(f"{source.relative_to(ROOT)}: untranslated extracted key {key!r}")
    if errors:
        raise SystemExit("\n".join(sorted(set(errors))))
    print(f"Localization checks passed: {sum(map(len, english.values()))} keys across English, German, Spanish, and French.")


if __name__ == "__main__":
    main()
