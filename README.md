---
title: Diaryx Tools
author: Adam Harris
created: "2025-09-29T14:28:50-06:00"
updated: "2025-09-29T14:28:50-06:00"
visibility:
- public
- Diaryx users
format: CommonMark
reachable: diaryx-tools on Github
---

# Diaryx Tools

Tools for working with [Diaryx Writing Format](https://spec.diaryx.org) files - a structured Markdown format with YAML frontmatter designed for personal knowledge management and selective sharing.

## What's Included

- **`index.html`** - Interactive HTML viewer for Diaryx files with nested navigation support
- **`diaryx-lua-filter.lua`** - Pandoc Lua filter for rendering Diaryx metadata
- **`deploy-example.sh`** - Example deployment script for static site generation
- **`.github/workflows/deploy.yml`** - GitHub Actions workflow for automated deployment

## Features

### HTML Viewer (`index.html`)

An interactive, single-file HTML viewer that:

- ✅ Displays Diaryx metadata in order: `title`, `author`, `created`, `updated`, `visibility`, `format`, `reachable`
- ✅ Shows all additional properties after the standard ones
- ✅ Supports nested navigation via `contents` (child documents) and `part_of` (parent documents)
- ✅ Clickable links to load related Diaryx files dynamically
- ✅ **Smart link handling**: Auto-converts `.md` links to `.html` in static mode
- ✅ **Dual mode support**: Works as interactive viewer or static site
- ✅ Clean, responsive UI with proper styling
- ✅ Uses DOMPurify for XSS protection
- ✅ Markdown rendering via `marked` library
- ✅ YAML frontmatter parsing via `js-yaml`

### Lua Filter (`diaryx-lua-filter.lua`)

A Pandoc filter that:

- ✅ Renders metadata as a definition list at the top of the document
- ✅ Shows properties in the specified order first
- ✅ Then displays all remaining properties
- ✅ Converts URLs and email addresses to clickable links
- ✅ Preserves Markdown formatting in metadata values

## Quick Start

### Option 1: View Locally (Interactive Mode)

1. Edit the `MD_PATH` constant (line 115) in `index.html` to point to your Diaryx file
2. Serve via a local web server (required for fetch API):

```bash
python3 -m http.server 8000
```

3. Visit `http://localhost:8000`

In this mode:
- Loads `.md` files dynamically
- Navigation links load files via JavaScript
- No page refresh when navigating

### Option 2: Use with Pandoc

Convert a Diaryx file to HTML with metadata:

```bash
pandoc -f markdown -t html --standalone \
  --lua-filter=diaryx-lua-filter.lua \
  "Portfolio site.md" -o output.html
```

### Option 3: Static Site Generation

#### Simple Deployment (All Files)

Generate a static site from ALL Diaryx files:

```bash
./deploy-example.sh
```

This will:
1. Download or use the local HTML template
2. Process all `.md` files in `./content` directory
3. Generate corresponding HTML files in `./public`
4. Set MODE to "static" (converts `.md` links to `.html`)
5. Copy markdown and asset files
6. Create a redirect `index.html` if needed

#### Smart Deployment (Connected Files Only)

**Recommended**: Generate a static site by discovering files connected to a root document:

```bash
./deploy-smart.sh "Portfolio site.md"
```

This will:
1. Parse your root file's `contents` and `part_of` links
2. Recursively discover all connected files
3. Build HTML **only** for discovered files (ignores unconnected files)
4. Preserve directory structure
5. Copy assets from relevant directories
6. Create a redirect `index.html`

**Why use smart deployment?**
- Only builds files you actually link to
- Handles nested directory structures automatically
- Respects your site's navigation hierarchy
- Faster builds for large projects with many markdown files

See [SMART-DEPLOY.md](SMART-DEPLOY.md) for complete documentation.

**In static mode:**
- Each `.html` file fetches its corresponding `.md` file for content
- All navigation links automatically convert to `.html` references
- Works without JavaScript dynamic loading
- Perfect for hosting on static site platforms

### Option 4: Use with Pandoc (Alternative)

Convert a single Diaryx file to HTML with metadata using Pandoc:

```bash
pandoc -f markdown -t html --standalone \
  --lua-filter=diaryx-lua-filter.lua \
  "Portfolio site.md" -o output.html
```

## CI/CD Deployment

### GitHub Pages

The included GitHub Actions workflow (`.github/workflows/deploy.yml`) automatically:

1. Processes all Diaryx markdown files on push to `main`
2. Generates HTML files using the template
3. Deploys to GitHub Pages

**Setup:**

1. Copy `.github/workflows/deploy.yml` to your repository
2. Go to Settings → Pages → Source: GitHub Actions
3. Push to `main` branch
4. Your site will be live at `https://yourusername.github.io/repo-name`

### Custom Deployment

Use curl to download the template and sed to replace the filename:

```bash
# Download template
curl -o template.html https://raw.githubusercontent.com/user/repo/main/index.html

# Generate HTML for a specific file
sed 's|const MD_PATH = ".*"; // REPLACE_WITH_FILENAME|const MD_PATH = "./Portfolio site.md";|' \
  template.html > output.html

# Copy the markdown file
cp "Portfolio site.md" ./output-directory/
```

## Diaryx Format Overview

Diaryx files are Markdown files with YAML frontmatter containing structured metadata:

```markdown
---
title: "Hello! I'm Adam Harris!"
author:
  - Adam Harris
created: 2025-09-18T19:12:15-06:00
updated: 2025-09-26T11:17:00-06:00
visibility:
  - public
  - employers
format: "[CommonMark (Markdown)](https://spec.commonmark.org/0.31.2/)"
contents:
  - "[Resume](<Resume.md>)"
  - "[Projects Overview](<Projects Overview.md>)"
part_of:
  - "[Portfolio site](<Portfolio site.md>)"
reachable: "[adammharris.me](https://www.adammharris.me)"
---

# Your content here...
```

### Key Properties

#### Required (in display order)
- **`title`** - Document title
- **`author`** - Author name(s)
- **`created`** - ISO 8601 timestamp when created
- **`updated`** - ISO 8601 timestamp when last updated
- **`visibility`** - Who can view this (e.g., `public`, `private`, custom audiences)
- **`format`** - Content format (usually Markdown variant)
- **`reachable`** - Contact info or URL where author can be reached

#### Navigation
- **`contents`** - List of child documents (e.g., chapters, sub-pages)
- **`part_of`** - List of parent documents (e.g., which collections include this)

Format for navigation links:
```yaml
contents:
  - "[Chapter One](<Chapter One.md>)"
  - "[Chapter Two](<Chapter Two.md>)"
```

Note: Use angle brackets in links to avoid URL encoding spaces.

#### Additional Optional Properties
- `version` - Document version
- `copying` - License or copyright information
- `tags` - Categorization tags
- `aliases` - Alternative names
- `checksums` - File integrity hashes
- `language` - Content language code
- And many more... see [Diaryx Specification](https://spec.diaryx.org)

## Examples

See the included example files:
- **`Portfolio site.md`** - Root index with `contents` links
- **`Resume.md`** - Child document with `part_of` link
- **`Projects Overview.md`** - Another child document

## How It Works

### Dual Mode System

The HTML viewer supports two modes:

**Interactive Mode** (default for local viewing):
- Loads `.md` files dynamically via fetch
- Navigation links trigger JavaScript file loading
- No page refresh when clicking links
- Set with `const MODE = "auto"` or `"interactive"`

**Static Mode** (for deployed sites):
- Each HTML file loads its own `.md` file for content
- All `.md` links automatically converted to `.html`
- Standard browser navigation (page refresh on clicks)
- Set with `const MODE = "static"`
- Deployment scripts automatically enable this mode

### Interactive Navigation

1. The HTML viewer parses YAML frontmatter to extract metadata
2. It displays `contents` as "↓ Contents:" with clickable links
3. It displays `part_of` as "↑ Part of:" with clickable links
4. In interactive mode: clicking loads the file via fetch
5. In static mode: clicking navigates to the `.html` page
6. All relative paths are resolved correctly

### Property Display Order

1. First: The 7 standard properties in order
2. Then: All other properties in the order they appear in the YAML
3. Navigation properties (`contents`, `part_of`) are shown separately in navigation boxes

### CI/CD Flow

```
[Push to repo]
     ↓
[GitHub Actions triggers]
     ↓
[Download HTML template]
     ↓
[For each .md file:]
  - Replace MD_PATH → points to .md file
  - Replace MODE → set to "static"
  - Save as .html file
  - Copy .md file alongside (for content)
     ↓
[Copy all assets]
     ↓
[Deploy to GitHub Pages]
     ↓
[Static site with .html links]
```

**Why both .md and .html files?**
- `.html` files: Entry points (what users visit)
- `.md` files: Content source (fetched by HTML files)
- Links in navigation: Automatically point to `.html` files

### Smart Deployment with Discovery

For sites with many files, use the smart deployment script:

```
User specifies root file
     ↓
[Parse root YAML frontmatter]
     ↓
[Extract contents/part_of links]
     ↓
[Recursively discover connected files]
     ↓
[Build dependency graph]
     ↓
[Generate HTML for discovered files only]
     ↓
[Copy relevant assets]
     ↓
[Static site with only connected files]
```

**Benefits:**
- Only builds files you actually use
- Automatically handles nested structures
- Ignores drafts and unlinked files
- Faster builds for large projects

See [SMART-DEPLOY.md](SMART-DEPLOY.md) for details.

## Browser Compatibility

Works in all modern browsers that support:
- ES6 modules
- Fetch API
- Template literals
- Async/await

Tested on:
- Chrome/Edge 90+
- Firefox 88+
- Safari 14+

## Security

- Uses DOMPurify to sanitize all HTML output
- Prevents XSS attacks through content injection
- Safe to use with untrusted markdown content

## License

This tooling is provided as examples for working with the Diaryx Writing Format. Modify as needed for your use case.

## Learn More

- [Diaryx Writing Specification](https://spec.diaryx.org)
- [Diaryx CLI](https://github.com/adammharris/diaryx-cli)
- [Diaryx App](https://app.diaryx.org)

## Contributing

Found a bug or have a feature request? Feel free to:
1. Open an issue
2. Submit a pull request
3. Reach out at adam@diaryx.org

---

Made with ❤️ for the Diaryx community
