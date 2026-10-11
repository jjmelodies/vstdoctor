"""
build-manual-fallback.py - generate docs/manual.pdf from docs/manual.md
without pandoc.

build-manual.ps1 prefers pandoc (cleaner typography). When pandoc isn't
installed the .ps1 falls back to this script, which uses reportlab (a pure
Python dep already pinned by the project's other tooling).

Usage:
    py tools\\build-manual-fallback.py

Renders a deliberate subset of CommonMark - the constructs the manual
actually uses: ATX headings (# .. ###), paragraphs, fenced code blocks,
unordered lists (- and *), pipe tables, bold (**x**), inline code (`x`),
italics (*x*). Not a general markdown engine.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


REPO_ROOT = Path(__file__).resolve().parent.parent
SRC = REPO_ROOT / "docs" / "manual.md"
DST = REPO_ROOT / "docs" / "manual.pdf"

PRODUCT_NAME = os.environ.get("PRODUCT_NAME", "Plugin")
COMPANY_NAME = os.environ.get("COMPANY_NAME", "")
DOC_TITLE = f"{PRODUCT_NAME} User Manual"


def make_styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    body = ParagraphStyle(
        "Body",
        parent=base["BodyText"],
        fontName="Helvetica",
        fontSize=10,
        leading=13,
        spaceAfter=6,
        alignment=TA_LEFT,
    )
    return {
        "title": ParagraphStyle(
            "TitleX", parent=base["Title"], fontSize=24, leading=28, spaceAfter=18
        ),
        "h1": ParagraphStyle(
            "H1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=18,
            leading=22,
            spaceBefore=18,
            spaceAfter=10,
            textColor=colors.HexColor("#1a1a1a"),
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=18,
            spaceBefore=12,
            spaceAfter=6,
            textColor=colors.HexColor("#222222"),
        ),
        "h3": ParagraphStyle(
            "H3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=14,
            spaceBefore=8,
            spaceAfter=4,
        ),
        "body": body,
        "li": ParagraphStyle(
            "LI",
            parent=body,
            leftIndent=14,
            bulletIndent=2,
            spaceAfter=2,
        ),
        "code": ParagraphStyle(
            "Code",
            parent=body,
            fontName="Courier",
            fontSize=9,
            leading=11,
            leftIndent=8,
            rightIndent=8,
            spaceBefore=4,
            spaceAfter=8,
            backColor=colors.HexColor("#f4f4f4"),
            borderColor=colors.HexColor("#e0e0e0"),
            borderWidth=0.5,
            borderPadding=4,
        ),
        "quote": ParagraphStyle(
            "Quote",
            parent=body,
            leftIndent=18,
            rightIndent=18,
            textColor=colors.HexColor("#444444"),
            fontName="Helvetica-Oblique",
            spaceBefore=4,
            spaceAfter=8,
        ),
    }


def inline(text: str) -> str:
    """Render inline markdown to ReportLab mini-HTML."""
    # Code spans first so we don't double-escape inside them.
    text = re.sub(
        r"`([^`]+)`",
        lambda m: f'<font name="Courier" size="9">{escape_xml(m.group(1))}</font>',
        text,
    )
    # Bold then italic.
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", r"<i>\1</i>", text)
    return text


def escape_xml(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def parse_table(lines: list[str], start: int) -> tuple[list[list[str]], int]:
    """Consume a pipe table starting at lines[start]. Returns rows + new index."""
    rows: list[list[str]] = []
    i = start
    while i < len(lines) and "|" in lines[i]:
        raw = lines[i].strip()
        if raw.startswith("|"):
            raw = raw[1:]
        if raw.endswith("|"):
            raw = raw[:-1]
        cells = [c.strip() for c in raw.split("|")]
        rows.append(cells)
        i += 1
    # Drop the alignment row (2nd row, all dashes).
    if len(rows) >= 2 and all(re.match(r"^:?-+:?$", c) for c in rows[1]):
        rows = [rows[0]] + rows[2:]
    return rows, i


def build_table(rows: list[list[str]], styles: dict[str, ParagraphStyle]) -> Table:
    cell_style = ParagraphStyle(
        "Cell", parent=styles["body"], fontSize=9, leading=11, spaceAfter=0
    )
    head_style = ParagraphStyle(
        "Head",
        parent=cell_style,
        fontName="Helvetica-Bold",
        textColor=colors.white,
    )
    data: list[list[Paragraph]] = []
    for r_idx, row in enumerate(rows):
        s = head_style if r_idx == 0 else cell_style
        data.append([Paragraph(inline(escape_xml(c)), s) for c in row])
    tbl = Table(data, repeatRows=1, hAlign="LEFT")
    tbl.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#444444")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7f7f7")]),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#cccccc")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return tbl


def build_story(md: str, styles: dict[str, ParagraphStyle]):
    story: list = []
    lines = md.splitlines()

    # Strip YAML frontmatter.
    if lines and lines[0].strip() == "---":
        end = 1
        while end < len(lines) and lines[end].strip() != "---":
            end += 1
        lines = lines[end + 1 :]

    story.append(Paragraph(DOC_TITLE, styles["title"]))

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        if stripped.startswith("```"):
            i += 1
            buf: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1  # consume closing fence
            code = "<br/>".join(escape_xml(b).replace(" ", "&nbsp;") for b in buf)
            story.append(Paragraph(code, styles["code"]))
            continue

        if stripped.startswith("# "):
            story.append(Paragraph(inline(escape_xml(stripped[2:])), styles["h1"]))
            i += 1
            continue
        if stripped.startswith("## "):
            story.append(Paragraph(inline(escape_xml(stripped[3:])), styles["h2"]))
            i += 1
            continue
        if stripped.startswith("### "):
            story.append(Paragraph(inline(escape_xml(stripped[4:])), styles["h3"]))
            i += 1
            continue

        if stripped.startswith(">"):
            story.append(Paragraph(inline(escape_xml(stripped.lstrip("> ").strip())), styles["quote"]))
            i += 1
            continue

        if "|" in stripped and i + 1 < len(lines) and re.search(r"^\|?\s*:?-+", lines[i + 1].strip()):
            rows, i = parse_table(lines, i)
            story.append(build_table(rows, styles))
            story.append(Spacer(1, 6))
            continue

        if stripped.startswith(("- ", "* ")):
            while i < len(lines) and lines[i].strip().startswith(("- ", "* ")):
                item = lines[i].strip()[2:]
                story.append(
                    Paragraph(
                        f"&bull; {inline(escape_xml(item))}",
                        styles["li"],
                    )
                )
                i += 1
            story.append(Spacer(1, 4))
            continue

        # Otherwise, paragraph: collect lines until blank.
        para: list[str] = [stripped]
        i += 1
        while i < len(lines) and lines[i].strip() and not _is_block_start(lines[i]):
            para.append(lines[i].strip())
            i += 1
        text = " ".join(para)
        story.append(Paragraph(inline(escape_xml(text)), styles["body"]))

    return story


def _is_block_start(line: str) -> bool:
    s = line.strip()
    return (
        s.startswith("#")
        or s.startswith("```")
        or s.startswith(("- ", "* ", "> "))
        or "|" in s
    )


def main() -> int:
    if not SRC.exists():
        print(f"ERROR: {SRC} not found", file=sys.stderr)
        return 1
    md = SRC.read_text(encoding="utf-8")
    styles = make_styles()

    DST.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(DST),
        pagesize=LETTER,
        leftMargin=0.9 * inch,
        rightMargin=0.9 * inch,
        topMargin=0.8 * inch,
        bottomMargin=0.8 * inch,
        title=DOC_TITLE,
        author=COMPANY_NAME,
    )
    story = build_story(md, styles)
    doc.build(story)
    print(f"[manual-fallback] wrote {DST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
