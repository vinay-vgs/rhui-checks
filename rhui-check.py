#!/usr/bin/python3
"""This script will perform an instance repository check and attempt
   to fix any issues which prevent the instance from registering to
   the SUSE update infrastructure """

import argparse
import datetime
import json
import logging
import os
import re
import requests
import shlex
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from requests.packages import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

VERSION = "1.0.0"
SCRIPT_NAME = "rhui-checks"


def get_framework():
    """Check which public cloud framework script is running in"""
    cmd = ["dmidecode"]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        logging.error("dmidecode error: %s" % e)
        sys.exit()
    except FileNotFoundError:
        logging.error("dmidecode binary not found.")
        sys.exit()
    else:
        dmidecode_output = str(proc.stdout.read().lower())
    if "microsoft" in dmidecode_output:
        framework = "azure"
    elif "amazon" in dmidecode_output:
        framework = "ec2"
    elif "google" in dmidecode_output:
        framework = "gce"
    else:
        logging.error("No supported framework. Quitting.")
        sys.exit()
    return framework

