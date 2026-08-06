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

EXTERNAL_EXTENSION_MEMBERS: dict[str, dict[str, set[str]]] = {
    'package:go_router/go_router.dart': {
        'context': {
            'canPop',
            'go',
            'goNamed',
            'pop',
            'push',
            'pushNamed',
            'pushReplacement',
            'pushReplacementNamed',
            'replace',
            'replaceNamed',
        },
    },
    'package:provider/provider.dart': {
        'context': {'read', 'select', 'watch'},
    },
}


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


@dataclass
class ProjectClass:
    name: str
    members: set[str] = field(default_factory=set)
    fields: set[str] = field(default_factory=set)


@dataclass
class ProjectLibrary:
    path: Path
    declarations: set[str] = field(default_factory=set)
    constants: set[str] = field(default_factory=set)
    exports: list[Path] = field(default_factory=list)
    extensions: dict[str, set[str]] = field(default_factory=dict)


def changed_files() -> list[Path]:
    result = subprocess.check_output(
        ['git', 'diff', '362cf3e..HEAD', '--name-only'], cwd=ROOT, text=True
    ).splitlines()
    result += subprocess.check_output(
        ['git', 'diff', '--name-only'], cwd=ROOT, text=True
    ).splitlines()
    return list(dict.fromkeys(ROOT / x for x in result if x.endswith('.dart')))


def dart_files() -> list[Path]:
    return list((ROOT / 'lib').rglob('*.dart'))


def package_path(uri: str) -> Path | None:
    prefix = 'package:boanerges1714/'
    if uri.startswith(prefix):
        return ROOT / 'lib' / uri[len(prefix):]
    return None


def imported_paths(path: Path, source: str) -> list[Path]:
    result: list[Path] = []
    for match in re.finditer(
        r'''^\s*import\s+['"]([^'"]+)['"]''', source, re.MULTILINE
    ):
        uri = match.group(1)
        imported = package_path(uri)
        if imported is not None:
            result.append(imported)
        elif uri.startswith('.'):
            result.append((path.parent / uri).resolve())
    return result


def imported_uris(source: str) -> set[str]:
    return {
        match.group(1)
        for match in re.finditer(
            r'''^\s*import\s+['"]([^'"]+)['"]''', source, re.MULTILINE
        )
    }


def exported_paths(path: Path, source: str) -> list[Path]:
    result: list[Path] = []
    for match in re.finditer(
        r'''^\s*export\s+['"]([^'"]+)['"]''', source, re.MULTILINE
    ):
        uri = match.group(1)
        imported = package_path(uri)
        if imported is not None:
            result.append(imported)
        elif uri.startswith('.'):
            result.append((path.parent / uri).resolve())
    return result


def parse_named_fields(text: str) -> set[str]:
    fields: set[str] = set()
    for item in split_top_level(text):
        item = re.sub(r'\s+', ' ', item.strip())
        item = re.sub(r'^(?:required\s+)?', '', item)
        match = re.search(r'\b([a-z_]\w*)\s*$', item)
        if match:
            fields.add(match.group(1))
    return fields


def project_index() -> tuple[
    dict[Path, ProjectLibrary],
    dict[str, ProjectClass],
    dict[str, set[str]],
    dict[str, set[str]],
]:
    libraries: dict[Path, ProjectLibrary] = {}
    classes: dict[str, ProjectClass] = {}
    records: dict[str, set[str]] = {}
    functions: dict[str, set[str]] = {}
    for path in dart_files():
        raw = path.read_text(errors='ignore')
        source = strip_comments_and_strings(raw)
        library = ProjectLibrary(path)
        libraries[path] = library
        class_ranges: list[tuple[int, int]] = []
        for declaration in re.finditer(
            r'\b(?:class|enum|mixin|typedef)\s+([A-Za-z_]\w*)', raw
        ):
            library.declarations.add(declaration.group(1))
        for match in re.finditer(
            r'\b(?:class|enum|mixin|typedef)\s+([A-Za-z_]\w*)', source
        ):
            name = match.group(1)
            library.declarations.add(name)
            if source[match.start():].startswith('typedef'):
                opening = source.find('(', match.end())
                if opening >= 0 and source.find('=', match.end(), opening) >= 0:
                    body = matching(source, opening)
                    if body is not None:
                        body = body.strip()
                        if body.startswith('{') and body.endswith('}'):
                            body = body[1:-1]
                        records[name] = parse_named_fields(body)
        for match in re.finditer(
            r'\bclass\s+(_?[A-Z][A-Za-z0-9_]*)\b', source
        ):
            class_name = match.group(1)
            body_start = source.find('{', match.end())
            body = matching(source, body_start, '{', '}') if body_start >= 0 else None
            if body is None:
                continue
            class_ranges.append((body_start, body_start + len(body) + 2))
            project_class = classes.setdefault(class_name, ProjectClass(class_name))
            for prop in re.finditer(
                r'\b(?:final|late\s+final|static\s+const|static\s+final)\s+'
                r'(?:[A-Za-z][A-Za-z0-9_<>,.? ()]*\s+)?([a-z_]\w*)\s*(?:[=;({])',
                body,
            ):
                project_class.members.add(prop.group(1))
                project_class.fields.add(prop.group(1))
            for method in re.finditer(r'\b([a-z_]\w*)\s*\(', body):
                project_class.members.add(method.group(1))
        for match in re.finditer(
            r'(?m)^[ \t]*(?:[A-Za-z_<>,.?()\[\] ]+)\s+'
            r'([a-z_]\w*)\s*\([^;{}]*\)\s*(?:async\s*)?(?:\{|=>)',
            source,
        ):
            in_class = any(start < match.start() < end for start, end in class_ranges)
            if not in_class and source[:match.start()].count('{') == source[:match.start()].count('}'):
                function_name = match.group(1)
                functions.setdefault(function_name, set()).add(str(path))
                library.declarations.add(function_name)
        for match in re.finditer(
            r'(?m)^[ \t]*(?:const|final)\s+'
            r'(?:[A-Za-z_<>,.?()\[\] ]+\s+)?([a-z_]\w*)\s*=',
            source,
        ):
            if source[:match.start()].count('{') == source[:match.start()].count('}'):
                library.constants.add(match.group(1))
        for match in re.finditer(
            r'\bextension(?:\s+\w+)?\s+on\s+([A-Za-z_]\w*)\s*\{',
            source,
        ):
            body = matching(source, source.find('{', match.start()), '{', '}')
            if body is not None:
                members = set(
                    re.findall(r'\b(?:get\s+)?([a-z_]\w*)\s*(?:\([^)]*\))?\s*(?:=>|\{)',
                               body)
                )
                library.extensions.setdefault(match.group(1), set()).update(members)
        library.exports.extend(exported_paths(path, source))
    return libraries, classes, records, functions


def library_visible_declarations(
    path: Path,
    libraries: dict[Path, ProjectLibrary],
    cache: dict[Path, set[str]] | None = None,
) -> set[str]:
    cache = cache if cache is not None else {}
    if path in cache:
        return cache[path]
    library = libraries.get(path)
    if library is None:
        return set()
    visible = set(library.declarations) | set(library.constants)
    cache[path] = visible
    for exported in library.exports:
        visible.update(library_visible_declarations(exported, libraries, cache))
    return visible


def library_visible_extensions(
    path: Path,
    libraries: dict[Path, ProjectLibrary],
    cache: dict[Path, dict[str, set[str]]] | None = None,
) -> dict[str, set[str]]:
    cache = cache if cache is not None else {}
    if path in cache:
        return cache[path]
    library = libraries.get(path)
    if library is None:
        return {}
    visible = {
        receiver: set(members)
        for receiver, members in library.extensions.items()
    }
    cache[path] = visible
    for exported in library.exports:
        for receiver, members in library_visible_extensions(
            exported, libraries, cache
        ).items():
            visible.setdefault(receiver, set()).update(members)
    return visible


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


def record_return_fields(source: str) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    pattern = re.compile(
        r'\(\s*\{([^{}]*)\}\s*\)\s*\??\s*'
        r'(?:async\s+)?([a-z_]\w*)\s*\(',
        re.S,
    )
    for match in pattern.finditer(source):
        result[match.group(2)] = parse_named_fields(match.group(1))
    return result


def inferred_local_members(
    source: str,
    records: dict[str, set[str]],
    classes: dict[str, ProjectClass],
) -> dict[str, tuple[str, set[str]]]:
    inferred: dict[str, tuple[str, set[str]]] = {}
    returns = record_return_fields(source)
    for match in re.finditer(
        r'\b(?:final|late\s+final)\s+([A-Za-z_]\w*)\s+([a-z_]\w*)\s*=',
        source,
    ):
        type_name, variable = match.groups()
        if type_name in records:
            inferred[variable] = ('record', records[type_name])
    for match in re.finditer(
        r'\b(?:final|var|late\s+final)\s+([A-Za-z_]\w*)\s*=\s*'
        r'([A-Za-z_]\w*)\s*\(',
        source,
    ):
        variable, function = match.groups()
        if function in returns:
            inferred[variable] = ('record', returns[function])
    for match in re.finditer(
        r'\b(?:final|var|late\s+final)\s+([A-Z]\w*)\s+([a-z_]\w*)\s*=',
        source,
    ):
        class_name, variable = match.groups()
        if class_name in classes:
            inferred[variable] = ('class', {class_name})
    for match in re.finditer(
        r'\b(?:final|var|late\s+final)\s+([a-z_]\w*)\s*=\s*\(([^()]*)\)',
        source,
    ):
        variable, body = match.groups()
        if ':' not in body:
            continue
        fields = parse_named_fields(body)
        if fields:
            inferred[variable] = ('record', fields)
    return inferred


def member_errors(
    path: Path,
    source: str,
    records: dict[str, set[str]],
    classes: dict[str, ProjectClass],
) -> list[str]:
    inferred = inferred_local_members(source, records, classes)
    errors: list[str] = []
    pattern = re.compile(r'\b([a-z_]\w*)\s*(\?|)\.([a-z_]\w*)')
    for match in pattern.finditer(strip_comments_and_strings(source)):
        variable, member = match.group(1), match.group(3)
        info = inferred.get(variable)
        if info is None:
            continue
        kind, values = info
        if kind == 'record':
            if member not in values:
                errors.append(
                    f'{path.relative_to(ROOT)} {variable}: '
                    f'unknown record member {member}'
                )
        else:
            class_name = next(iter(values))
            if member not in classes[class_name].members:
                errors.append(
                    f'{path.relative_to(ROOT)} {class_name}.{member}: '
                    'unknown project class member'
                )
    return errors


def state_widget_field_errors(
    path: Path,
    source: str,
    classes: dict[str, ProjectClass],
    libraries: dict[Path, ProjectLibrary],
) -> list[str]:
    cleaned = strip_comments_and_strings(source)
    errors: list[str] = []
    for state_match in re.finditer(
        r'\bclass\s+(_?[A-Z]\w*State)\s+extends\s+State<(_?[A-Z]\w*)>',
        cleaned,
    ):
        state_name, widget_name = state_match.groups()
        widget = classes.get(widget_name)
        if widget is None or not widget.fields:
            continue
        opening = cleaned.find('{', state_match.end())
        body = matching(cleaned, opening, '{', '}') if opening >= 0 else None
        if body is None:
            continue
        local_names = set(
            re.findall(
                r'\b(?:final|var|late\s+final|const)\s+'
                r'(?:[A-Za-z_<>,.?()\[\] ]+\s+)?([a-z_]\w*)',
                body,
            )
        )
        local_names.update(re.findall(r'\b(?:void|Widget|Future<[^>]+>|'
                                      r'[A-Za-z_]\w*)\s+([a-z_]\w*)\s*\(',
                                      body))
        for parameter_list in re.findall(
            r'\b[a-z_]\w*\s*\(([^()]*)\)\s*\{',
            body,
        ):
            for parameter in split_top_level(parameter_list):
                match = re.search(r'\b([a-z_]\w*)\s*$', parameter.strip())
                if match:
                    local_names.add(match.group(1))
        global_names = set()
        for library in libraries.values():
            global_names.update(library.declarations)
            global_names.update(library.constants)
        for field in sorted(widget.fields):
            if field in local_names or field in global_names:
                continue
            for use in re.finditer(rf'\b{re.escape(field)}\b', body):
                before = body[max(0, use.start() - 1):use.start()]
                after = body[use.end():use.end() + 1]
                if before == '.' or after == ':':
                    continue
                errors.append(
                    f'{path.relative_to(ROOT)} {state_name}: '
                    f'widget field {field} used without widget.'
                )
                break
    return errors


def import_errors(
    path: Path,
    source: str,
    libraries: dict[Path, ProjectLibrary],
    classes: dict[str, ProjectClass],
    functions: dict[str, set[str]],
) -> list[str]:
    cleaned = strip_comments_and_strings(source)
    imported = imported_paths(path, source)
    imported_external_uris = imported_uris(source)
    cache: dict[Path, set[str]] = {}
    visible: set[str] = set()
    for imported_path in imported:
        visible.update(library_visible_declarations(imported_path, libraries, cache))
    current_library = libraries.get(path, ProjectLibrary(path))
    local = current_library.declarations | current_library.constants
    errors: list[str] = []

    extension_members: dict[str, set[Path]] = {}
    for library_path, library in libraries.items():
        for members in library.extensions.values():
            for member in members:
                extension_members.setdefault(member, set()).add(library_path)
    for member, sources in extension_members.items():
        if not re.search(rf'\b[a-z_]\w*\s*\?\?\.{re.escape(member)}\b|\b'
                         rf'[a-z_]\w*\s*\.{re.escape(member)}\b', cleaned):
            continue
        imported_extensions = any(
            member in members
            for imported_path in imported
            for members in library_visible_extensions(
                imported_path, libraries
            ).values()
        )
        if not imported_extensions:
            errors.append(
                f'{path.relative_to(ROOT)}: extension member .{member} '
                'used without importing its defining library'
            )

    for uri, receivers in EXTERNAL_EXTENSION_MEMBERS.items():
        if uri in imported_external_uris:
            continue
        for receiver, members in receivers.items():
            for member in members:
                if re.search(
                    rf'\b{re.escape(receiver)}\s*\?\.\s*'
                    rf'{re.escape(member)}\b|'
                    rf'\b{re.escape(receiver)}\s*\.\s*'
                    rf'{re.escape(member)}\b',
                    cleaned,
                ):
                    errors.append(
                        f'{path.relative_to(ROOT)}: external extension member '
                        f'.{member} used without importing {uri}'
                    )

    for class_name in classes:
        if class_name in local or class_name in visible:
            continue
        if re.search(rf'\b{re.escape(class_name)}\s*(?:<[^;{{}}>]+>)?\s*'
                     r'(?:\(|\.)', cleaned):
            errors.append(
                f'{path.relative_to(ROOT)}: symbol {class_name} '
                'used without an import'
            )
    for function_name, locations in functions.items():
        if (
            function_name.startswith('_')
            or len(locations) != 1
            or function_name in local
            or function_name in visible
        ):
            continue
        if re.search(rf'\b{re.escape(function_name)}\s*\(', cleaned):
            errors.append(
                f'{path.relative_to(ROOT)}: function {function_name} '
                'used without an import'
            )
    constants: dict[str, set[Path]] = {}
    for library_path, library in libraries.items():
        for constant in library.constants:
            constants.setdefault(constant, set()).add(library_path)
    for constant, locations in constants.items():
        if len(locations) != 1 or constant in local or constant in visible:
            continue
        if re.search(rf'\b{re.escape(constant)}\b', cleaned):
            errors.append(
                f'{path.relative_to(ROOT)}: constant {constant} '
                'used without an import'
            )
    return errors


def main() -> int:
    constructors, properties, class_count = index_framework()
    class_names = {class_name for class_name, _ in constructors}
    libraries, project_classes, project_records, project_functions = project_index()
    errors: list[str] = []
    reviews: list[str] = []
    files = changed_files()
    invocations_checked = 0

    for path in files:
        if not path.exists():
            continue
        source = path.read_text(errors='ignore')
        errors.extend(member_errors(
            path, source, project_records, project_classes
        ))
        errors.extend(state_widget_field_errors(
            path, source, project_classes, libraries
        ))
        errors.extend(import_errors(
            path, source, libraries, project_classes, project_functions
        ))
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
