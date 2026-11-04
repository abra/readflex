#!/usr/bin/env python3
"""Render a local Markdown handoff into a linked, Cyrillic-capable PDF.

Requires Python 3, PyMuPDF, Markdown and fontTools. No network access is used.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import textwrap
from datetime import date
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit

import fitz
import markdown
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont


CSS = """
@font-face { font-family: Guide; src: url(fonts/Guide-Regular.ttf); }
@font-face { font-family: Guide; src: url(fonts/Guide-Bold.ttf); font-weight: bold; }
@font-face { font-family: Guide; src: url(fonts/Guide-Italic.ttf); font-style: italic; }
@font-face { font-family: GuideCode; src: url(fonts/Guide-Code.ttf); }
body { font-family: Guide; font-size: 10pt; line-height: 1.41; color: #253041; margin: 0; }
p { margin-top: 0; margin-bottom: 8pt; }
h1 { font-size: 26pt; color: #123c43; margin-top: 0; margin-bottom: 15pt; }
h2 { font-size: 20pt; color: #123c43; margin-top: 22pt; margin-bottom: 12pt; page-break-after: avoid; }
h3 { font-size: 13pt; color: #123c43; margin-top: 16pt; margin-bottom: 7pt; page-break-after: avoid; }
h4 { font-size: 11pt; color: #123c43; margin-top: 12pt; margin-bottom: 6pt; page-break-after: avoid; }
a { color: #087a81; text-decoration: none; }
strong { font-weight: bold; }
em { font-style: italic; }
ul, ol { margin-top: 2pt; margin-bottom: 10pt; padding-left: 20pt; }
li { margin-bottom: 4pt; }
li p { margin-bottom: 4pt; }
table { width: 100%; border-collapse: collapse; margin-top: 5pt; margin-bottom: 11pt; font-size: 8.3pt; }
th { font-weight: bold; color: #123c43; }
td, th { padding: 5pt; border-bottom: 0.5pt solid #d7e0e3; text-align: left; vertical-align: top; }
tr { page-break-inside: avoid; }
code { font-family: GuideCode; font-size: 8.4pt; color: #24565e; }
pre { font-family: GuideCode; font-size: 8.3pt; line-height: 1.35; border-left: 1pt solid #a6c7c5; padding: 8pt; margin: 7pt 0 11pt 0; white-space: pre-wrap; }
pre code { font-family: GuideCode; font-size: 8.3pt; color: #253041; }
blockquote { border-left: 2pt solid #39928d; margin: 8pt 0 12pt 0; padding: 9pt 11pt; }
blockquote p { margin-bottom: 3pt; }
hr { border: 0; border-top: 0.5pt solid #d7e0e3; margin-top: 14pt; margin-bottom: 14pt; }
.cover { padding-top: 100pt; page-break-after: always; }
.cover-label { color: #087a81; font-size: 11pt; margin-bottom: 20pt; }
.cover h1 { font-size: 43pt; margin-bottom: 16pt; }
.cover-subtitle { font-size: 20pt; color: #3f5963; margin-bottom: 35pt; }
.cover-meta { font-size: 10pt; color: #61717a; }
.cover-note { margin-top: 45pt; padding-top: 14pt; border-top: 1pt solid #a6c7c5; font-size: 10pt; color: #47616a; }
.toc-title { font-size: 23pt; font-weight: bold; color: #123c43; margin: 0 0 18pt 0; }
.toc { page-break-after: always; }
.toc table { font-size: 10pt; }
.toc td { padding-top: 5pt; padding-bottom: 5pt; border-bottom: 0.5pt solid #e4ebed; }
.toc .toc-sub { padding-left: 15pt; font-size: 8.8pt; }
.toc .toc-page { width: 30pt; text-align: right; color: #61717a; }
.source-ref { color: #61717a; font-size: 8pt; }
.document-title { font-size: 20pt; margin-bottom: 16pt; }
.heading-lead { page-break-inside: avoid; }
"""


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repository-root", type=Path, default=Path.cwd())
    parser.add_argument("--repository-url", default="")
    parser.add_argument("--revision", default="")
    parser.add_argument("--date", default=date.today().isoformat())
    parser.add_argument("--title", default="Readflex")
    parser.add_argument("--subtitle", default="Руководство для новой команды")
    parser.add_argument("--preview-dir", type=Path)
    parser.add_argument("--language", choices=("ru", "en"), default="ru")
    return parser.parse_args()


def make_fonts(repository_root: Path, working_dir: Path):
    destination = working_dir / "fonts"
    destination.mkdir(parents=True, exist_ok=True)
    source = repository_root / "packages/component_library/fonts"
    for weight, name in ((400, "Regular"), (700, "Bold")):
        target = destination / f"Guide-{name}.ttf"
        # Rebuild from tracked font sources so an earlier export cannot leave
        # stale instances after the repository fonts change.
        font = TTFont(source / "OpenSans-Variable.ttf")
        instantiateVariableFont(font, {"wght": weight, "wdth": 100}, inplace=True)
        font.save(target)
        font.close()
    italic = destination / "Guide-Italic.ttf"
    italic.write_bytes((source / "PTSerif-Italic.ttf").read_bytes())
    code = destination / "Guide-Code.ttf"
    # Use repository fonts on every OS; a system font would change pagination.
    code.write_bytes((destination / "Guide-Regular.ttf").read_bytes())
    return destination


def wrap_code_blocks(source: str) -> str:
    """Wrap command examples before layout; preserve Markdown fence language."""
    lines, fenced = [], False
    for line in source.splitlines():
        if re.match(r"^\s*(```|~~~)", line):
            fenced = not fenced
            lines.append(line)
            continue
        if fenced and len(line) > 88:
            lines.extend(textwrap.wrap(line, width=88, expand_tabs=True,
                                       replace_whitespace=False,
                                       drop_whitespace=False,
                                       break_long_words=True,
                                       break_on_hyphens=False,
                                       subsequent_indent="  "))
        else:
            lines.append(line)
    return "\n".join(lines)


def decorate_links(document: str, args) -> str:
    def link(match):
        before, href, after, label = match.groups()
        decoded = html.unescape(href)
        parsed = urlsplit(decoded)
        if parsed.scheme or parsed.netloc or decoded.startswith("#"):
            return match.group(0)
        target = (args.input.parent / unquote(parsed.path)).resolve()
        try:
            relative = target.relative_to(args.repository_root.resolve()).as_posix()
        except ValueError:
            relative = unquote(parsed.path)
        if args.repository_url:
            url = args.repository_url.rstrip("/") + "/blob/" + quote(args.revision or "main", safe="") + "/" + quote(relative, safe="/")
            if parsed.fragment:
                url += "#" + quote(parsed.fragment, safe="-_")
            return f'<a{before}href="{html.escape(url)}"{after}>{label}</a>'
        # Relative paths remain useful in a standalone handoff; file:// links do not.
        plain_label = re.sub(r"<[^>]+>", "", html.unescape(label))
        if plain_label.rstrip("/") == relative.rstrip("/"):
            return f'<span class="source-ref">{html.escape(relative)}</span>'
        return f'{label} <span class="source-ref">({html.escape(relative)})</span>'
    return re.sub(r'<a([^>]*?)href="([^"]*)"([^>]*)>(.*?)</a>', link, document, flags=re.S)


def main():
    args = arguments()
    args.input = args.input.resolve()
    args.output = args.output.resolve()
    args.repository_root = args.repository_root.resolve()
    if args.input == args.output:
        raise SystemExit("The PDF output must not overwrite its Markdown source.")
    if not args.input.is_file():
        raise SystemExit(f"Markdown source does not exist: {args.input}")
    if args.output.suffix.lower() != ".pdf":
        raise SystemExit("PDF output must have a .pdf extension.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fonts = make_fonts(args.repository_root, args.output.parent)
    source = wrap_code_blocks(args.input.read_text(encoding="utf-8"))
    md = markdown.Markdown(extensions=["tables", "fenced_code", "toc", "sane_lists"])
    body = decorate_links(md.convert(source), args)
    # MuPDF's heading break hints alone do not prevent every orphan heading.
    # Group only its first paragraph; never keep an entire chapter or table together.
    body = re.sub(r'(<h([234])[^>]*>(?:(?!</h[234]>).)*</h\2>\s*<p>.*?</p>)',
                  r'<div class="heading-lead">\1</div>', body, flags=re.S)
    headings = []
    for level, attributes, title in re.findall(r'<h([123])([^>]*)>(.*?)</h\1>', body, re.S):
        identifier = re.search(r'\bid="([^"]+)"', attributes)
        if identifier and level in ("2", "3"):
            headings.append((int(level), identifier.group(1), re.sub(r"<[^>]+>", "", title)))
    if not headings:
        raise SystemExit("Input must contain at least one h2 section (## Heading).")

    # The Markdown title belongs in the body too, but should not mimic a second cover.
    body = re.sub(r'<h1([^>]*)>', r'<h1 class="document-title"\1>', body, count=1)
    labels = ({"toc": "Содержание", "version": "Версия исходного кода", "date": "Подготовлено", "note": "Практическая карта архитектуры, сценариев, сборки и сопровождения. Описание отражает проверенный срез проекта; исходный код и поддерживаемая документация остаются источником истины.", "page": "стр.", "header": "Руководство для команды"}
              if args.language == "ru" else
              {"toc": "Contents", "version": "Source revision", "date": "Prepared", "note": "A practical guide to architecture, flows, builds and maintenance. This document describes a verified project snapshot; source code and maintained documentation remain authoritative.", "page": "p.", "header": "Team handoff"})

    page_box = fitz.paper_rect("a4")
    content_box = fitz.Rect(46, 61, page_box.width - 46, page_box.height - 52)
    heading_ids = {identifier for _level, identifier, _title in headings}
    forced_breaks = set()
    layout_passes = 0

    def content(positions):
        nonlocal layout_passes
        layout_passes += 1
        if layout_passes > len(headings) * 2 + 10:
            raise RuntimeError("PDF pagination did not stabilize; inspect long headings or tables.")
        # Story does not honor every CSS keep-with-next hint. Add a page break
        # only when a measured heading would leave too little room for its lead.
        previous = None
        for position in positions:
            if position.id not in heading_ids or not position.open_close & 1:
                continue
            level = position.heading
            reserve = 110 if level == 2 else 85
            if position.rect[1] > content_box.y1 - reserve:
                identifier = position.id
                if (previous and previous.page_num == position.page_num
                        and previous.heading == 2 and level == 3
                        and position.rect[1] - previous.rect[3] < 80):
                    identifier = previous.id
                if identifier in forced_breaks:
                    raise RuntimeError(f"Cannot place heading with its lead: {identifier}")
                forced_breaks.add(identifier)
                # Correct the earliest orphan first. Later pages must be measured
                # again after this reflow, rather than receiving stale breaks.
                break
            previous = position
        pages = {position.id: position.page_num for position in positions
                 if position.id and position.open_close & 1}
        rows = []
        for level, identifier, title in headings:
            css_class = ' class="toc-sub"' if level == 3 else ""
            rows.append(f'<tr><td{css_class}><a href="#{identifier}">{title}</a></td>'
                        f'<td class="toc-page">{pages.get(identifier, "—")}</td></tr>')
        revision = f'<br/>{labels["version"]}: {html.escape(args.revision)}' if args.revision else ""
        flowing_body = body
        for identifier in forced_breaks:
            flowing_body = re.sub(r'(<h[234])([^>]*\bid="' + re.escape(identifier) + r'"[^>]*>)',
                                  r'\1 style="page-break-before:always"\2', flowing_body)
        return (f'<html><body><div class="cover"><p class="cover-label">ENGINEERING HANDOFF</p>'
                f'<h1>{html.escape(args.title)}</h1><p class="cover-subtitle">{html.escape(args.subtitle)}</p>'
                f'<p class="cover-meta">{labels["date"]}: {html.escape(args.date)}{revision}</p>'
                f'<p class="cover-note">{labels["note"]}</p></div>'
                f'<div class="toc"><p class="toc-title">{labels["toc"]}</p><table>{"".join(rows)}</table></div>'
                f'{flowing_body}</body></html>')

    def rectangle(_rect_number, _filled):
        return page_box, content_box, None

    positions = []
    document = fitz.Story.write_stabilized_with_links(
        content, rectangle, user_css=CSS, em=10,
        archive=fitz.Archive(args.output.parent),
        positionfn=positions.append, add_header_ids=False)
    outline = []
    heading_lookup = {identifier: (level, title) for level, identifier, title in headings}
    seen = set()
    for pos in positions:
        if pos.id in heading_lookup and pos.open_close & 1 and pos.id not in seen:
            seen.add(pos.id)
            level, title = heading_lookup[pos.id]
            outline.append([level - 1, html.unescape(title), pos.page_num])
    document.set_toc(outline)
    document.set_metadata({"title": f"{args.title} — {args.subtitle}", "author": "Readflex project", "subject": "Architecture, onboarding and engineering handoff", "keywords": "Readflex, Flutter, Dart, Rust, Pagecraft, team handoff", "creator": "Local Markdown / PyMuPDF handoff renderer"})

    for number, page in enumerate(document, 1):
        page.insert_font(fontname="guide", fontfile=str(fonts / "Guide-Regular.ttf"))
        if number > 1:
            page.draw_line((46, 44), (page_box.width - 46, 44), color=(0.79, 0.85, 0.86), width=0.5)
            page.insert_text((46, 35), f'{args.title}  /  {labels["header"]}', fontname="guide", fontsize=8, color=(0.39, 0.46, 0.50))
        page.insert_text((46, page_box.height - 28), args.date, fontname="guide", fontsize=8, color=(0.39, 0.46, 0.50))
        footer = f'{labels["page"]} {number} / {len(document)}'
        # Font measurement avoids clipping with non-ASCII labels.
        font = fitz.Font(fontfile=str(fonts / "Guide-Regular.ttf"))
        width = font.text_length(footer, fontsize=8)
        page.insert_text((page_box.width - 46 - width, page_box.height - 28), footer, fontname="guide", fontsize=8, color=(0.39, 0.46, 0.50))

    document.subset_fonts()
    document.save(args.output, garbage=4, deflate=True)
    extracted = "\n".join(page.get_text() for page in document)
    if "\ufffd" in extracted:
        raise SystemExit("PDF contains replacement characters; inspect embedded fonts.")
    previews = args.preview_dir
    if previews:
        previews.mkdir(parents=True, exist_ok=True)
        for number, page in enumerate(document, 1):
            page.get_pixmap(matrix=fitz.Matrix(0.9, 0.9), alpha=False).save(previews / f"page-{number:03d}.png")
    print(json.dumps({"output": str(args.output), "pages": len(document), "outline_items": len(outline), "bytes": args.output.stat().st_size, "text_characters": len(extracted), "replacement_characters": extracted.count("\ufffd")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
