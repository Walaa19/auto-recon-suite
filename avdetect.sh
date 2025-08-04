#!/bin/bash

# Colors for terminal
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

# Prompt user for target
read -p "Enter target domain (e.g., example.com): " target
if [[ -z "$target" ]]; then
    echo -e "${RED}[!] Target domain is required. Exiting.${RESET}"
    exit 1
fi
read -p "Enter organization name (no spaces): " orgName

# Setup
base_dir="$HOME/recon"
output_dir="$base_dir/avdetect_${orgName}"
mkdir -p "$output_dir"
output_file="$output_dir/avdetect.txt"
favicon_file="$output_dir/favicon.ico"

echo -e "${BOLD}[+] Antivirus Detection Report for: $target${RESET}"
echo -e "[*] Output saved in: $output_file"
echo "==============================" | tee "$output_file"
echo "[*] Starting Antivirus Detection on $target" | tee -a "$output_file"

# 1. Check for HTTP headers
echo -e "\n${BLUE}[1] AV/WAF/IPS/Related HTTP Headers:${RESET}" | tee -a "$output_file"
headers=$(curl -sI "https://$target")
if [[ -z "$headers" ]]; then
    echo -e "${RED}[-] Could not fetch HTTP headers.${RESET}" | tee -a "$output_file"
else
    echo "$headers" | grep -iE "X-AV|X-Proofpoint|X-FireEye|X-Bluecoat|X-Powered-By|Server" | tee -a "$output_file"
fi

# 2. Run httpx for technology detection
echo -e "\n${BLUE}[2] Web Tech Detection (httpx):${RESET}" | tee -a "$output_file"
echo "$target" | httpx -title -tech-detect -web-server -silent | tee -a "$output_file"

# 3. Favicon Hashing
echo -e "\n${BLUE}[3] Favicon Hashing:${RESET}" | tee -a "$output_file"
wget -q "https://$target/favicon.ico" -O "$favicon_file"
if [[ -s "$favicon_file" ]]; then
    sha256hash=$(sha256sum "$favicon_file" | awk '{print $1}')
    md5hash=$(md5sum "$favicon_file" | awk '{print $1}')
    echo "SHA256: $sha256hash" | tee -a "$output_file"
    echo "MD5   : $md5hash" | tee -a "$output_file"
    echo "Search in Shodan: http.favicon.hash:$md5hash" | tee -a "$output_file"
else
    echo -e "${RED}[-] Failed to download favicon.ico${RESET}" | tee -a "$output_file"
fi

# 4. WAF/IPS/IDS Detection via Nmap
echo -e "\n${BLUE}[4] WAF/IPS Detection (Nmap):${RESET}" | tee -a "$output_file"
nmap -p 80,443 --script http-waf-detect,http-waf-fingerprint -T4 "$target" | tee -a "$output_file"

# Done
echo -e "\n${GREEN}[✓] Scan completed. Output saved to: $output_file${RESET}"
