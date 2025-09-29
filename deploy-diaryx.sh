#!/bin/bash

# Smart Diaryx Static Site Generator
# Automatically discovers and builds all files connected to a root document
# via 'contents' and 'part_of' properties

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
TEMPLATE_URL=""  # Leave empty to use local index.html
OUTPUT_DIR="./public"
TEMPLATE_FILE="./template.html"

# Usage information
usage() {
    echo "Usage: $0 <root-markdown-file> [source-directory]"
    echo ""
    echo "Arguments:"
    echo "  root-markdown-file   The root/index markdown file (e.g., 'Portfolio site.md')"
    echo "  source-directory     Optional: Directory containing markdown files (default: current directory)"
    echo ""
    echo "Example:"
    echo "  $0 'Portfolio site.md'"
    echo "  $0 'Portfolio site.md' ./content"
    echo ""
    echo "The script will:"
    echo "  1. Parse the root file's 'contents' and 'part_of' links"
    echo "  2. Recursively discover all connected files"
    echo "  3. Build HTML only for discovered files"
    echo "  4. Copy all necessary assets"
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

ROOT_FILE="$1"
SOURCE_DIR="${2:-.}"

# Validate root file exists
if [ ! -f "$SOURCE_DIR/$ROOT_FILE" ]; then
    echo -e "${RED}Error: Root file not found: $SOURCE_DIR/$ROOT_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}=== Smart Diaryx Static Site Generator ===${NC}"
echo -e "Root file: ${YELLOW}$ROOT_FILE${NC}"
echo -e "Source directory: ${YELLOW}$SOURCE_DIR${NC}"
echo ""

# Create Python script to discover connected files
cat > /tmp/discover_files.py << 'PYPYTHON'
#!/usr/bin/env python3
import sys
import os
import re
import yaml

def extract_frontmatter(filepath):
    """Extract YAML frontmatter from a markdown file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check if file starts with ---
        if not content.startswith('---\n'):
            return {}

        # Find the end of frontmatter
        rest = content[4:]
        end_match = re.search(r'\n(?:---|\.\.\.)\s*\r?\n', rest)
        if not end_match:
            return {}

        frontmatter_text = rest[:end_match.start() + 1]

        try:
            return yaml.safe_load(frontmatter_text) or {}
        except yaml.YAMLError as e:
            print(f"Warning: YAML parse error in {filepath}: {e}", file=sys.stderr)
            return {}
    except Exception as e:
        print(f"Warning: Could not read {filepath}: {e}", file=sys.stderr)
        return {}

def extract_links_from_value(value):
    """Extract markdown links from a value (string or list)."""
    links = []

    if isinstance(value, str):
        # Match [text](url) or [text](<url>)
        matches = re.findall(r'\[([^\]]*)\]\(<?([^)>]+)>?\)', value)
        for text, url in matches:
            # Strip angle brackets if present
            url = re.sub(r'^<(.+)>$', r'\1', url)
            # Only include .md files
            if url.endswith('.md'):
                links.append(url)
    elif isinstance(value, list):
        for item in value:
            links.extend(extract_links_from_value(item))

    return links

def get_connected_files(root_file, source_dir):
    """Discover all files connected to the root file via contents/part_of links."""
    discovered = set()
    to_process = [root_file]
    processed = set()

    while to_process:
        current_file = to_process.pop(0)

        # Skip if already processed
        if current_file in processed:
            continue

        processed.add(current_file)
        discovered.add(current_file)

        # Get full path
        current_path = os.path.join(source_dir, current_file)

        if not os.path.exists(current_path):
            print(f"Warning: File not found: {current_path}", file=sys.stderr)
            continue

        # Extract frontmatter
        meta = extract_frontmatter(current_path)

        # Extract links from 'contents' property
        if 'contents' in meta:
            links = extract_links_from_value(meta['contents'])
            for link in links:
                # Resolve relative path
                current_dir = os.path.dirname(current_file)
                if current_dir:
                    resolved_link = os.path.normpath(os.path.join(current_dir, link))
                else:
                    resolved_link = link

                if resolved_link not in processed:
                    to_process.append(resolved_link)

        # Extract links from 'part_of' property
        if 'part_of' in meta:
            links = extract_links_from_value(meta['part_of'])
            for link in links:
                # Resolve relative path
                current_dir = os.path.dirname(current_file)
                if current_dir:
                    resolved_link = os.path.normpath(os.path.join(current_dir, link))
                else:
                    resolved_link = link

                if resolved_link not in processed:
                    to_process.append(resolved_link)

    return sorted(discovered)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: discover_files.py <root_file> <source_dir>", file=sys.stderr)
        sys.exit(1)

    root_file = sys.argv[1]
    source_dir = sys.argv[2]

    files = get_connected_files(root_file, source_dir)

    # Output one file per line
    for f in files:
        print(f)
PYPYTHON

chmod +x /tmp/discover_files.py

# Check if Python 3 and PyYAML are available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is required but not installed.${NC}"
    exit 1
fi

if ! python3 -c "import yaml" 2> /dev/null; then
    echo -e "${YELLOW}Warning: PyYAML not installed. Attempting to install...${NC}"
    pip3 install pyyaml --quiet 2>&1 || {
        echo -e "${RED}Error: Could not install PyYAML. Please install manually:${NC}"
        echo "  pip3 install pyyaml"
        exit 1
    }
fi

# Discover connected files
echo -e "${BLUE}Discovering connected files...${NC}"
DISCOVERED_FILES=$(python3 /tmp/discover_files.py "$ROOT_FILE" "$SOURCE_DIR" 2>&1)

# Check if discovery was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}Error during file discovery:${NC}"
    echo "$DISCOVERED_FILES"
    exit 1
fi

# Count discovered files
FILE_COUNT=$(echo "$DISCOVERED_FILES" | wc -l | tr -d ' ')
echo -e "${GREEN}✓${NC} Discovered $FILE_COUNT connected file(s)"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Download or copy template
if [ -n "$TEMPLATE_URL" ]; then
    echo "Downloading template from $TEMPLATE_URL..."
    curl -s "$TEMPLATE_URL" -o "$TEMPLATE_FILE"
else
    echo "Using local index.html as template"
    cp index.html "$TEMPLATE_FILE"
fi

# Process each discovered file
echo -e "${BLUE}Processing markdown files...${NC}"

while IFS= read -r mdfile; do
    # Skip empty lines
    [ -z "$mdfile" ] && continue

    # Get relative path and create directory structure
    relpath="$mdfile"
    htmlfile="$OUTPUT_DIR/${relpath%.md}.html"

    # Create directory structure
    mkdir -p "$(dirname "$htmlfile")"

    # Get the filename for template replacement
    filename="$(basename "$mdfile")"

    echo -e "${GREEN}✓${NC} Generating: $relpath -> ${htmlfile#$OUTPUT_DIR/}"

    # Replace the filename and mode in template and save to output
    sed -e "s|const MD_PATH = \".*\"; // REPLACE_WITH_FILENAME|const MD_PATH = \"./$filename\"; // $filename|" \
        -e "s|const MODE = \".*\"; // REPLACE_WITH_MODE|const MODE = \"static\"; // static mode|" \
        "$TEMPLATE_FILE" > "$htmlfile"

    # Copy the markdown file next to the HTML file
    cp "$SOURCE_DIR/$mdfile" "$(dirname "$htmlfile")/"
done <<< "$DISCOVERED_FILES"

# Copy assets from source directory
if [ -d "$SOURCE_DIR" ]; then
    echo -e "${BLUE}Copying assets...${NC}"

    # Find all non-markdown files in directories containing discovered markdown files
    while IFS= read -r mdfile; do
        [ -z "$mdfile" ] && continue

        # Get the directory of this markdown file
        mddir=$(dirname "$mdfile")
        if [ "$mddir" = "." ]; then
            mddir=""
        fi

        # Copy all assets from that directory
        if [ -n "$mddir" ]; then
            source_asset_dir="$SOURCE_DIR/$mddir"
            output_asset_dir="$OUTPUT_DIR/$mddir"
        else
            source_asset_dir="$SOURCE_DIR"
            output_asset_dir="$OUTPUT_DIR"
        fi

        # Copy image and other asset files
        if [ -d "$source_asset_dir" ]; then
            for ext in png jpg jpeg gif svg ico css js woff woff2 ttf eot; do
                find "$source_asset_dir" -maxdepth 1 -type f -iname "*.$ext" 2>/dev/null | while read -r asset; do
                    if [ -f "$asset" ]; then
                        cp "$asset" "$output_asset_dir/" 2>/dev/null || true
                        echo -e "${GREEN}✓${NC} Copied: $(basename "$asset")"
                    fi
                done
            done
        fi
    done <<< "$DISCOVERED_FILES"
fi

# Clean up template file
rm -f "$TEMPLATE_FILE"
rm -f /tmp/discover_files.py

# Create index redirect to root file if needed
ROOT_HTML="$OUTPUT_DIR/${ROOT_FILE%.md}.html"
if [ -f "$ROOT_HTML" ] && [ ! -f "$OUTPUT_DIR/index.html" ]; then
    echo -e "${BLUE}Creating redirect index...${NC}"
    ROOT_HTML_RELATIVE="${ROOT_FILE%.md}.html"

    # URL encode spaces
    ROOT_HTML_ENCODED=$(echo "$ROOT_HTML_RELATIVE" | sed 's/ /%20/g')

    cat > "$OUTPUT_DIR/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=./$ROOT_HTML_ENCODED">
    <title>Redirecting...</title>
</head>
<body>
    <p>Redirecting to <a href="./$ROOT_HTML_ENCODED">$(basename "${ROOT_FILE%.md}")</a>...</p>
</body>
</html>
EOF
    echo -e "${GREEN}✓${NC} Created redirect index.html"
fi

echo ""
echo -e "${GREEN}=== Build complete! ===${NC}"
echo "Output directory: $OUTPUT_DIR"
echo "Files generated: $FILE_COUNT"
echo ""
echo "To test locally, run:"
echo "  cd $OUTPUT_DIR && python3 -m http.server 8000"
echo "  Then visit: http://localhost:8000"
