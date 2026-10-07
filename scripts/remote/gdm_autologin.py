#!/usr/bin/env python3
"""Active, désactive ou affiche l'ouverture de session automatique GDM (/etc/gdm/custom.conf).

Édition ligne à ligne : les commentaires et les autres sections du fichier sont conservés.
"""
import argparse
import re
import sys

SECTION = re.compile(r"^\s*\[(.+?)\]\s*$")
AUTOLOGIN = re.compile(r"^\s*AutomaticLogin(Enable)?\s*=", re.IGNORECASE)
USER = re.compile(r"^[a-z_][a-z0-9_-]*$")


def edit(lines, user, enable):
    out = []
    in_daemon = False
    seen_daemon = False
    for line in lines:
        header = SECTION.match(line)
        if header:
            in_daemon = header.group(1).strip().lower() == "daemon"
            out.append(line)
            if in_daemon and not seen_daemon:
                seen_daemon = True
                if enable:
                    out.append("AutomaticLoginEnable=True\n")
                    out.append(f"AutomaticLogin={user}\n")
            continue
        if in_daemon and AUTOLOGIN.match(line):
            continue
        out.append(line)
    if enable and not seen_daemon:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        out += ["\n", "[daemon]\n", "AutomaticLoginEnable=True\n", f"AutomaticLogin={user}\n"]
    return out


def status(lines):
    in_daemon = False
    values = {}
    for line in lines:
        header = SECTION.match(line)
        if header:
            in_daemon = header.group(1).strip().lower() == "daemon"
            continue
        if in_daemon and "=" in line and not line.lstrip().startswith(("#", ";")):
            key, value = line.split("=", 1)
            values[key.strip().lower()] = value.strip()
    if values.get("automaticloginenable", "").lower() in ("true", "1", "yes"):
        return f"enabled user={values.get('automaticlogin', '')}"
    return "disabled"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("action", choices=("enable", "disable", "status"))
    parser.add_argument("--user", help="utilisateur à ouvrir automatiquement (enable)")
    parser.add_argument("--file", default="/etc/gdm/custom.conf")
    args = parser.parse_args(argv)
    try:
        with open(args.file, encoding="utf-8") as handle:
            lines = handle.readlines()
    except FileNotFoundError:
        lines = []
    if args.action == "status":
        print(status(lines))
        return 0
    if args.action == "enable":
        if not args.user or not USER.match(args.user) or args.user == "root":
            print("ERREUR : --user doit être un compte non root valide", file=sys.stderr)
            return 2
    with open(args.file, "w", encoding="utf-8") as handle:
        handle.writelines(edit(lines, args.user, args.action == "enable"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
