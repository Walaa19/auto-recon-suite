#!/bin/bash
# Final Version: Application Fingerprinting Script
# Output goes to: ~/recon/applications_<org>/

set -euo pipefail

# Interactive input
read -rp "Enter the domain to fingerprint: " DOMAIN
read -rp "Enter organization name (used for output folder): " ORG

OUTPUT_DIR="$HOME/recon/applications_$ORG"
RESOLVED="$HOME/recon/subdomain_$ORG/resolved/live.txt"
URLS="$OUTPUT_DIR/urls.txt"

mkdir -p "$OUTPUT_DIR"

echo "[*] App Fingerprinting for: $ORG ($DOMAIN)"
echo "[*] Output directory: $OUTPUT_DIR"

# Step 1: Validate and clean resolved domains
if [ ! -f "$RESOLVED" ]; then
  echo "[!] $RESOLVED not found. Please run DNS resolution first."
  exit 1
fi

echo "[*] Cleaning resolved.txt..."
grep -E '^[a-zA-Z0-9.-]+$' "$RESOLVED" | \
  grep -viE '(^|\.)ns[0-9]*\.|(^|\.)mail\.|(^|\.)mx\.' | sort -u > "$OUTPUT_DIR/resolved.cleaned"

# Step 2: Build URLs
echo "[*] Building URLs using httpx..."
if command -v httpx &>/dev/null; then
  httpx -l "$OUTPUT_DIR/resolved.cleaned" -silent -status-code | awk '/200|301|302/ {print $1}' > "$URLS"
else
  echo "[!] httpx not found. Install it via: go install github.com/projectdiscovery/httpx/cmd/httpx@latest"
  exit 1
fi

# Validate URLs
if [ ! -s "$URLS" ]; then
  echo "[!] No valid URLs found. Exiting."
  exit 1
fi

# Step 3: WhatWeb
if command -v whatweb &>/dev/null; then
  echo "[*] Running WhatWeb..."
  whatweb -i "$URLS" --color=never --log-verbose "$OUTPUT_DIR/whatweb.txt" --log-json "$OUTPUT_DIR/whatweb.json"
else
  echo "[!] WhatWeb not installed. Skipping."
fi

# Step 4: Webanalyze
if command -v webanalyze &>/dev/null; then
  echo "[*] Updating Webanalyze fingerprints..."
  webanalyze -update > /dev/null 2>&1

  echo "[*] Running Webanalyze..."
  webanalyze -hosts "$URLS" -crawl 0 -output csv > "$OUTPUT_DIR/webanalyze.csv"
else
  echo "[!] Webanalyze not installed. Skipping."
fi

# Step 5: BuiltWith links
echo "[*] Generating BuiltWith links..."
awk '{print "https://builtwith.com/" $0}' "$URLS" > "$OUTPUT_DIR/builtwith_links.txt"

# Step 6: Nmap http-enum
if command -v nmap &>/dev/null; then
  echo "[*] Running Nmap http-enum..."
  nmap -sV -Pn --script http-enum,http-title,http-server-header,http-methods \
    -p 80,443,8080,8443,8000,8888 -iL "$OUTPUT_DIR/resolved.cleaned" -oA "$OUTPUT_DIR/nmap_http"
else
  echo "[!] Nmap not installed. Skipping."
fi

# Step 7: Summary Reports
if [ -s "$OUTPUT_DIR/webanalyze.csv" ]; then
  echo "[*] Summarizing top technologies..."
  cut -d',' -f2- "$OUTPUT_DIR/webanalyze.csv" | sed 's/ *, */,/g' | tr ',' '\n' | \
    sort | uniq -c | sort -nr | head -n 20 > "$OUTPUT_DIR/summary_top_tech.txt"
fi

echo "[✓] Application fingerprinting complete for: $DOMAIN"
echo "[*] All results saved in: $OUTPUT_DIR"
