"""Convertisseur Markdown → HTML minimal pour la documentation EXO.

Supporte : titres, paragraphes, listes (ordonnées/non), code inline/blocks,
liens, images, tableaux, gras, italique, blockquotes, lignes horizontales.

Usage :
    from md_to_html import markdown_to_html
    html = markdown_to_html(texte_md)
"""
import re
from html import escape


def markdown_to_html(text: str) -> str:
    """Convertit du Markdown en HTML."""
    lines = text.split('\n')
    html_parts: list[str] = []
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]

        # ── Code blocks (```) ──────────────────────────────
        if line.strip().startswith('```'):
            lang = line.strip()[3:].strip()
            lang_attr = f' class="language-{escape(lang)}"' if lang else ''
            code_lines: list[str] = []
            i += 1
            while i < n and not lines[i].strip().startswith('```'):
                code_lines.append(escape(lines[i]))
                i += 1
            i += 1  # skip closing ```
            code = '\n'.join(code_lines)
            html_parts.append(
                f'<pre><code{lang_attr}>{code}</code></pre>'
            )
            continue

        # ── Lignes vides ───────────────────────────────────
        if line.strip() == '':
            i += 1
            continue

        # ── Commentaires HTML (<!-- ... -->) ───────────────
        if line.strip().startswith('<!--'):
            while i < n and '-->' not in lines[i]:
                i += 1
            i += 1
            continue

        # ── Ligne horizontale ──────────────────────────────
        if re.match(r'^-{3,}$|^\*{3,}$|^_{3,}$', line.strip()):
            html_parts.append('<hr>')
            i += 1
            continue

        # ── Titres (# → h6) ───────────────────────────────
        m = re.match(r'^(#{1,6})\s+(.+)', line)
        if m:
            level = len(m.group(1))
            title_text = m.group(2).strip()
            slug = _make_slug(title_text)
            html_parts.append(
                f'<h{level} id="{slug}">{_inline(title_text)}</h{level}>'
            )
            i += 1
            continue

        # ── Blockquotes ────────────────────────────────────
        if line.strip().startswith('>'):
            bq_lines: list[str] = []
            while i < n and lines[i].strip().startswith('>'):
                bq_lines.append(re.sub(r'^>\s?', '', lines[i]))
                i += 1
            bq_html = markdown_to_html('\n'.join(bq_lines))
            html_parts.append(f'<blockquote>{bq_html}</blockquote>')
            continue

        # ── Tableaux ──────────────────────────────────────
        if '|' in line and i + 1 < n and re.match(r'^\s*\|?\s*[-:]+', lines[i + 1]):
            table_lines: list[str] = []
            while i < n and '|' in lines[i]:
                table_lines.append(lines[i])
                i += 1
            html_parts.append(_parse_table(table_lines))
            continue

        # ── Listes non ordonnées ───────────────────────────
        if re.match(r'^(\s*)[*\-+]\s', line):
            list_lines: list[str] = []
            while i < n and (re.match(r'^(\s*)[*\-+]\s', lines[i]) or
                             (lines[i].strip() and lines[i].startswith('  '))):
                list_lines.append(lines[i])
                i += 1
            html_parts.append(_parse_ul(list_lines))
            continue

        # ── Listes ordonnées ───────────────────────────────
        if re.match(r'^(\s*)\d+[.)]\s', line):
            list_lines = []
            while i < n and (re.match(r'^(\s*)\d+[.)]\s', lines[i]) or
                             (lines[i].strip() and lines[i].startswith('  '))):
                list_lines.append(lines[i])
                i += 1
            html_parts.append(_parse_ol(list_lines))
            continue

        # ── Paragraphe ────────────────────────────────────
        para_lines: list[str] = []
        while i < n and lines[i].strip() and not _is_block_start(lines[i]):
            para_lines.append(lines[i])
            i += 1
        if para_lines:
            text_p = ' '.join(l.strip() for l in para_lines)
            html_parts.append(f'<p>{_inline(text_p)}</p>')

    return '\n'.join(html_parts)


# ── Inline formatting ─────────────────────────────────────────

def _inline(text: str) -> str:
    """Applique le formatage inline : gras, italique, code, liens, images."""
    # Échapper le HTML brut (mais préserver les entités déjà safe)
    text = _safe_escape(text)
    # Code inline (avant les autres pour protéger le contenu)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    # Images ![alt](src)
    text = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)',
                  r'<img src="\2" alt="\1">', text)
    # Liens [text](url)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)',
                  r'<a href="\2">\1</a>', text)
    # Gras **text** ou __text__
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'__(.+?)__', r'<strong>\1</strong>', text)
    # Italique *text* ou _text_
    text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
    text = re.sub(r'(?<!\w)_(.+?)_(?!\w)', r'<em>\1</em>', text)
    # Strikethrough ~~text~~
    text = re.sub(r'~~(.+?)~~', r'<del>\1</del>', text)
    return text


def _safe_escape(text: str) -> str:
    """Échappe le HTML tout en préservant les emojis et caractères spéciaux."""
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    return text


# ── Slug pour ancres ──────────────────────────────────────────

def _make_slug(text: str) -> str:
    """Génère un slug d'ancre compatible GitHub."""
    # Retirer le formatage markdown
    slug = re.sub(r'[*_`~]', '', text)
    # Retirer les emojis et caractères non-alphanumériques (garder lettres, chiffres, tirets, espaces)
    slug = re.sub(r'[^\w\s-]', '', slug, flags=re.UNICODE)
    slug = slug.strip().lower()
    slug = re.sub(r'[\s]+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug


# ── Parsers de blocs ──────────────────────────────────────────

def _is_block_start(line: str) -> bool:
    """Vérifie si une ligne commence un nouveau bloc."""
    if line.strip().startswith('#'):
        return True
    if line.strip().startswith('```'):
        return True
    if re.match(r'^-{3,}$|^\*{3,}$|^_{3,}$', line.strip()):
        return True
    if line.strip().startswith('>'):
        return True
    if re.match(r'^(\s*)[*\-+]\s', line):
        return True
    if re.match(r'^(\s*)\d+[.)]\s', line):
        return True
    if line.strip().startswith('<!--'):
        return True
    return False


def _parse_table(lines: list[str]) -> str:
    """Parse un tableau Markdown en HTML."""
    if len(lines) < 2:
        return ''

    def split_row(row: str) -> list[str]:
        row = row.strip()
        if row.startswith('|'):
            row = row[1:]
        if row.endswith('|'):
            row = row[:-1]
        return [c.strip() for c in row.split('|')]

    headers = split_row(lines[0])
    # Parse alignement
    aligns: list[str] = []
    for cell in split_row(lines[1]):
        cell = cell.strip()
        if cell.startswith(':') and cell.endswith(':'):
            aligns.append('center')
        elif cell.endswith(':'):
            aligns.append('right')
        else:
            aligns.append('left')

    html = '<div class="table-wrap"><table>\n<thead><tr>'
    for j, h in enumerate(headers):
        align = aligns[j] if j < len(aligns) else 'left'
        html += f'<th style="text-align:{align}">{_inline(h)}</th>'
    html += '</tr></thead>\n<tbody>\n'

    for row_line in lines[2:]:
        cells = split_row(row_line)
        html += '<tr>'
        for j, cell in enumerate(cells):
            align = aligns[j] if j < len(aligns) else 'left'
            html += f'<td style="text-align:{align}">{_inline(cell)}</td>'
        html += '</tr>\n'

    html += '</tbody></table></div>'
    return html


def _parse_ul(lines: list[str]) -> str:
    """Parse une liste non ordonnée."""
    items: list[str] = []
    for line in lines:
        m = re.match(r'^(\s*)[*\-+]\s+(.*)', line)
        if m:
            items.append(_inline(m.group(2)))
        elif line.strip():
            # Continuation de l'item précédent
            if items:
                items[-1] += ' ' + _inline(line.strip())
    return '<ul>\n' + '\n'.join(f'<li>{item}</li>' for item in items) + '\n</ul>'


def _parse_ol(lines: list[str]) -> str:
    """Parse une liste ordonnée."""
    items: list[str] = []
    for line in lines:
        m = re.match(r'^(\s*)\d+[.)]\s+(.*)', line)
        if m:
            items.append(_inline(m.group(2)))
        elif line.strip():
            if items:
                items[-1] += ' ' + _inline(line.strip())
    return '<ol>\n' + '\n'.join(f'<li>{item}</li>' for item in items) + '\n</ol>'
