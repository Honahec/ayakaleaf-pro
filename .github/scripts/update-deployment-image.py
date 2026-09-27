#!/usr/bin/env python3
"""Replace only the pinned ayakaleaf-pro image digest in a Kustomize file."""

import re
import sys
from pathlib import Path


def update(path: Path, digest: str) -> bool:
    if not re.fullmatch(r"sha256:[a-f0-9]{64}", digest):
        raise ValueError(f"Invalid image digest: {digest}")

    original = path.read_text()
    lines = original.splitlines(keepends=True)
    headers = [i for i, line in enumerate(lines) if re.fullmatch(r"images:\s*", line)]
    if len(headers) != 1:
        raise ValueError("Expected exactly one top-level images section")
    start = headers[0] + 1
    end = next(
        (i for i in range(start, len(lines)) if re.match(r"^[A-Za-z][\w-]*:", lines[i])),
        len(lines),
    )

    target = re.compile(r"^(?P<indent> *)- name: ghcr\.io/honahec/ayakaleaf-pro[ \t]*\r?\n?$")
    entries = [(i, target.fullmatch(lines[i])) for i in range(start, end)]
    matches = [(i, match) for i, match in entries if match is not None]
    if len(matches) != 1:
        raise ValueError("Expected exactly one ayakaleaf-pro image entry")
    index, match = matches[0]
    indent = len(match.group("indent"))
    item_end = next(
        (i for i in range(index + 1, end) if re.match(rf"^ {{0,{indent}}}- ", lines[i])),
        end,
    )
    digest_line = re.compile(rf"^(?P<indent> {{{indent + 1},}})digest: sha256:[a-f0-9]{{64}}(?P<ending>\r?\n?)$")
    digest_matches = [(i, found) for i in range(index + 1, item_end) if (found := digest_line.fullmatch(lines[i]))]
    if len(digest_matches) != 1:
        raise ValueError("Expected exactly one existing pinned digest in image entry")
    digest_index, found = digest_matches[0]
    lines[digest_index] = f'{found.group("indent")}digest: {digest}{found.group("ending")}'
    updated = "".join(lines)
    if updated == original:
        return False
    path.write_text(updated)
    return True


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: update-deployment-image.py KUSTOMIZATION DIGEST")
    try:
        update(Path(sys.argv[1]), sys.argv[2])
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
