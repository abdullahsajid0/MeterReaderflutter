# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.x.x   | :white_check_mark: |
| < 2.0.0 | :x:                |

---

## Reporting a Vulnerability

We take the security and privacy of WattWise and its users very seriously.

If you believe you have discovered a security vulnerability (such as an insecure dependency, insecure data storage, or improper handling of network requests):

1. **Do not disclose it publicly in an open GitHub issue.**
2. Please report the issue privately using **[GitHub Private Security Advisories](https://github.com/abdullahsajid0/MeterReaderflutter/security/advisories/new)** or by opening a draft advisory.
3. Include detailed steps to reproduce the vulnerability, along with proof-of-concept information if available.

### What to Expect
- We will acknowledge receipt of your vulnerability report within 48 hours.
- We will provide an assessment and timeline for releasing a fix.
- Once fixed, a security advisory will be published and credit will be given (unless you wish to remain anonymous).

---

## Privacy Architecture Note

WattWise is designed with privacy-by-default:
- **On-Device OCR**: Optical Character Recognition for meter reading occurs strictly on-device using Google ML Kit. No camera frames or photographs are transmitted to external servers.
- **Local Persistence**: User meter reading histories, target limits, and preferences are stored locally using SQLite / SharedPreferences.
- **Public Bill Scraper**: Web bill synchronization requests only target public DISCO bill endpoints using reference numbers provided by the user.
