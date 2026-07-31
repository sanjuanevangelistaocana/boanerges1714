#!/usr/bin/env python3
"""Validate Flutter constructor usage against the checked-out Flutter SDK.

The script intentionally reports uncertain inference as REVIEW rather than an
error. It parses the framework sources directly, so it does not need pub
packages or a working package config.
"""
from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SDK = Path('/home/ubuntu/tools/flutter/packages/flutter/lib/src')


@dataclass
class Parameter:
    name: str
    type: str
    required: bool
    nullable: bool


@dataclass
class Constructor:
    class_name: str
    name: str
    parameters: dict[str, Parameter] = field(default_factory=dict)


@dataclass
class Property:
    class_name: str
    name: str
    type: str
    nullable: bool


def changed_files() -> list[Path]:
    result = subprocess.check_output(
        ['git', 'diff', '362cf3e..HEAD', '--name-only'], cwd=ROOT, text=True
    ).splitlines()
    result += subprocess.check_output(
        ['git', 'diff', '--name-only'], cwd=ROOT, text=True
    ).splitlines()
    return list(dict.fromkeys(ROOT / x for x in result if x.endswith('.dart')))


def strip_comments_and_strings(source: str) -> str:
    # Keep offsets stable: callers use regex positions to slice the original
    # source shape. Quoted text and comments become spaces, preserving newlines.
    out = list(source)
    i = 0
    quote = None
    while i < len(source):
        if quote:
            if source[i] == '\\':
                if source[i] != '\n':
                    out[i] = ' '
                if i + 1 < len(source):
                    out[i + 1] = '\n' if source[i + 1] == '\n' else ' '
                i += 2
                continue
            if source[i] == quote:
                out[i] = ' '
                quote = None
            elif source[i] != '\n':
                out[i] = ' '
            i += 1
            continue
        if source.startswith('//', i):
            out[i:i + 2] = [' ', ' ']
            i += 2
            while i < len(source) and source[i] != '\n':
                out[i] = ' '
                i += 1
            continue
        if source.startswith('/*', i):
            out[i:i + 2] = [' ', ' ']
            i += 2
            while i + 1 < len(source) and source[i:i + 2] != '*/':
                if source[i] != '\n':
                    out[i] = ' '
                i += 1
            if i + 1 < len(source):
                out[i:i + 2] = [' ', ' ']
                i += 2
            continue
        if source[i] in "'\"":
            quote = source[i]
            out[i] = ' '
        i += 1
    return ''.join(out)


def matching(source: str, start: int, opening: str = '(', closing: str = ')') -> str | None:
    pairs = {'(': ')', '[': ']', '{': '}'}
    stack = [opening]
    for index in range(start + 1, len(source)):
        char = source[index]
        if char in pairs:
            stack.append(char)
        elif char in (')', ']', '}'):
            if not stack or pairs[stack[-1]] != char:
                continue
            stack.pop()
            if not stack:
                return source[start + 1:index]
    return None


def split_top_level(source: str, delimiter: str = ',') -> list[str]:
    result: list[str] = []
    start = 0
    depths = {'(': 0, '[': 0, '{': 0}
    pairs = {')': '(', ']': '[', '}': '{'}
    for index, char in enumerate(source):
        if char in depths:
            depths[char] += 1
        elif char in pairs:
            depths[pairs[char]] = max(0, depths[pairs[char]] - 1)
        elif char == delimiter and not any(depths.values()):
            result.append(source[start:index])
            start = index + 1
    result.append(source[start:])
    return result


def named_block(constructor_body: str) -> str:
    opening = constructor_body.find('{')
    if opening < 0:
        return ''
    return matching(constructor_body, opening, '{', '}') or ''


def parse_parameters(body: str) -> dict[str, Parameter]:
    result: dict[str, Parameter] = {}
    for raw in split_top_level(named_block(body)):
        item = re.sub(r'\s+', ' ', raw.strip())
        if not item:
            continue
        required = item.startswith('required ')
        item = re.sub(r'^required\s+', '', item)
        item = re.sub(r'^covariant\s+', '', item)
        item = item.split('=', 1)[0].strip()
        this_match = re.match(r'(?:(.*?)\s+)?(?:this|super)\.([A-Za-z_]\w*)$', item)
        if this_match:
            type_name, name = this_match.groups()
            result[name] = Parameter(name, (type_name or 'inferred').strip(), required, True if not type_name else '?' in type_name)
            continue
        match = re.match(r'(.+?)\s+([A-Za-z_]\w*)$', item)
        if not match:
            continue
        type_name, name = match.groups()
        result[name] = Parameter(
            name,
            type_name,
            required,
            '?' in type_name or type_name.endswith('dynamic'),
        )
    return result


def index_framework() -> tuple[dict[tuple[str, str], Constructor], dict[tuple[str, str], Property], int]:
    constructors: dict[tuple[str, str], Constructor] = {}
    properties: dict[tuple[str, str], Property] = {}
    classes = 0
    for path in SDK.rglob('*.dart'):
        raw = path.read_text(errors='ignore')
        source = strip_comments_and_strings(raw)
        for class_match in re.finditer(r'\bclass\s+([A-Z][A-Za-z0-9_]*)\b', source):
            class_name = class_match.group(1)
            classes += 1
            body_start = source.find('{', class_match.end())
            body = matching(source, body_start, '{', '}') if body_start >= 0 else None
            if body is None:
                continue
            # Constructors, including named constructors such as Dialog.fullscreen.
            pattern = re.compile(
                rf'(?:(?:const|factory)\s+)?{re.escape(class_name)}'
                r'(?:\.([A-Za-z_]\w*))?\s*\('
            )
            for match in pattern.finditer(body):
                opening = body.find('(', match.start(), match.end())
                constructor_body = matching(body, opening)
                if constructor_body is None:
                    continue
                name = match.group(1) or 'new'
                candidate = Constructor(
                    class_name, name, parse_parameters(constructor_body)
                )
                current = constructors.get((class_name, name))
                if current is None or len(candidate.parameters) > len(current.parameters):
                    constructors[(class_name, name)] = candidate
            # Public instance fields, used only for safe nullable propagation.
            for prop in re.finditer(
                r'\bfinal\s+([A-Za-z][A-Za-z0-9_<>,.? ]*)\s+([a-z][A-Za-z0-9_]*)\s*;',
                body,
            ):
                type_name, name = prop.groups()
                properties[(class_name, name)] = Property(
                    class_name, name, type_name.strip(), '?' in type_name
                )
    return constructors, properties, classes


def named_arguments(body: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in split_top_level(body):
        item = item.strip()
        match = re.match(r'([a-z_]\w*)\s*:\s*(.*)$', item, re.S)
        if match:
            result[match.group(1)] = match.group(2).strip()
    return result


def invocations(source: str, class_names: set[str]):
    source = strip_comments_and_strings(source)
    pattern = re.compile(r'\b([A-Z][A-Za-z0-9_]*)\s*(?:\.([a-z][A-Za-z0-9_]*))?\s*\(')
    for match in pattern.finditer(source):
        class_name = match.group(1)
        if class_name not in class_names:
            continue
        if match.start() > 0 and source[match.start() - 1] == '.':
            continue
        prefix = source[max(0, match.start() - 20):match.start()]
        if re.search(r'\b(?:class|typedef|enum|mixin)\s*$', prefix):
            continue
        opening = source.find('(', match.start(), match.end())
        body = matching(source, opening)
        if body is not None:
            yield class_name, match.group(2) or 'new', named_arguments(body)


def nullable_expression(expression: str, properties: dict[tuple[str, str], Property]):
    match = re.fullmatch(r'([a-z_]\w*)\.([a-zA-Z_]\w*)', expression.strip())
    if not match:
        return None
    # Without local variable type inference, this is deliberately REVIEW.
    prop_name = match.group(1)
    candidates = [p for (cls, name), p in properties.items() if name == prop_name]
    if len(candidates) == 1:
        return candidates[0]
    return None


def main() -> int:
    constructors, properties, class_count = index_framework()
    class_names = {class_name for class_name, _ in constructors}
    errors: list[str] = []
    reviews: list[str] = []
    files = changed_files()
    invocations_checked = 0

    for path in files:
        if not path.exists():
            continue
        source = path.read_text(errors='ignore')
        for class_name, constructor_name, args in invocations(source, class_names):
            constructor = constructors.get((class_name, constructor_name))
            if constructor is None:
                # The token is a static/member method (for example Theme.of,
                # Navigator.pop or Button.styleFrom), not a constructor call.
                continue
            invocations_checked += 1
            allowed = set(constructor.parameters)
            unknown = set(args) - allowed
            missing = {
                name for name, parameter in constructor.parameters.items()
                if parameter.required and name not in args
            }
            for name in sorted(unknown):
                errors.append(
                    f'{path.relative_to(ROOT)} {class_name}.{constructor_name}: '
                    f'unknown parameter {name}'
                )
            for name in sorted(missing):
                errors.append(
                    f'{path.relative_to(ROOT)} {class_name}.{constructor_name}: '
                    f'missing required parameter {name}'
                )
            for name, expression in args.items():
                parameter = constructor.parameters.get(name)
                if parameter is None or parameter.nullable:
                    continue
                prop = nullable_expression(expression, properties)
                if prop is not None and prop.nullable:
                    errors.append(
                        f'{path.relative_to(ROOT)} {class_name}.{constructor_name}: '
                        f'nullable {prop.class_name}.{prop.name} assigned to non-nullable {name}'
                    )
                elif re.fullmatch(r'[a-z_]\w*\.[a-zA-Z_]\w*', expression):
                    receiver, member = expression.split('.', 1)
                    if member == 'length':
                        continue
                    reviews.append(
                        f'{path.relative_to(ROOT)} {class_name}.{constructor_name}: '
                        f'could not infer nullability of {expression} -> {name}'
                    )

    print(f'FRAMEWORK_CLASSES {class_count}')
    print(f'FILES {len(files)}')
    print(f'INVOCATIONS_CHECKED {invocations_checked}')
    print(f'ERRORS {len(errors)}')
    print(f'REVIEWS {len(reviews)}')
    for item in errors:
        print('ERROR', item)
    for item in reviews:
        print('REVIEW', item)
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
