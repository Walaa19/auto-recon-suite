#!/bin/bash

# === User Input ===
read -p "Enter domain (e.g., example.com): " domain
read -p "Enter organization name (no spaces): " org_name

# === Configuration ===
baseDir="$HOME/recon"
outputDir="${baseDir}/emails_${org_name}"
mkdir -p "$outputDir"

hunter_api_key=""

echo ""
echo "[*] Starting email recon for $domain"
echo "[*] Output will be saved to: $outputDir"
echo "========================================"

# === theHarvester ===
echo "[*] Running theHarvester..."
theHarvester -d "$domain" -b google,bing,linkedin,github -f "$outputDir/harvester" -f xml > /dev/null 2>&1

grep -Eo "[a-zA-Z0-9._%+-]+@$domain" "$outputDir/harvester.xml" | sort -u > "$outputDir/harvester.txt"
echo "[+] Harvested $(wc -l < "$outputDir/harvester.txt") emails from theHarvester"

# === Hunter.io ===
if [[ -n "$hunter_api_key" ]]; then
  echo "[*] Querying Hunter.io API..."
  curl -s "https://api.hunter.io/v2/domain-search?domain=$domain&api_key=$hunter_api_key" \
    | jq -r '.data.emails[]?.value' 2>/dev/null | grep -Ei "@$domain" | sort -u > "$outputDir/hunter.txt"
  echo "[+] Found $(wc -l < "$outputDir/hunter.txt") emails via Hunter.io"
else
  echo "[!] Missing Hunter.io API key."
  > "$outputDir/hunter.txt"
fi

# === GitHub Dorking ===
if command -v lynx >/dev/null 2>&1; then
  echo "[*] Searching GitHub for public emails..."
  github_url="https://github.com/search?q=%40$domain&type=code"
  lynx -dump "$github_url" | grep -Eio "[a-zA-Z0-9._%+-]+@$domain" | sort -u > "$outputDir/github.txt"
  echo "[+] Found $(wc -l < "$outputDir/github.txt") emails via GitHub"
else
  echo "[!] 'lynx' not installed. Skipping GitHub dorking."
  > "$outputDir/github.txt"
fi

# === Merge & Clean ===
echo "[*] Consolidating and deduplicating emails..."
cat "$outputDir/"*.txt | sort -u > "$outputDir/all_emails.txt"
total_emails=$(wc -l < "$outputDir/all_emails.txt")

# === Summary ===
{
  echo "Email Recon Summary for: $domain"
  echo "------------------------------------"
  echo "theHarvester: $(wc -l < "$outputDir/harvester.txt")"
  echo "Hunter.io   : $(wc -l < "$outputDir/hunter.txt")"
  echo "GitHub      : $(wc -l < "$outputDir/github.txt")"
  echo ""
  echo "Total unique emails found: $total_emails"
} > "$outputDir/summary.txt"

# === Final Output ===
echo ""
echo "[✓] Done. "
echo ""
echo "[+] All emails saved to: $outputDir/all_emails.txt"
