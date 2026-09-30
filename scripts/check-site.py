#!/usr/bin/env python3
"""Dependency-free checks for the static project site."""

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit
import sys

ROOT = Path(__file__).resolve().parents[1] / "site"


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.refs = []
        self.images = []
        self.title = False
        self.description = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("a", "link") and attrs.get("href"):
            self.refs.append(attrs["href"])
        if tag == "script" and attrs.get("src"):
            self.refs.append(attrs["src"])
        if tag == "img":
            self.images.append(attrs)
            if attrs.get("src"):
                self.refs.append(attrs["src"])
        if tag == "title":
            self.title = True
        if tag == "meta" and attrs.get("name", "").lower() == "description" and attrs.get("content", "").strip():
            self.description = True


errors = []
pages = sorted(ROOT.glob("*.html"))
for page in pages:
    parser = Page()
    source = page.read_text(encoding="utf-8")
    parser.feed(source)
    if not parser.title:
        errors.append(f"{page.name}: missing title")
    if not parser.description:
        errors.append(f"{page.name}: missing meta description")
    for image in parser.images:
        if "alt" not in image:
            errors.append(f"{page.name}: image missing alt text")
    for ref in parser.refs:
        target = urlsplit(ref)
        if target.scheme or target.netloc or ref.startswith("#"):
            continue
        local = (ROOT / target.path.lstrip("/")).resolve()
        if not local.exists():
            errors.append(f"{page.name}: missing local target {ref}")
    if "Source-native systems. Directly." not in source:
        errors.append(f"{page.name}: missing shared brand line")

for asset in ROOT.rglob("*"):
    if asset.is_file() and asset.stat().st_size > 200_000:
        errors.append(f"{asset.relative_to(ROOT)}: exceeds 200 KB")

if errors:
    print("SITE CHECK FAILED")
    print("\n".join(f"- {error}" for error in errors))
    sys.exit(1)
print(f"SITE CHECK OK: {len(pages)} pages, local links, metadata, and asset budgets verified")
