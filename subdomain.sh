#!/bin/bash

# Base recon directory
baseDir="/home/user/recon"

# Prompt user
read -p "Enter root domain (e.g., example.com): " root_domain
read -p "Enter organization name (no spaces): " org_name

# Output directory
orgDir="${baseDir}/subdomain_${org_name}"
domainsDir="${orgDir}/domains"
rawDir="${orgDir}/raw"
resolvedDir="${orgDir}/resolved"
httpxDir="${orgDir}/httpx"
summaryFile="${orgDir}/summary.txt"

# Clean previous run
rm -rf "$orgDir"
mkdir -p "$domainsDir" "$rawDir" "$resolvedDir" "$httpxDir"

# Save root domain
echo "$root_domain" > "${domainsDir}/rootdomain.txt"

echo -e "[*] Recon output will be saved in: $orgDir"
echo -e "[*] Starting subdomain enumeration for $org_name"

### Subdomain Enumeration
echo "[*] Running Subfinder..."
subfinder -d "$root_domain" -all -silent > "${rawDir}/subfinder.txt"

echo "[*] Running Amass..."
amass enum -passive -d "$root_domain" -o "${rawDir}/amass.txt"

echo "[*] Running Assetfinder..."
assetfinder --subs-only "$root_domain" > "${rawDir}/assetfinder.txt"

# Merge + deduplicate subdomains
cat "${rawDir}"/*.txt | sort -u > "${orgDir}/all_subdomains.txt"
totalSubs=$(wc -l < "${orgDir}/all_subdomains.txt")
echo "[+] Total unique subdomains: $totalSubs"

### DNS Resolution
echo "[*] Resolving subdomains using dnsx..."
dnsx -l "${orgDir}/all_subdomains.txt" -a -silent \
    | sed 's/\[\|\]//g' | tee "${resolvedDir}/live.txt" \
    | awk '{print $1}' > "${resolvedDir}/live_subs_only.txt"

resolvedCount=$(wc -l < "${resolvedDir}/live_subs_only.txt")

### HTTP Probing
echo "[*] Probing HTTP services with httpx..."
httpx -l "${resolvedDir}/live_subs_only.txt" -sc -silent \
    | anew "${httpxDir}/metadata_raw.txt"

# Strip ANSI color codes
sed 's/\x1B\[[0-9;]*[JKmsu]//g' "${httpxDir}/metadata_raw.txt" > "${httpxDir}/metadata_clean.txt"

# HTTP Status Breakdown
echo "[*] Organizing results by HTTP status..."
statusSummary=""
for code in 200 301 302 401 403 404 502 503; do
    grep "\[$code\]" "${httpxDir}/metadata_clean.txt" | cut -d " " -f 1 | cut -d "/" -f 3 > "${httpxDir}/${code}.txt"
    count=$(wc -l < "${httpxDir}/${code}.txt")
    statusSummary+="$code responses: $count"$'\n'
done

### DNS Info Summary (Enhanced IP Resolution)
echo "[*] Collecting DNS info (fallback: dig, host, ping)..."
dnsinfoTmp="${orgDir}/dns_info_tmp.txt"
> "$dnsinfoTmp"

resolve_ip() {
    domain="$1"
    ip=$(dig +short A "$domain" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

    if [[ -z "$ip" ]]; then
        ip=$(host "$domain" | grep "has address" | awk '{print $4}' | head -n1)
    fi

    if [[ -z "$ip" ]]; then
        ip=$(ping -c 1 "$domain" 2>/dev/null | grep "PING" | awk -F '[()]' '{print $2}' | head -n1)
    fi

    echo "$ip"
}

while read -r sub; do
    ip=$(resolve_ip "$sub")
    if [[ -n "$ip" ]]; then
        echo "$sub -> $ip" >> "$dnsinfoTmp"
    else
        echo "$sub -> [No IP Found]" >> "$dnsinfoTmp"
    fi
done < "${resolvedDir}/live_subs_only.txt"

ip_ranges=$(cat "$dnsinfoTmp" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u)

### Final Summary
echo "[*] Creating summary.txt..."

{
    echo "Recon Summary for: $org_name"
    echo "----------------------------------------"
    echo "Root domain: $root_domain"
    echo ""
    echo "Total unique subdomains found: $totalSubs"
    echo "Total resolved (live) subdomains: $resolvedCount"
    echo ""
    echo "$statusSummary"
    echo ""
    echo "Live Subdomains:"
    cat "${resolvedDir}/live.txt"
    echo ""
    echo "Resolved IP Ranges :"
    cat ${orgDir}/dns_info_tmp.txt
} > "$summaryFile"

echo "[✓] Recon complete. All outputs are stored under: $orgDir"
