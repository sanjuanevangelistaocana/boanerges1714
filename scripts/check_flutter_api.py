#!/usr/bin/env python3
"""Static Flutter API guard for responsive changes.

Reads the local Flutter framework sources instead of resolving pub packages.
It checks named arguments used by selected framework constructors against the
Flutter SDK installed at /home/ubuntu/tools/flutter.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = Path('/home/ubuntu/tools/flutter/packages/flutter/lib/src')
FRAMEWORK = {
    'ChipThemeData': FLUTTER / 'material/chip_theme.dart',
    'IconButtonThemeData': FLUTTER / 'material/icon_button_theme.dart',
    'ButtonStyle': FLUTTER / 'material/button_style.dart',
    'DataTable': FLUTTER / 'material/data_table.dart',
    'DataColumn': FLUTTER / 'material/data_table.dart',
    'DataRow': FLUTTER / 'material/data_table.dart',
    'Dialog': FLUTTER / 'material/dialog.dart',
    'AlertDialog': FLUTTER / 'material/dialog.dart',
    'SimpleDialog': FLUTTER / 'material/dialog.dart',
    'TabBar': FLUTTER / 'material/tabs.dart',
    'Wrap': FLUTTER / 'widgets/basic.dart',
    'ThemeData': FLUTTER / 'material/theme_data.dart',
}


def changed_files() -> list[Path]:
    names = subprocess.check_output(
        ['git', 'diff', '362cf3e..HEAD', '--name-only'], cwd=ROOT, text=True
    ).splitlines()
    names += subprocess.check_output(
        ['git', 'diff', '--name-only'], cwd=ROOT, text=True
    ).splitlines()
    return list(dict.fromkeys(ROOT / name for name in names if name.endswith('.dart')))


def clean(source: str) -> str:
    source = re.sub(r'//[^\n]*', '', source)
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    source = re.sub(r"'(?:\\.|[^'\\])*'", "''", source)
    source = re.sub(r'"(?:\\.|[^"\\])*"', '""', source)
    return source


def matching(source: str, start: int, opening: str = '(', closing: str = ')') -> str | None:
    depth = 0
    for index in range(start, len(source)):
        char = source[index]
        if char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return source[start + 1:index]
    return None


def named_arguments(body: str) -> set[str]:
    result: set[str] = set()
    depth = 0
    index = 0
    while index < len(body):
        char = body[index]
        if char in '([{':
            depth += 1
        elif char in ')]}':
            depth = max(0, depth - 1)
        elif depth == 0 and (char.isalpha() or char == '_'):
            end = index + 1
            while end < len(body) and (body[end].isalnum() or body[end] == '_'):
                end += 1
            probe = end
            while probe < len(body) and body[probe].isspace():
                probe += 1
            if probe < len(body) and body[probe] == ':':
                result.add(body[index:end])
            index = end - 1
        index += 1
    return result


def constructor_body(source: str, class_name: str) -> str | None:
    pattern = re.compile(
        rf'(?:(?:const|factory)\s+)?{re.escape(class_name)}(?:\.[A-Za-z_]\w*)?\s*\(\s*{{'
    )
    match = pattern.search(source)
    if not match:
        return None
    opening = source.find('(', match.start(), match.end())
    return matching(source, opening)


def parameter_info(source: str, class_name: str) -> tuple[set[str], set[str]]:
    body = constructor_body(source, class_name)
    if body is None:
        return set(), set()
    allowed = set(re.findall(r'\b(?:this\.)?([A-Za-z_]\w*)\s*(?:,|=|\)|}|$)', body))
    allowed.update(re.findall(r'\brequired\s+[^,\n}]+?\s+([A-Za-z_]\w*)\s*(?:,|$)', body))
    required = set(re.findall(r'\brequired\s+[^,\n}]+?\s+([A-Za-z_]\w*)\s*(?:,|$)', body))
    return allowed, required


def constructor_calls(source: str, class_name: str) -> list[tuple[str, str]]:
    source = clean(source)
    calls: list[tuple[str, str]] = []
    for match in re.finditer(rf'\b{re.escape(class_name)}(?:\.[A-Za-z_]\w*)?\s*\(', source):
        prefix = source[max(0, match.start() - 12):match.start()]
        if re.search(r'\bclass\s*$', prefix) or re.search(r'\btypedef\s*$', prefix):
            continue
        opening = source.find('(', match.start(), match.end())
        body = matching(source, opening)
        if body is not None:
            calls.append((match.group(0), body))
    return calls


def main() -> int:
    problems: list[str] = []
    framework_api: dict[str, tuple[set[str], set[str]]] = {}
    for name, path in FRAMEWORK.items():
        framework_api[name] = parameter_info(path.read_text(), name)

    for path in changed_files():
        if not path.exists():
            continue
        source = path.read_text(errors='ignore')
        for name, (allowed, required) in framework_api.items():
            if not allowed:
                problems.append(f'FRAMEWORK_PARSE {path.relative_to(ROOT)} {name}')
                continue
            for constructor, body in constructor_calls(source, name):
                args = named_arguments(body)
                missing = required - args
                unknown = args - allowed
                if missing:
                    problems.append(
                        f'MISSING {path.relative_to(ROOT)} {constructor}: {sorted(missing)}'
                    )
                if unknown:
                    problems.append(
                        f'UNKNOWN {path.relative_to(ROOT)} {constructor}: {sorted(unknown)}'
                    )

        # Explicit nullable framework property guard currently relevant to this batch.
        if re.search(r'children\s*:\s*dialog\.children\s*[,}]', source):
            problems.append(
                f'NULLABILITY {path.relative_to(ROOT)} SimpleDialog.children is List<Widget>?'
            )

    print(f'FILES {len(changed_files())}')
    print(f'PROBLEMS {len(problems)}')
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == '__main__':
    raise SystemExit(main())
