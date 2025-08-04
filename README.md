# auto-recon-suite
A fully automated reconnaissance toolkit for any domain or organization. This script-based suite collects live subdomains, IPs, DNS records, emails, application technologies, and even checks antivirus detection. It’s perfect for bug bounty hunters, red teamers, and OSINT enthusiasts.



## Features

- Subdomain enumeration (passive + brute force)
- DNS records collection
- Live host detection
- Application fingerprinting (WhatWeb, Webanalyze, BuiltWith, Nmap)
- Email harvesting
- AV/URL detection check
- Simple interactive CLI
- Organized outputs by organization



## Directory Structure
```
~/recon/
  ├── scripts/
  │ ├── subdomain.sh           # Subdomain enumeration
  │ ├── dnsrecords.sh           # DNS and network info
  │ ├── emails.sh         # Email harvesting
  │ ├── avdetect.sh     # Antivirus info 
  │ ├── appfp.sh   # Application info 
  ├── README.md          # This documentation
```

## Prerequisites

Make sure the following tools are installed:

- `subfinder`
- `assetfinder`
- `amass`
- `dnsx`
- `httpx`
- `whatweb`
- `webanalyze`
- `nmap`
- `theHarvester`
- `curl`, `jq`, `awk`, `bash`, etc.

##  Usage

```bash
git clone https://github.com/YOUR_USERNAME/global-recon-toolkit.git
cd global-recon-toolkit/scripts
chmod +x *.sh
./subenum.sh       # Subdomain Enumeration
./dnsrecords.sh    # DNS Record Collection
./appfp.sh         # App Fingerprinting
./emails.sh        # Email Harvesting
./avdetect.sh            # AV / URL reputation
```



## Walkthrough

For a detailed walkthrough of the implementation, watch my [Medium Walkthrough](https://youtu.be/PkLIdSmdRyE).



## Disclaimer

This project involves working with live malware. **Extreme caution** must be exercised. Ensure all testing is performed in a secure, isolated environment to prevent accidental harm. Follow ethical guidelines and cybersecurity best practices strictly.


