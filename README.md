# RHUI Checks & Auto-Repair Tool

A diagnostic and automated remediation utility for Red Hat Enterprise Linux (RHEL) instances running on cloud platforms (GCP, AWS/EC2, Azure).

This repository contains tools to identify, troubleshoot, and automatically fix Red Hat Update Infrastructure (RHUI) repository and package installation issues.

## Tools Included

* **`rhui-checks.py` (Main Repair Tool (Under development)):** Python 3 engine that performs deep repository health checks, queries metadata servers, and attempts to automatically repair broken repository configurations and SSL certificate issues.Its still under development and contributions are welcomed.
* **`rhui-checks.sh` (Diagnostic Wrapper):** Lightweight Bash script for quick, color-coded terminal environment checks.

## Key Features

* **Cloud Platform Detection:** Identifies execution environment (GCP `gce`, AWS `ec2`, or Azure) using system `dmidecode`.
* **Automated Remediation:** Attempts to fix broken `yum`/`dnf` repository setups preventing package installations.
* **Licensing & Metadata Verification:** Validates instance pay-as-you-go (PAYG) licensing against cloud provider metadata endpoints.
* **RHUIv4 Endpoint Validation:** Ensures systems are migrated from legacy RHUIv3 endpoints to modern infrastructure (`rhui.googlecloud.com`).
* **Yum/DNF Configuration Analysis:** Detects hardcoded OS version locks (`releasever`) and HTTP repository errors (403/404/SSL errors).

## Usage

Run the Python script with root privileges:

```bash
sudo python3 rhui-checks.py

Or run the shell diagnostic wrapper:

chmod +x rhui-checks.sh
sudo ./rhui-checks.sh

System Requirements
OS: Red Hat Enterprise Linux (RHEL)
Python: Python 3.x with requests package installed
System Utilities: dmidecode, curl
License
Licensed under the Apache License, Version 2.0.
