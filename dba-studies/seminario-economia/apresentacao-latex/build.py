"""Convert the seminar notebook to a Beamer deck without rewriting its text."""

from __future__ import annotations

import base64
import json
import re
import shutil
import subprocess
from pathlib import Path

from lxml import html
from PIL import Image


HERE = Path(__file__).resolve().parent
SEMINAR = HERE.parent
NOTEBOOK = SEMINAR / "seminario-scx5013.ipynb"
ASSETS = HERE / "assets"
OUTPUTS = HERE / "outputs"


def latex_escape(value: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}", "&": r"\&", "%": r"\%", "$": r"\$",
        "#": r"\#", "_": r"\_", "{": r"\{", "}": r"\}",
        "~": r"\textasciitilde{}", "^": r"\textasciicircum{}",
    }
    return "".join(replacements.get(character, character) for character in value)


def markdown_to_latex(markdown: str) -> str:
    # Notebook Markdown permits a list immediately after a sentence; Pandoc
    # needs a blank line there. Math delimiters also need to hug their content.
    markdown = re.sub(r"([^\n])\n(?=(?:- |\d+\. ))", r"\1\n\n", markdown)
    markdown = re.sub(
        r"(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)",
        lambda match: "$" + match.group(1).strip() + "$",
        markdown,
        flags=re.DOTALL,
    )
    # Keep the source's explicit list numbers, including its repeated "4.".
    if re.search(r"(?m)^\d+\. ", markdown):
        numbered = re.findall(r"(?m)^(\d+)\. (.+)$", markdown)
        first = f"{numbered[0][0]}. {numbered[0][1]}"
        last = f"{numbered[-1][0]}. {numbered[-1][1]}"
        markdown = markdown.replace(first, "\\begin{description}\n\\item[" + numbered[0][0] + ".] " + numbered[0][1], 1)
        for number, content in numbered[1:-1]:
            markdown = markdown.replace(f"{number}. {content}", f"\\item[{number}.] {content}", 1)
        if last != first:
            markdown = markdown.replace(last, "\\item[" + numbered[-1][0] + ".] " + numbered[-1][1] + "\n\\end{description}", 1)
    result = subprocess.run(
        ["pandoc", "-f", "markdown+tex_math_dollars+raw_tex", "-t", "latex", "--wrap=none"],
        input=markdown,
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


def source_text(cell: dict) -> str:
    return "".join(cell.get("source", []))


def output_text(value: str | list[str]) -> str:
    return "".join(value) if isinstance(value, list) else value


def frame(title: str, body: str, *, allow_breaks: bool = False) -> str:
    options = []
    if allow_breaks:
        options.append("allowframebreaks")
    option = "[" + ",".join(options) + "]" if options else ""
    return f"\\begin{{frame}}{option}{{{latex_escape(title)}}}\n{body}\n\\end{{frame}}\n"


def image_frame(title: str, path: Path) -> str:
    body = (
        "\\centering\n"
        f"\\includegraphics[width=0.95\\textwidth,height=0.78\\textheight,keepaspectratio]{{{path.as_posix()}}}"
    )
    return frame(title, body)


def markdown_fragments(markdown: str) -> list[tuple[str, str]]:
    """Separate images and internal headings while retaining the original words."""
    image_pattern = re.compile(r"!\[[^]]*\]\((?:<[^>]+>|[^)]+)\)")
    heading_pattern = re.compile(r"(?m)^#{4,5} (.+)$")
    pieces: list[tuple[str, str]] = []
    remaining = markdown
    while remaining:
        image_match = image_pattern.search(remaining)
        heading_match = heading_pattern.search(remaining)
        matches = [m for m in (image_match, heading_match) if m]
        if not matches:
            pieces.append(("text", remaining))
            break
        match = min(matches, key=lambda m: m.start())
        if match.start():
            pieces.append(("text", remaining[: match.start()]))
        if match.re is image_pattern:
            raw = match.group(0)
            target = raw[raw.find("](") + 2 : -1].strip("<>")
            pieces.append(("image", target))
        else:
            pieces.append(("heading", match.group(1)))
        remaining = remaining[match.end() :]
    return pieces


def prose_chunks(markdown: str, max_chars: int = 850) -> list[str]:
    paragraphs = re.split(r"\n\s*\n", markdown.strip())
    chunks: list[str] = []
    current = ""
    for paragraph in paragraphs:
        if current and len(current) + len(paragraph) + 2 > max_chars:
            chunks.append(current)
            current = ""
        current = paragraph if not current else current + "\n\n" + paragraph
    if current:
        chunks.append(current)
    return chunks


def table_frames(title: str, output: dict) -> list[str]:
    document = html.fromstring(output_text(output["data"]["text/html"]))
    header_rows = document.xpath("//thead/tr")
    if not header_rows:
        return []
    headers = [" ".join(node.itertext()).strip() for node in header_rows[0].xpath("./th")]
    rows = [
        [" ".join(node.itertext()).strip() for node in row.xpath("./td")]
        for row in document.xpath("//tbody/tr[contains(@class, 'dataRow')]")
    ]
    if not rows:
        return []
    if len(headers) <= 3:
        columns = "l" + "X" * (len(headers) - 1)
        tex_rows = []
        for row in [headers] + rows:
            tex_rows.append(" & ".join(latex_escape(value) for value in row) + r" \\")
        body = (
            "\\small\n\\begin{tabularx}{\\textwidth}{" + columns + "}\n"
            + tex_rows[0]
            + "\n\\hline\n"
            + "\n".join(tex_rows[1:])
            + "\n\\end{tabularx}"
        )
        return [frame(title, body)]
    result = []
    for row in rows:
        body = "\\small\n\\begin{description}\n"
        body += "\n".join(
            f"\\item[{latex_escape(key)}] {latex_escape(value)}" for key, value in zip(headers, row)
        )
        body += "\n\\end{description}"
        result.append(frame(title, body, allow_breaks=True))
    return result


def save_png_from_output(index: int, output: dict) -> Path:
    target = ASSETS / f"celula-{index:02d}.png"
    target.write_bytes(base64.b64decode(output_text(output["data"]["image/png"])))
    return target


def gif_frames(index: int) -> list[Path]:
    gif_name = "ar1.gif" if index == 22 else "matching-100x20.gif"
    source = SEMINAR / gif_name
    shutil.copy2(source, ASSETS / gif_name)
    image = Image.open(source)
    indices = sorted({0, image.n_frames // 2, image.n_frames - 1})
    paths = []
    for frame_index in indices:
        image.seek(frame_index)
        path = ASSETS / f"celula-{index:02d}-quadro-{frame_index:03d}.png"
        image.convert("RGB").save(path)
        paths.append(path)
    return paths


def build() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    OUTPUTS.mkdir(parents=True, exist_ok=True)
    cells = json.loads(NOTEBOOK.read_text())["cells"]
    title = source_text(cells[0]).lstrip("# ").strip()

    tex = [
        r"\documentclass[aspectratio=169,11pt]{beamer}",
        r"\usetheme{Madrid}",
        r"\usefonttheme{serif}",
        r"\usepackage{fontspec}",
        r"\setmainfont{Times New Roman}",
        r"\setsansfont{Arial}",
        r"\setmonofont{Menlo}",
        r"\usepackage{amsmath,amssymb,graphicx,tabularx}",
        r"\usepackage{hyperref}",
        r"\providecommand{\tightlist}{\setlength{\itemsep}{0pt}\setlength{\parskip}{0pt}}",
        r"\definecolor{SeminarRed}{HTML}{CC0100}",
        r"\setbeamercolor{normal text}{fg=black,bg=white}",
        r"\setbeamercolor{structure}{fg=SeminarRed}",
        r"\setbeamercolor{frametitle}{fg=black,bg=white}",
        r"\setbeamercolor{title}{fg=SeminarRed,bg=white}",
        r"\setbeamercolor{palette primary}{fg=white,bg=SeminarRed}",
        r"\setbeamercolor{palette secondary}{fg=white,bg=black}",
        r"\setbeamercolor{palette tertiary}{fg=white,bg=SeminarRed}",
        r"\setbeamercolor{palette quaternary}{fg=white,bg=black}",
        r"\setbeamercolor{block title}{fg=white,bg=SeminarRed}",
        r"\setbeamercolor{block body}{fg=black,bg=white}",
        r"\setbeamercolor{section in toc}{fg=black}",
        r"\setbeamercolor{itemize item}{fg=SeminarRed}",
        r"\setbeamercolor{enumerate item}{fg=SeminarRed}",
        r"\setbeamertemplate{navigation symbols}{}",
        r"\setbeamertemplate{footline}[frame number]",
        r"\setbeamercolor{page number in head/foot}{fg=black,bg=white}",
        r"\setbeamertemplate{frametitle continuation}{}",
        r"\setbeamersize{text margin left=0.7cm,text margin right=0.7cm}",
        r"\hypersetup{colorlinks=true,urlcolor=SeminarRed,linkcolor=SeminarRed}",
        r"\AtBeginSection[]{\begin{frame}[plain]\vfill\centering\LARGE\color{SeminarRed}\insertsectionhead\vfill\end{frame}}",
        f"\\title{{{latex_escape(title)}}}",
        r"\date{}",
        r"\begin{document}",
        r"\begin{frame}[plain]\vfill\centering{\Huge\bfseries\color{SeminarRed} "
        + latex_escape(title)
        + r"}\vspace{0.8cm}\par{\color{black}\rule{0.55\textwidth}{0.8pt}}\vfill\end{frame}",
    ]

    current_title = title
    for index, cell in enumerate(cells[1:], start=1):
        if cell["cell_type"] == "markdown":
            content = source_text(cell).strip()
            if not content:
                continue
            heading = re.match(r"^(#{1,3})\s+([^\n]+)(?:\n|$)", content)
            if heading:
                level, heading_text = len(heading.group(1)), heading.group(2).strip()
                if level == 2:
                    tex.append(f"\\section{{{latex_escape(heading_text)}}}")
                current_title = heading_text
                content = content[heading.end() :].strip()
                if not content:
                    continue
            active_title = current_title
            for kind, fragment in markdown_fragments(content):
                if kind == "heading":
                    active_title = fragment.strip()
                elif kind == "image":
                    source = SEMINAR / fragment
                    if not source.exists():
                        raise FileNotFoundError(source)
                    target = ASSETS / source.name
                    shutil.copy2(source, target)
                    tex.append(image_frame(active_title, target.relative_to(HERE)))
                elif fragment.strip():
                    for chunk in prose_chunks(fragment):
                        latex = markdown_to_latex(chunk)
                        tex.append(frame(active_title, "\\normalsize\n" + latex, allow_breaks=True))
        elif cell["cell_type"] == "code":
            for output_index, output in enumerate(cell.get("outputs", [])):
                data = output.get("data", {})
                if "image/png" in data:
                    image_path = save_png_from_output(index, output)
                    tex.append(image_frame(current_title, image_path.relative_to(HERE)))
                elif "text/html" in data and "data:image/gif;base64" in output_text(data["text/html"]):
                    tex.extend(
                        image_frame(current_title, path.relative_to(HERE))
                        for path in gif_frames(index)
                    )
                elif "text/html" in data and "data-frame" in output_text(data["text/html"]):
                    tex.extend(table_frames(current_title, output))
                elif "text/plain" in data:
                    plain = output_text(data["text/plain"])
                    (OUTPUTS / f"celula-{index:02d}-saida-{output_index}.txt").write_text(plain)
                elif "text" in output:
                    (OUTPUTS / f"celula-{index:02d}-stream-{output_index}.txt").write_text(
                        output_text(output["text"])
                    )

    tex.append(r"\end{document}")
    (HERE / "seminario.tex").write_text("\n\n".join(tex) + "\n")


if __name__ == "__main__":
    build()
