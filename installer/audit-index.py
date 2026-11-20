#!/usr/bin/env python3
"""Audit staged paths and text before proposing publication."""
import re
import subprocess
import sys

secret = re.compile(rb"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{28,}|"
                    rb"github_pat_[A-Za-z0-9_]{30,}|sk-(?:proj-)?[A-Za-z0-9]{24,}|AKIA[A-Z0-9]{16}|"
                    rb"https?://[^\s/@:]+:[^\s/@]+@")
personal = re.compile(rb"(?<![A-Za-z0-9_./-])/(?:home|Users)/[A-Za-z0-9_.-]+/|/run/user/[0-9]+/")
forbidden = re.compile(r"(^|/)(?:\.backups|\.cache|__pycache__|\.env|credentials[^/]*)(?:/|$)|"
                       r"\.(?:ini|key|pem|p12|sqlite3?|sock|mp[34]|mkv|webm|zip|tar\.gz)$|"
                       r"/assets/(?:[^/]+\.svg|rory-foreground\.png)$", re.I)

def main():
    index = subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0")
    count = 0
    errors = []
    for path in filter(None, index):
        count += 1
        if forbidden.search(path):
            errors.append(f"Ruta excluida: {path}")
            continue
        if path == "installer/audit-index.py":
            continue
        data = subprocess.check_output(["git", "show", ":" + path])
        if b"\0" in data:
            errors.append(f"Binario requiere revisión independiente: {path}")
            continue
        for number, line in enumerate(data.splitlines(), 1):
            if secret.search(line) or personal.search(line):
                errors.append(f"Revisar texto: {path}:{number}")
    print(f"{count} rutas del índice inspeccionadas; {len(errors)} coincidencias.")
    for error in errors:
        print(error, file=sys.stderr)
    return bool(errors)

if __name__ == "__main__":
    raise SystemExit(main())
