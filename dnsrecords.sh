#!/bin/bash

# Prompt user interactively
read -p "Enter root domain (e.g., example.com): " rootDomain
read -p "Enter organization name (no spaces): " orgName

# Paths
baseDir="$HOME/recon"
outputDir="$baseDir/dnsrecon_${orgName}"
recordsDir="$outputDir/records"
reconDir="$outputDir/recon"
ipDir="$outputDir/ip_ranges"
summaryFile="$outputDir/summary.txt"

echo "[*] Recon output will be saved in: $outputDir"
echo "[*] Starting DNS enumeration for $orgName"

# Clean any previous results
rm -rf "$outputDir"
mkdir -p "$recordsDir" "$reconDir" "$ipDir"

# =============================
# DIG Records
# =============================
echo "[*] Collecting DNS records for $rootDomain..."
for type in A AAAA MX NS CNAME TXT ANY; do
    dig +noall +answer "$rootDomain" "$type" | sort -u > "$recordsDir/${rootDomain}_${type}.txt"
done

# =============================
# DNSRecon
# =============================
echo "[*] Running dnsrecon on $rootDomain..."
dnsrecon -d "$rootDomain" -n 8.8.8.8,1.1.1.1 -a -t std > "$reconDir/${rootDomain}_dnsrecon.txt"

# =============================
# IP Ranges
# =============================
echo "[*] Extracting IP ranges..."

# IPv4 /24
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$recordsDir/${rootDomain}_A.txt" | sort -u | \
    awk -F. '{print $1"."$2"."$3".0/24"}' | sort -u > "$ipDir/${rootDomain}_ipv4_ranges.txt"

# IPv6 /48
grep -Eo '([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}' "$recordsDir/${rootDomain}_AAAA.txt" | sort -u | \
    cut -d: -f1-3 | sed 's/$/::\/48/' | sort -u > "$ipDir/${rootDomain}_ipv6_ranges.txt"

# =============================
# SUMMARY FILE
# =============================
echo "[*] Building summary..."

echo "=============================================" > "$summaryFile"
echo " DNS RECONNAISSANCE SUMMARY for $orgName" >> "$summaryFile"
echo "=============================================" >> "$summaryFile"

# --- DIG section ---
echo -e "\n========== DIG RECORDS ==========" >> "$summaryFile"
for type in A AAAA MX NS CNAME TXT ANY; do
    file="$recordsDir/${rootDomain}_${type}.txt"
    if [[ -s "$file" ]]; then
        echo -e "\n[*] ${type} Records:" >> "$summaryFile"
        sort -u "$file" | sed '/^$/d' >> "$summaryFile"
    fi
done

# --- DNSRecon section ---
echo -e "\n========== DNSRECON RESULTS ==========" >> "$summaryFile"
reconFile="$reconDir/${rootDomain}_dnsrecon.txt"
if [[ -s "$reconFile" ]]; then
    echo -e "\n[*] Extracted Hosts:" >> "$summaryFile"
    grep -iE 'Name|A\sRecord|AAAA\sRecord|PTR|CNAME' "$reconFile" | sort -u >> "$summaryFile"

    echo -e "\n[*] Zone Transfer Attempts:" >> "$summaryFile"
    grep -i "Zone Transfer" "$reconFile" | sort -u >> "$summaryFile"

    echo -e "\n[*] Wildcards and Misconfigurations:" >> "$summaryFile"
    grep -Ei "wildcard|misconfigured|interesting|vulnerable" "$reconFile" | sort -u >> "$summaryFile"
else
    echo "No dnsrecon data found." >> "$summaryFile"
fi

# --- IP ranges section ---
echo -e "\n========== IP RANGES ==========" >> "$summaryFile"

if [[ -s "$ipDir/${rootDomain}_ipv4_ranges.txt" ]]; then
    echo -e "\n[*] IPv4 ranges (/24):" >> "$summaryFile"
    sort -u "$ipDir/${rootDomain}_ipv4_ranges.txt" >> "$summaryFile"
else
    echo -e "\nNo IPv4 ranges found." >> "$summaryFile"
fi

if [[ -s "$ipDir/${rootDomain}_ipv6_ranges.txt" ]]; then
    echo -e "\n[*] IPv6 ranges (/48):" >> "$summaryFile"
    sort -u "$ipDir/${rootDomain}_ipv6_ranges.txt" >> "$summaryFile"
else
    echo -e "\nNo IPv6 ranges found." >> "$summaryFile"
fi

echo "[✓] Recon complete!"
echo "[✓] Results saved in: $outputDir"
echo "[✓] Summary available at: $summaryFile"
