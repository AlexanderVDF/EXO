"""Générateur de site statique pour la documentation EXO.

Scanne docs/, convertit .md → .html, génère la navigation latérale,
l'index principal et un sitemap.

Usage :
    python scripts/build_docs_site.py            # build complet
    python scripts/build_docs_site.py --clean     # nettoyer puis rebuild
"""
import shutil
import sys
from datetime import datetime
from pathlib import Path

# Ajouter scripts/ au path pour importer md_to_html
sys.path.insert(0, str(Path(__file__).resolve().parent))
from md_to_html import markdown_to_html

# ── Chemins ─────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = ROOT / 'docs'
SITE_DIR = ROOT / 'docs_site'

# ── Catégories et métadonnées ───────────────────────────────
CATEGORIES = {
    'core': {'label': '🏗 Architecture & Spécifications', 'order': 1},
    'guides': {'label': '📖 Guides Techniques', 'order': 2},
    'ui': {'label': '🎨 Interface & Design', 'order': 3},
    'audits': {'label': '🔍 Audits', 'order': 4},
    'reports': {'label': '📊 Rapports Techniques', 'order': 5},
    'prompts': {'label': '💬 Prompts Historiques', 'order': 6},
    'archives': {'label': '📦 Archives', 'order': 7},
}

BUILD_DATE = datetime.now().strftime('%d %B %Y')

# ── CSS ─────────────────────────────────────────────────────

CSS = """\
:root {
  --bg-primary: #1e1e2e;
  --bg-secondary: #181825;
  --bg-surface: #252536;
  --bg-hover: #2a2a3d;
  --text-primary: #cdd6f4;
  --text-secondary: #a6adc8;
  --text-muted: #6c7086;
  --accent: #89b4fa;
  --accent-hover: #74c7ec;
  --accent-dim: #313244;
  --border: #45475a;
  --success: #a6e3a1;
  --warning: #f9e2af;
  --error: #f38ba8;
  --code-bg: #11111b;
  --sidebar-width: 280px;
  --header-height: 56px;
}

* { margin: 0; padding: 0; box-sizing: border-box; }

html { scroll-behavior: smooth; }

body {
  font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
  background: var(--bg-primary);
  color: var(--text-primary);
  line-height: 1.7;
  display: flex;
  min-height: 100vh;
}

/* ── Header ──────────────────────────────────────────── */
header {
  position: fixed;
  top: 0; left: 0; right: 0;
  height: var(--header-height);
  background: var(--bg-secondary);
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  padding: 0 24px;
  z-index: 100;
  gap: 16px;
}

header .logo {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--accent);
  text-decoration: none;
  white-space: nowrap;
}

header .version {
  font-size: 0.8rem;
  color: var(--text-muted);
  background: var(--accent-dim);
  padding: 2px 8px;
  border-radius: 4px;
}

header .search-box {
  margin-left: auto;
  position: relative;
}

header .search-box input {
  background: var(--bg-surface);
  border: 1px solid var(--border);
  color: var(--text-primary);
  padding: 6px 12px 6px 32px;
  border-radius: 6px;
  font-size: 0.85rem;
  width: 240px;
  outline: none;
}

header .search-box input:focus {
  border-color: var(--accent);
}

header .search-box::before {
  content: '🔍';
  position: absolute;
  left: 8px; top: 50%;
  transform: translateY(-50%);
  font-size: 0.8rem;
}

#menu-toggle {
  display: none;
  background: none;
  border: none;
  color: var(--text-primary);
  font-size: 1.5rem;
  cursor: pointer;
}

/* ── Sidebar ─────────────────────────────────────────── */
.sidebar {
  position: fixed;
  top: var(--header-height);
  left: 0;
  width: var(--sidebar-width);
  height: calc(100vh - var(--header-height));
  background: var(--bg-secondary);
  border-right: 1px solid var(--border);
  overflow-y: auto;
  padding: 16px 0;
  z-index: 50;
}

.sidebar::-webkit-scrollbar { width: 4px; }
.sidebar::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }

.sidebar .nav-section {
  padding: 0 16px;
  margin-bottom: 4px;
}

.sidebar .nav-section-title {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  padding: 12px 0 4px;
  cursor: pointer;
  user-select: none;
  display: flex;
  align-items: center;
  gap: 6px;
}

.sidebar .nav-section-title .arrow {
  transition: transform 0.2s;
  font-size: 0.6rem;
}

.sidebar .nav-section-title.collapsed .arrow {
  transform: rotate(-90deg);
}

.sidebar .nav-links {
  list-style: none;
  overflow: hidden;
  transition: max-height 0.3s ease;
}

.sidebar .nav-links.collapsed { max-height: 0 !important; }

.sidebar .nav-links a {
  display: block;
  padding: 4px 8px 4px 12px;
  color: var(--text-secondary);
  text-decoration: none;
  font-size: 0.82rem;
  border-radius: 4px;
  border-left: 2px solid transparent;
  transition: all 0.15s;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sidebar .nav-links a:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.sidebar .nav-links a.active {
  background: var(--accent-dim);
  color: var(--accent);
  border-left-color: var(--accent);
  font-weight: 500;
}

/* ── Main content ────────────────────────────────────── */
.content {
  margin-left: var(--sidebar-width);
  margin-top: var(--header-height);
  flex: 1;
  padding: 32px 48px;
  max-width: 960px;
  min-height: calc(100vh - var(--header-height));
}

.content h1 {
  font-size: 2rem;
  font-weight: 700;
  margin-bottom: 8px;
  color: var(--text-primary);
  border-bottom: 2px solid var(--accent-dim);
  padding-bottom: 12px;
}

.content h2 {
  font-size: 1.45rem;
  font-weight: 600;
  margin-top: 2rem;
  margin-bottom: 8px;
  color: var(--text-primary);
  padding-bottom: 4px;
  border-bottom: 1px solid var(--border);
}

.content h3 {
  font-size: 1.15rem;
  font-weight: 600;
  margin-top: 1.5rem;
  margin-bottom: 6px;
  color: var(--accent);
}

.content p { margin-bottom: 1rem; }

.content a {
  color: var(--accent);
  text-decoration: none;
  border-bottom: 1px solid transparent;
  transition: border-color 0.15s;
}

.content a:hover { border-bottom-color: var(--accent); }

.content code {
  background: var(--code-bg);
  padding: 2px 6px;
  border-radius: 4px;
  font-family: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
  font-size: 0.88em;
  color: var(--accent-hover);
}

.content pre {
  background: var(--code-bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 16px;
  overflow-x: auto;
  margin: 1rem 0;
  line-height: 1.5;
}

.content pre code {
  background: none;
  padding: 0;
  color: var(--text-primary);
  font-size: 0.85rem;
}

.content blockquote {
  border-left: 3px solid var(--accent);
  background: var(--bg-surface);
  padding: 12px 16px;
  margin: 1rem 0;
  border-radius: 0 6px 6px 0;
  color: var(--text-secondary);
}

.content blockquote p { margin-bottom: 0.3rem; }

.content ul, .content ol {
  margin: 0.5rem 0 1rem 1.5rem;
}

.content li { margin-bottom: 4px; }

.content hr {
  border: none;
  border-top: 1px solid var(--border);
  margin: 2rem 0;
}

.content img { max-width: 100%; border-radius: 6px; }

.content strong { color: var(--text-primary); font-weight: 600; }
.content em { color: var(--text-secondary); }
.content del { color: var(--text-muted); }

/* ── Tables ──────────────────────────────────────────── */
.table-wrap {
  overflow-x: auto;
  margin: 1rem 0;
}

.content table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.88rem;
}

.content th, .content td {
  border: 1px solid var(--border);
  padding: 8px 12px;
  text-align: left;
}

.content th {
  background: var(--bg-surface);
  font-weight: 600;
  color: var(--accent);
  font-size: 0.82rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.content tr:hover td {
  background: var(--bg-hover);
}

/* ── Footer ──────────────────────────────────────────── */
.page-footer {
  margin-top: 3rem;
  padding-top: 1rem;
  border-top: 1px solid var(--border);
  color: var(--text-muted);
  font-size: 0.8rem;
}

/* ── Breadcrumb ──────────────────────────────────────── */
.breadcrumb {
  font-size: 0.82rem;
  color: var(--text-muted);
  margin-bottom: 16px;
}

.breadcrumb a { color: var(--text-secondary); }
.breadcrumb a:hover { color: var(--accent); }
.breadcrumb .sep { margin: 0 6px; }

/* ── Search results ──────────────────────────────────── */
#search-results {
  position: fixed;
  top: var(--header-height);
  right: 24px;
  width: 360px;
  max-height: 400px;
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow-y: auto;
  display: none;
  z-index: 200;
  box-shadow: 0 8px 32px rgba(0,0,0,0.4);
}

#search-results a {
  display: block;
  padding: 8px 16px;
  color: var(--text-secondary);
  text-decoration: none;
  border-bottom: 1px solid var(--border);
  font-size: 0.85rem;
}

#search-results a:hover {
  background: var(--bg-hover);
  color: var(--accent);
}

#search-results .cat {
  font-size: 0.7rem;
  color: var(--text-muted);
  text-transform: uppercase;
}

/* ── Index cards ─────────────────────────────────────── */
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
  margin: 1.5rem 0;
}

.card {
  background: var(--bg-surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 20px;
  transition: all 0.2s;
}

.card:hover {
  border-color: var(--accent);
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0,0,0,0.3);
}

.card h3 {
  margin-top: 0;
  margin-bottom: 8px;
  font-size: 1rem;
}

.card .count {
  font-size: 0.78rem;
  color: var(--text-muted);
}

.card ul {
  list-style: none;
  margin: 8px 0 0 0;
  padding: 0;
}

.card ul li {
  margin: 2px 0;
}

.card ul a {
  font-size: 0.82rem;
  color: var(--text-secondary);
}

.card ul a:hover { color: var(--accent); }

/* ── Responsive ──────────────────────────────────────── */
@media (max-width: 768px) {
  .sidebar { transform: translateX(-100%); transition: transform 0.3s; }
  .sidebar.open { transform: translateX(0); }
  .content { margin-left: 0; padding: 24px 16px; }
  #menu-toggle { display: block; }
  header .search-box input { width: 140px; }
}
"""


# ── Fonctions utilitaires ────────────────────────────────────

def _pretty_name(filename: str) -> str:
    """Génère un nom lisible depuis un nom de fichier .md."""
    name = filename.replace('.md', '').replace('.html', '')
    name = name.replace('_', ' ').replace('-', ' ')
    # Capitalize chaque mot sauf les articles
    words = name.split()
    return ' '.join(w.capitalize() if len(w) > 2 else w for w in words)


def _read_title(md_path: Path) -> str:
    """Extrait le titre H1 d'un fichier markdown."""
    try:
        for line in md_path.read_text(encoding='utf-8').splitlines()[:20]:
            m = __import__('re').match(r'^#\s+(.+)', line)
            if m:
                # Retirer emojis au début
                title = __import__('re').sub(r'^[\U0001F000-\U0001FFFF\u2600-\u27BF\u2B50\U0001FA00-\U0001FA6F\U0001FA70-\U0001FAFF]+\s*', '', m.group(1))
                return title.strip()
    except Exception:
        pass
    return _pretty_name(md_path.name)


def _build_nav(file_tree: dict) -> str:
    """Génère la navigation latérale HTML."""
    nav_html = ''

    # Fichiers racine
    root_files = file_tree.get('_root', [])
    if root_files:
        nav_html += '<div class="nav-section">\n'
        nav_html += '<div class="nav-section-title" onclick="toggleNav(this)">'
        nav_html += '<span class="arrow">▼</span> Documentation</div>\n'
        nav_html += '<ul class="nav-links">\n'
        for f in root_files:
            nav_html += f'<li><a href="{f["href"]}">{f["label"]}</a></li>\n'
        nav_html += '</ul></div>\n'

    # Catégories
    sorted_cats = sorted(
        [(k, v) for k, v in CATEGORIES.items() if k in file_tree],
        key=lambda x: x[1]['order']
    )
    for cat_key, cat_meta in sorted_cats:
        files = file_tree[cat_key]
        nav_html += '<div class="nav-section">\n'
        nav_html += f'<div class="nav-section-title" onclick="toggleNav(this)">'
        nav_html += f'<span class="arrow">▼</span> {cat_meta["label"]}</div>\n'
        nav_html += '<ul class="nav-links">\n'
        for f in files:
            nav_html += f'<li><a href="{f["href"]}">{f["label"]}</a></li>\n'
        nav_html += '</ul></div>\n'

    return nav_html


def _page_html(title: str, body: str, nav: str, breadcrumb: str,
               search_data: str, css_path: str = 'style.css') -> str:
    """Enveloppe le contenu dans le template HTML complet."""
    return f'''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title} — EXO Docs</title>
  <link rel="stylesheet" href="{css_path}">
</head>
<body>

<header>
  <button id="menu-toggle" onclick="document.querySelector('.sidebar').classList.toggle('open')">☰</button>
  <a href="{css_path.replace('style.css','index.html')}" class="logo">EXO Docs</a>
  <span class="version">v4.2</span>
  <div class="search-box">
    <input type="text" id="search-input" placeholder="Rechercher..." autocomplete="off">
  </div>
</header>

<div id="search-results"></div>

<nav class="sidebar">
{nav}
</nav>

<main class="content">
  <div class="breadcrumb">{breadcrumb}</div>
{body}
  <div class="page-footer">
    EXO Documentation v4.2 · Généré le {BUILD_DATE}
  </div>
</main>

<script>
const SEARCH_DATA = {search_data};

function toggleNav(el) {{
  el.classList.toggle('collapsed');
  el.nextElementSibling.classList.toggle('collapsed');
}}

const searchInput = document.getElementById('search-input');
const searchResults = document.getElementById('search-results');

searchInput.addEventListener('input', function() {{
  const q = this.value.toLowerCase().trim();
  if (q.length < 2) {{ searchResults.style.display = 'none'; return; }}
  const matches = SEARCH_DATA.filter(d =>
    d.title.toLowerCase().includes(q) || d.cat.toLowerCase().includes(q)
  ).slice(0, 12);
  if (!matches.length) {{ searchResults.style.display = 'none'; return; }}
  searchResults.innerHTML = matches.map(m =>
    '<a href="' + m.href + '"><span class="cat">' + m.cat + '</span><br>' + m.title + '</a>'
  ).join('');
  searchResults.style.display = 'block';
}});

document.addEventListener('click', function(e) {{
  if (!searchResults.contains(e.target) && e.target !== searchInput) {{
    searchResults.style.display = 'none';
  }}
}});

// Highlight active link
const current = location.pathname.split('/').pop();
document.querySelectorAll('.nav-links a').forEach(a => {{
  if (a.getAttribute('href') === current ||
      a.getAttribute('href').endsWith('/' + current)) {{
    a.classList.add('active');
  }}
}});
</script>

</body>
</html>'''


# ── Build principal ──────────────────────────────────────────

def build():
    """Point d'entrée : génère le site statique complet."""
    clean = '--clean' in sys.argv
    if clean and SITE_DIR.exists():
        shutil.rmtree(SITE_DIR)
        print(f'🗑  {SITE_DIR} nettoyé')

    SITE_DIR.mkdir(exist_ok=True)

    # Écrire le CSS
    (SITE_DIR / 'style.css').write_text(CSS, encoding='utf-8')

    # Scanner les fichiers .md
    file_tree: dict[str, list] = {'_root': []}
    all_pages: list[dict] = []

    for md_path in sorted(DOCS_DIR.rglob('*.md')):
        rel = md_path.relative_to(DOCS_DIR)
        parts = rel.parts

        # Ignorer les sous-dossiers profonds d'archives (diagnostic_scripts, legacy_gpu, etc.)
        if len(parts) > 2:
            continue
        # Ignorer les fichiers .bak
        if md_path.suffix != '.md':
            continue
        if '.bak' in md_path.name:
            continue

        title = _read_title(md_path)
        html_name = rel.with_suffix('.html').as_posix()

        page_info = {
            'md_path': md_path,
            'rel': rel,
            'html_name': html_name,
            'title': title,
            'label': _pretty_name(md_path.stem),
            'category': parts[0] if len(parts) > 1 else '_root',
        }

        all_pages.append(page_info)

        cat = page_info['category']
        if cat == '_root':
            file_tree.setdefault('_root', []).append({
                'href': html_name, 'label': page_info['label']
            })
        else:
            file_tree.setdefault(cat, []).append({
                'href': html_name, 'label': page_info['label']
            })

    # Données de recherche
    search_data = __import__('json').dumps([
        {'title': p['title'], 'href': p['html_name'],
         'cat': CATEGORIES.get(p['category'], {}).get('label', 'Documentation')}
        for p in all_pages
    ], ensure_ascii=False)

    nav_html = _build_nav(file_tree)
    total = 0

    # ── Convertir chaque page .md ──────
    for page in all_pages:
        md_content = page['md_path'].read_text(encoding='utf-8')
        body_html = markdown_to_html(md_content)

        # Réécrire les liens .md → .html
        body_html = __import__('re').sub(
            r'href="([^"]*?)\.md(#[^"]*?)?"',
            lambda m: f'href="{m.group(1)}.html{m.group(2) or ""}"',
            body_html
        )
        # Corriger les liens relatifs (../README.md → ../README.html etc.)
        body_html = body_html.replace('../README.html', 'README.html')
        # Pour les fichiers dans des sous-dossiers, les liens relatifs vers d'autres sous-dossiers
        # sont déjà corrects (ex: ../core/architecture.html)

        # Breadcrumb
        if page['category'] == '_root':
            bc = '<a href="index.html">Accueil</a><span class="sep">›</span>' + page['title']
        else:
            cat_label = CATEGORIES.get(page['category'], {}).get('label', page['category'])
            bc = (f'<a href="index.html">Accueil</a><span class="sep">›</span>'
                  f'<a href="index.html#{page["category"]}">{cat_label}</a>'
                  f'<span class="sep">›</span>{page["title"]}')

        # CSS path relatif
        css_path = 'style.css'
        index_path = 'index.html'
        if '/' in page['html_name']:
            depth = page['html_name'].count('/')
            css_path = '../' * depth + 'style.css'
            index_path = '../' * depth + 'index.html'

        # Ajuster les chemins dans le nav pour les pages en sous-dossier
        adjusted_nav = nav_html
        if '/' in page['html_name']:
            depth = page['html_name'].count('/')
            prefix = '../' * depth
            adjusted_nav = adjusted_nav.replace('href="', f'href="{prefix}')
            # Ne pas doubler le prefix sur les liens déjà absolus
            adjusted_nav = adjusted_nav.replace(f'{prefix}http', 'http')

        full_html = _page_html(
            title=page['title'],
            body=body_html,
            nav=adjusted_nav,
            breadcrumb=bc,
            search_data=search_data,
            css_path=css_path,
        )

        out_path = SITE_DIR / page['html_name']
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(full_html, encoding='utf-8')
        total += 1

    # ── Générer index.html ─────────────────
    index_body = _build_index_body(file_tree, all_pages)
    index_html = _page_html(
        title='EXO Assistant v4.2 — Documentation',
        body=index_body,
        nav=nav_html,
        breadcrumb='<strong>Accueil</strong>',
        search_data=search_data,
    )
    (SITE_DIR / 'index.html').write_text(index_html, encoding='utf-8')

    # ── Générer sitemap.xml ────────────────
    _build_sitemap(all_pages)

    print(f'\n{"="*60}')
    print(f'  ✅ Site généré dans {SITE_DIR.relative_to(ROOT)}/')
    print(f'{"="*60}')
    print(f'  Pages HTML     : {total}')
    print(f'  Index          : index.html')
    print(f'  Sitemap        : sitemap.xml')
    print(f'  Catégories     : {len([k for k in file_tree if k != "_root"])}')
    print(f'  CSS            : style.css')
    print(f'{"="*60}')


def _build_index_body(file_tree: dict, all_pages: list) -> str:
    """Génère le corps HTML de la page d'accueil."""
    html = '<h1>📘 EXO Assistant v4.2 — Documentation</h1>\n'
    html += '<p>Documentation technique complète de l\'assistant vocal EXO. '
    html += f'{len(all_pages)} documents · {len(CATEGORIES)} catégories.</p>\n'

    # Documents essentiels
    html += '<h2>⭐ Documents essentiels</h2>\n'
    essentials = [
        ('core/EXO_SPEC.html', 'EXO_SPEC', 'Source de vérité — spécification officielle v4.2'),
        ('core/architecture.html', 'Architecture', 'Vue d\'ensemble C++ + 7 microservices Python'),
        ('core/EXO_DOCUMENTATION.html', 'Documentation Complète', 'Référence technique exhaustive'),
        ('guides/audio_pipeline.html', 'Pipeline Audio', 'Capture → VAD → STT → LLM → TTS → lecture'),
        ('ui/design_system.html', 'Design System', 'VS Code + Fluent Design + Copilot'),
    ]
    html += '<div class="cards">\n'
    for href, title, desc in essentials:
        html += f'''<a class="card" href="{href}" style="text-decoration:none;color:inherit">
  <h3>{title}</h3>
  <p style="font-size:0.85rem;color:var(--text-secondary)">{desc}</p>
</a>\n'''
    html += '</div>\n'

    # Catégories
    sorted_cats = sorted(
        [(k, v) for k, v in CATEGORIES.items() if k in file_tree],
        key=lambda x: x[1]['order']
    )

    html += '<h2>📂 Catégories</h2>\n'
    html += '<div class="cards">\n'
    for cat_key, cat_meta in sorted_cats:
        files = file_tree[cat_key]
        html += f'<div class="card" id="{cat_key}">\n'
        html += f'  <h3>{cat_meta["label"]}</h3>\n'
        html += f'  <span class="count">{len(files)} document{"s" if len(files) > 1 else ""}</span>\n'
        html += '  <ul>\n'
        for f in files:
            html += f'    <li><a href="{f["href"]}">{f["label"]}</a></li>\n'
        html += '  </ul>\n'
        html += '</div>\n'
    html += '</div>\n'

    return html


def _build_sitemap(all_pages: list):
    """Génère un sitemap.xml basique."""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    lines.append('  <url><loc>index.html</loc></url>')
    for p in all_pages:
        lines.append(f'  <url><loc>{p["html_name"]}</loc></url>')
    lines.append('</urlset>')
    (SITE_DIR / 'sitemap.xml').write_text('\n'.join(lines), encoding='utf-8')


if __name__ == '__main__':
    build()
