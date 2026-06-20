#!/usr/bin/env python3
import json
import subprocess
import sys

query = json.load(sys.stdin)

result = subprocess.run(
    ["openssl", "passwd", "-5", "-salt", query["salt"], "-stdin"],
    input=query["password"],
    capture_output=True,
    text=True,
    check=True,
)

json.dump({"hash": result.stdout.strip()}, sys.stdout)
