# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest   | Yes |
| < latest | No  |

Only the latest release receives security updates. We recommend always running the most recent version.

## Reporting a Vulnerability

**Please do NOT open a public GitHub issue for security vulnerabilities.**

Instead, send an email to **security@evoai.com** with:

- A description of the vulnerability
- Steps to reproduce (if applicable)
- The potential impact
- Any suggested fixes (optional)

### What to Expect

- **Acknowledgment** within 48 hours of your report.
- **Status update** within 7 business days with an initial assessment.
- **Resolution timeline** communicated once the issue is confirmed.

We follow responsible disclosure practices. We ask that you give us a reasonable amount of time to address the issue before any public disclosure.

### What to Report

- Authentication or authorization bypasses
- Data exposure or leakage
- Remote code execution
- Injection vulnerabilities (SQL, command, etc.)
- Cross-site scripting (XSS) or cross-site request forgery (CSRF)

### What NOT to Report

- Issues already listed in public GitHub issues
- Denial of service (DoS) without a practical attack vector
- Social engineering attacks
- Issues in dependencies without a demonstrated exploit in this project
- Missing security headers on non-sensitive endpoints

## Recognition

We appreciate the security research community. Reporters of valid vulnerabilities will be credited in release notes (unless they prefer to remain anonymous).
