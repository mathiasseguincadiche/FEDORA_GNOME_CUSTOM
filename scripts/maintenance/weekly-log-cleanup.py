#!/usr/bin/env python3
"""Weekly, fail-closed cleanup of transient run logs. No journalctl deletion."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import sys

RUN_ID = re.compile(r"^\d{8}T\d{6}\d{9}Z-\d+$")
CATEGORIES = {
    "REMOTE": "acces-distant", "BACKUP": "sauvegardes",
    "HARDWARE": "materiel", "SECURITY": "securite",
    "SYSTEM": "systeme", "KVM": "systeme",
    "GNOME": "systeme", "APPLICATIONS": "installation",
}
ERROR = re.compile(r"\[(ERROR|KO|FAIL|FATAL)\]|\b(TRACEBACK|FAILED|SECURITY BLOCK)\b", re.I)

def utc_now():
    return dt.datetime.now(dt.timezone.utc)

def classify(text):
    for key, value in CATEGORIES.items():
        if f"[{key}]" in text:
            return value
    return "systeme"

def scan(root, now, dry_run):
    logs = root / "logs"
    incidents = logs / "incidents"
    reports = root / "reports"
    if not logs.is_dir() or logs.is_symlink():
        raise ValueError("Répertoire logs absent ou lien symbolique : refus")
    if incidents.is_symlink() or reports.is_symlink():
        raise ValueError("Chemin sensible sous forme de lien symbolique : refus")
    incidents.mkdir(mode=0o700, exist_ok=True)
    reports.mkdir(exist_ok=True)
    cutoff = now - dt.timedelta(days=7)
    events = []
    for run in sorted(logs.iterdir()):
        if run.is_symlink() or not run.is_dir() or not RUN_ID.fullmatch(run.name):
            continue
        try:
            stamp = dt.datetime.strptime(run.name[:15] + run.name[15:21] + "Z", "%Y%m%dT%H%M%S%fZ").replace(tzinfo=dt.timezone.utc)
        except ValueError:
            continue
        if stamp >= cutoff:
            continue
        if any(p.is_symlink() or not p.is_file() for p in run.iterdir()):
            events.append({"run":run.name,"action":"conserve","reason":"contenu inattendu"})
            continue
        main = run / "main.log"
        if not main.exists():
            events.append({"run":run.name,"action":"conserve","reason":"journal principal absent"})
            continue
        text = main.read_text(encoding="utf-8", errors="replace")
        incident = incidents / (run.name + ".json")
        if incident.exists():
            if not incident.is_file() or incident.is_symlink():
                events.append({"run":run.name,"action":"conserve","reason":"fiche incident non fiable"})
                continue
            try:
                state = json.loads(incident.read_text(encoding="utf-8")).get("status")
            except (ValueError, OSError):
                state = None
            if state != "resolved":
                events.append({"run":run.name,"action":"conserve","reason":"incident non résolu"})
                continue
        elif ERROR.search(text):
            data = {"run":run.name,"status":"open","category":classify(text),
                    "summary":"Erreur détectée dans le journal : diagnostic humain nécessaire.",
                    "created_utc":now.isoformat(),"resolution":None}
            if not dry_run:
                incident.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
                incident.chmod(0o600)
            events.append({"run":run.name,"action":"conserve","reason":"erreur détectée, incident ouvert"})
            continue
        if dry_run:
            events.append({"run":run.name,"action":"simulation-suppression","reason":"ancien journal sans incident ouvert"})
            continue
        # Only unlink regular files in a recognized run folder; never traverse directories.
        for entry in run.iterdir():
            entry.unlink()
        run.rmdir()
        events.append({"run":run.name,"action":"supprime","reason":"ancien journal sans incident ouvert"})
    report = {"date_utc":now.isoformat(),"simulation":dry_run,"events":events}
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if not dry_run:
        filename = "nettoyage-" + now.strftime("%Y%m%dT%H%M%S%fZ") + "-" + str(os.getpid()) + ".json"
        target = reports / filename
        with target.open("x",encoding="utf-8") as stream:
            json.dump(report,stream,ensure_ascii=False,indent=2)
            stream.write("\n")
    return report

def main():
    parser = argparse.ArgumentParser(description="Nettoyage hebdomadaire des logs, conservation des incidents ouverts.")
    parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument("--apply",action="store_true",help="Autorise la suppression des anciens journaux sûrs")
    args = parser.parse_args()
    try:
        scan(args.root.resolve(),utc_now(),not args.apply)
    except (OSError,ValueError) as exc:
        print(f"ERREUR : nettoyage interrompu : {exc}",file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
