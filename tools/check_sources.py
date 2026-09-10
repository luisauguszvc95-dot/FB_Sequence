#!/usr/bin/env python3
"""Bounded static checks for this repository's textual Structured Text sources.

This is not a compiler, IEC conformance validator, or runtime test. It checks the
plain TYPE/STRUCT/enum, FUNCTION, FUNCTION_BLOCK, PROGRAM and VAR_GLOBAL subset
used here. It does not resolve instance members, expressions, FB call signatures,
task scheduling, concurrency, or machine behavior. Use the target IDE for those.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path
import re
import sys


BUILTIN_TYPES = frozenset("""
BOOL BYTE WORD DWORD LWORD SINT INT DINT LINT USINT UINT UDINT ULINT
REAL LREAL TIME LTIME DATE LDATE TIME_OF_DAY TOD LTOD LTIME_OF_DAY
DATE_AND_TIME DT LDT LDATE_AND_TIME STRING WSTRING CHAR WCHAR
""".split())
VAR_WORD = r"VAR(?:_INPUT|_OUTPUT|_IN_OUT|_GLOBAL|_TEMP|_EXTERNAL|_STAT|_INST)?"
DECLARATION = re.compile(
    r"\b(TYPE|FUNCTION_BLOCK|FUNCTION|PROGRAM)\s+([A-Za-z_]\w*)", re.I
)
TYPE_REFERENCE = re.compile(
    r":\s*(?:ARRAY\s*\[[^\]]*\]\s+OF\s+)*"
    r"(?:(?:POINTER|REFERENCE)\s+TO\s+)?([A-Za-z_]\w*)", re.I
)
KIND_ORDER = {"enum": 0, "struct": 1, "type": 2,
              "function": 3, "fb": 4, "gvl": 5, "program": 6}


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    code: str
    message: str

    def display(self, root: Path) -> str:
        try:
            path = self.path.relative_to(root)
        except ValueError:
            path = self.path
        return f"{path}:{self.line}: {self.code}: {self.message}"


@dataclass
class Source:
    path: Path
    original: str
    code: str
    name: str = ""
    kind: str = ""
    enum_members: dict[str, int] = field(default_factory=dict)
    type_references: list[tuple[str, int]] = field(default_factory=list)
    dependencies: set[str] = field(default_factory=set)


@dataclass
class CheckResult:
    root: Path
    sources: list[Source]
    findings: list[Finding]
    import_order: list[Source]
    source_dirs: tuple[str, ...] = ("src",)

    @property
    def ok(self) -> bool:
        return not self.findings


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def mask_noncode(text: str) -> str:
    """Mask comments, pragmas and quoted strings, preserving offsets/newlines.

    Supports nested IEC (* *) comments, // comments, {$...} pragmas, doubled
    quote characters and IEC $ escapes. Delimiter keywords in these regions
    must never be treated as executable ST.
    """
    chars = list(text)
    i = 0
    while i < len(text):
        start = i
        if text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
        elif text.startswith("(*", i):
            depth = 1
            i += 2
            while i < len(text) and depth:
                if text.startswith("(*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*)", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            if depth:
                raise ValueError(f"unclosed block comment at line {line_number(text, start)}")
        elif text[i] == "{":
            end = text.find("}", i + 1)
            if end < 0:
                raise ValueError(f"unclosed pragma at line {line_number(text, start)}")
            i = end + 1
        elif text[i] in "\"'":
            quote = text[i]
            i += 1
            closed = False
            while i < len(text):
                if text[i] == "$":
                    i += 2
                elif text[i] == quote:
                    if i + 1 < len(text) and text[i + 1] == quote:
                        i += 2
                    else:
                        i += 1
                        closed = True
                        break
                else:
                    i += 1
            if not closed:
                raise ValueError(f"unclosed string at line {line_number(text, start)}")
        else:
            i += 1
            continue
        for j in range(start, min(i, len(text))):
            if chars[j] not in "\r\n":
                chars[j] = " "
    return "".join(chars)


def check_delimiters(source: Source, findings: list[Finding]) -> None:
    openers = {"IF": "END_IF", "CASE": "END_CASE", "FOR": "END_FOR",
               "WHILE": "END_WHILE", "REPEAT": "END_REPEAT",
               "TYPE": "END_TYPE", "STRUCT": "END_STRUCT",
               "FUNCTION": "END_FUNCTION", "FUNCTION_BLOCK": "END_FUNCTION_BLOCK",
               "PROGRAM": "END_PROGRAM"}
    stack: list[tuple[str, str, int]] = []
    for match in re.finditer(r"\b[A-Za-z_]\w*\b", source.code):
        token = match.group().upper()
        line = line_number(source.code, match.start())
        expected = "END_VAR" if re.fullmatch(VAR_WORD, token) else openers.get(token)
        if expected:
            stack.append((token, expected, line))
        elif token in set(openers.values()) | {"END_VAR"}:
            if not stack:
                findings.append(Finding(source.path, line, "delimiter", f"unexpected {token}"))
            elif stack[-1][1] != token:
                findings.append(Finding(source.path, line, "delimiter",
                                        f"{token} closes {stack[-1][0]}; expected {stack[-1][1]}"))
                stack.pop()
            else:
                stack.pop()
    for token, expected, line in stack:
        findings.append(Finding(source.path, line, "delimiter", f"{token} is missing {expected}"))


def parse_integer(value: str) -> int:
    value = value.strip().replace("_", "")
    # IEC typed literals such as UINT#16#0010 and decimal literals.
    value = re.sub(r"^[A-Za-z]+#", "", value)
    if re.fullmatch(r"[+-]?\d+", value):
        return int(value)
    match = re.fullmatch(r"(2|8|16)#([0-9A-Fa-f]+)", value)
    if match:
        return int(match[2], int(match[1]))
    raise ValueError("expected an explicit integer wire value")


def parse_source(path: Path, findings: list[Finding]) -> Source:
    original = path.read_text(encoding="utf-8-sig")
    try:
        code = mask_noncode(original)
    except ValueError as error:
        findings.append(Finding(path, 1, "lexical", str(error)))
        return Source(path, original, "")
    source = Source(path, original, code)
    check_delimiters(source, findings)
    for match in re.finditer(r"\bAT\b|%[IQ][A-Za-z0-9_.]*", code, re.I):
        findings.append(Finding(path, line_number(code, match.start()), "physical-io",
                                f"physical/direct address binding is forbidden here: {match.group()}"))

    declarations = list(DECLARATION.finditer(code))
    if not declarations and re.search(r"\bVAR_GLOBAL\b", code, re.I):
        source.name = path.stem
        source.kind = "gvl"
    elif len(declarations) != 1:
        findings.append(Finding(path, 1, "declaration",
                                f"expected one named TYPE/POU or a GVL; found {len(declarations)}"))
        return source
    else:
        header = declarations[0]
        source.name = header[2]
        keyword = header[1].upper()
        source.kind = {"TYPE": "type", "FUNCTION": "function",
                       "FUNCTION_BLOCK": "fb", "PROGRAM": "program"}[keyword]
        if source.name != path.stem:
            findings.append(Finding(path, line_number(code, header.start()), "filename",
                                    f"declaration {source.name} does not match {path.stem}"))
        if keyword == "TYPE":
            tail = code[header.end():]
            if re.match(r"\s*:\s*STRUCT\b", tail, re.I):
                source.kind = "struct"
            elif re.match(r"\s*:\s*\(", tail):
                source.kind = "enum"
                enum = re.match(r"\s*:\s*\((.*?)\)\s*(?:([A-Za-z_]\w*)\s*)?"
                                r"(?::=\s*([\w.]+))?\s*;", tail, re.S)
                if not enum:
                    findings.append(Finding(path, 1, "enum-shape", "unsupported or malformed enum declaration"))
                else:
                    if enum[2]:
                        source.type_references.append((enum[2], line_number(code, header.start())))
                    wire_values: dict[int, str] = {}
                    for entry in enum[1].split(","):
                        member = re.fullmatch(r"\s*([A-Za-z_]\w*)\s*:=\s*(.*?)\s*", entry, re.S)
                        if not member:
                            findings.append(Finding(path, 1, "enum-wirevalue",
                                                    f"enum members need explicit wire values: {entry.strip()}"))
                            continue
                        name = member[1]
                        try:
                            value = parse_integer(member[2])
                        except ValueError as error:
                            findings.append(Finding(path, 1, "enum-wirevalue", f"{name}: {error}"))
                            continue
                        key = name.upper()
                        if key in source.enum_members:
                            findings.append(Finding(path, 1, "duplicate-enum-member", f"duplicate member {name}"))
                        if value in wire_values:
                            findings.append(Finding(path, 1, "duplicate-enum-wirevalue",
                                                    f"{name} and {wire_values[value]} both use {value}"))
                        source.enum_members[key] = value
                        wire_values[value] = name
                    if enum[3] and enum[3].split(".")[-1].upper() not in source.enum_members:
                        findings.append(Finding(path, 1, "enum-member", f"unknown default {enum[3]}"))

    # Restrict colon scanning to declarations: CASE labels are not type uses.
    regions: list[tuple[str, int]] = []
    for match in re.finditer(rf"\b{VAR_WORD}\b(.*?)\bEND_VAR\b", code, re.I | re.S):
        regions.append((match[1], match.start(1)))
    for match in re.finditer(r"\bSTRUCT\b(.*?)\bEND_STRUCT\b", code, re.I | re.S):
        regions.append((match[1], match.start(1)))
    if source.kind in {"function", "type"} and declarations:
        header = declarations[0]
        end = code.find(";", header.end())
        if source.kind == "function":
            end = code.find("\n", header.end())
        regions.append((code[header.end():end if end >= 0 else len(code)], header.end()))
    for region, offset in regions:
        for match in TYPE_REFERENCE.finditer(region):
            source.type_references.append((match[1], line_number(code, offset + match.start())))
    return source


def dependency_order(sources: list[Source], findings: list[Finding]) -> list[Source]:
    symbols = {source.name.upper(): source for source in sources if source.name}
    state: dict[str, int] = {}
    trail: list[str] = []
    ordered: list[Source] = []

    def sort_key(name: str) -> tuple[int, str]:
        return KIND_ORDER.get(symbols[name].kind, 99), name

    def visit(name: str) -> None:
        if state.get(name) == 2:
            return
        if state.get(name) == 1:
            cycle = trail[trail.index(name):] + [name]
            findings.append(Finding(symbols[name].path, 1, "dependency-cycle",
                                    " -> ".join(symbols[key].name for key in cycle)))
            return
        state[name] = 1
        trail.append(name)
        for dependency in sorted(symbols[name].dependencies, key=sort_key):
            visit(dependency)
        trail.pop()
        state[name] = 2
        ordered.append(symbols[name])

    for name in sorted(symbols, key=sort_key):
        visit(name)
    return ordered


def check_repository(root: Path, source_dirs: tuple[str, ...] = ("src",)) -> CheckResult:
    root = root.resolve()
    findings: list[Finding] = []
    paths: set[Path] = set()
    for directory in source_dirs:
        base = root / directory
        paths.update(path for path in base.rglob("*") if path.is_file() and path.suffix.lower() == ".st")
    if not paths:
        findings.append(Finding(root, 1, "no-sources", "no .st files found in configured source directories"))
    sources = [parse_source(path, findings) for path in sorted(paths)]
    symbols: dict[str, Source] = {}
    for source in sources:
        if not source.name:
            continue
        key = source.name.upper()
        if key in symbols:
            findings.append(Finding(source.path, 1, "duplicate-declaration",
                                    f"{source.name} was already declared in {symbols[key].path.relative_to(root)}"))
        else:
            symbols[key] = source
    for source in sources:
        if not source.name:
            continue
        for name, line in source.type_references:
            key = name.upper()
            if key in BUILTIN_TYPES:
                continue
            if key not in symbols:
                findings.append(Finding(source.path, line, "missing-type", f"undefined type/FB {name}"))
            elif symbols[key].kind not in {"enum", "struct", "type", "fb"}:
                findings.append(Finding(source.path, line, "invalid-type", f"{name} is not a TYPE or FB"))
            else:
                source.dependencies.add(key)

        for match in re.finditer(r"\b([A-Za-z_]\w*)\s*\.\s*([A-Za-z_]\w*)", source.code):
            qualifier, member = match[1].upper(), match[2].upper()
            line = line_number(source.code, match.start())
            if qualifier.startswith("E_") or (qualifier in symbols and symbols[qualifier].kind == "enum"):
                enum_source = symbols.get(qualifier)
                if enum_source is None or enum_source.kind != "enum":
                    findings.append(Finding(source.path, line, "missing-enum", f"undefined enum {match[1]}"))
                else:
                    if member not in enum_source.enum_members:
                        findings.append(Finding(source.path, line, "enum-member",
                                                f"{match[1]}.{match[2]} is not declared"))
                    if qualifier != source.name.upper():
                        source.dependencies.add(qualifier)
            elif qualifier.startswith("GVL_"):
                if qualifier not in symbols or symbols[qualifier].kind != "gvl":
                    findings.append(Finding(source.path, line, "missing-gvl", f"undefined GVL {match[1]}"))
                elif qualifier != source.name.upper():
                    source.dependencies.add(qualifier)

        for match in re.finditer(r"\b([A-Za-z_]\w*)\s*\(", source.code):
            name = match[1].upper()
            target = symbols.get(name)
            if target and target.kind == "function":
                source.dependencies.add(name)
            elif name.startswith("F_") and target is None:
                findings.append(Finding(source.path, line_number(source.code, match.start()),
                                        "missing-function", f"undefined project function {match[1]}"))
    order = dependency_order(sources, findings)
    return CheckResult(root, sources, findings, order, source_dirs)


def write_inventory(result: CheckResult, destination: Path) -> None:
    if not result.ok:
        raise ValueError("cannot generate an inventory for invalid sources")
    symbols = {source.name.upper(): source.name for source in result.sources}
    command = "python tools/build_bundle.py"
    if result.source_dirs != ("src",):
        command += "".join(f" --source-dir {directory}" for directory in result.source_dirs)
    lines = ["# Inventário ST", "", f"Gerado por `{command}`; não editar manualmente.", "",
             f"{len(result.sources)} objetos. A ordem abaixo respeita as dependências identificadas.", "",
             "| Ordem | Objeto | Tipo | Dependências | Fonte |", "| --- | --- | --- | --- | --- |"]
    for index, source in enumerate(result.import_order, 1):
        path = source.path.relative_to(result.root).as_posix()
        dependencies = ", ".join(f"`{symbols[key]}`" for key in sorted(source.dependencies)) or "—"
        lines.append(f"| {index} | `{source.name}` | {source.kind} | {dependencies} | [{source.path.name}](../{path}) |")
    lines.extend(["", "Verificação estática: declarações e nomes de arquivo, tipos utilizados, membros e valores",
                  "de enums, delimitadores, ausência de endereçamento físico AT/%I/%Q e ciclos de dependência.", "",
                  "O bundle é texto para revisão/importação manual por objeto; não é XML PLCopen nem projeto nativo.",
                  "O checker cobre o subconjunto textual deste repositório. Não verifica assinaturas de chamada,",
                  "campos de instância, expressões, escalonamento, concorrência ou comportamento em execução.",
                  "Compilação, simulação e validação no Machine Expert permanecem pendentes.", ""])
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source-dir", action="append", help="relative source directory; repeatable (default: src)")
    args = parser.parse_args()
    result = check_repository(args.root, tuple(args.source_dir or ["src"]))
    for finding in result.findings:
        print(finding.display(result.root), file=sys.stderr)
    print(f"Static source checks: {len(result.sources)} objects, {len(result.findings)} findings.")
    print("No ST compilation or runtime behavior was tested.")
    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
