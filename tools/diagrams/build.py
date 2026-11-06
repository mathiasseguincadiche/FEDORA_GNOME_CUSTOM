"""Build the seven documentation diagrams into OUT_DIR as .drawio + .svg pairs."""
import sys
from pathlib import Path

from diagramkit import Diagram

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
diagrams = []

# 1. ARCHITECTURE — what the workstation contains and where the data lives.
d = Diagram("architecture-poste", "Le poste obtenu : usages et stockage",
            "Le PC cible exécute Fedora 45 Workstation (Wayland, SELinux, firewalld). Fedora porte quatre usages : "
            "bureau GNOME 51, DevOps avec KVM, jeu vidéo et noyau Linux amont avec secours Fedora. Le premier T705 "
            "contient le système Btrfs, réinstallé depuis le dépôt. Le second T705 porte /data en EXT4, conservé lors "
            "d'une réinstallation : documents, projets et IA sont sauvegardés par Borg sur le SSD externe XS1000 ; "
            "ISO et jeux sont hors Borg par défaut ; les disques des VM s'exportent à la main.", 1320, 760)
d.node("pc", ["PC cible", "Ryzen 7 7700 · Arc B580 · 48 Gio"], 60, 80, 300, 70)
d.node("host", ["Fedora 45 Workstation", "Wayland · SELinux · firewalld"], 60, 200, 300, 70, "main")
d.group("g_use", "Usages", 440, 80, 840, 200)
for i, (nid, lines) in enumerate([("gnome", ["Bureau GNOME 51", "Nautilus · Ptyxis", "six extensions"]),
                                  ("dev", ["DevOps", "Git · Bash", "KVM / libvirt"]),
                                  ("game", ["Jeu vidéo", "Steam · Proton", "Vulkan"]),
                                  ("kernel", ["Noyau", "Linux amont N / N-1", "secours : noyau Fedora"])]):
    d.node(nid, lines, 460 + i * 205, 130, 190, 120)
d.node("root", ["T705 nº1 : système Btrfs", "réinstallé depuis le dépôt"], 60, 360, 360, 76)
d.node("data", ["T705 nº2 : /data EXT4", "conservé à la réinstallation"], 520, 360, 360, 76, "data")
d.node("files", ["Documents, Projets, IA", "sauvegardés par Borg"], 380, 510, 260, 76, "data")
d.node("media", ["ISO, Jeux", "hors Borg par défaut"], 670, 510, 260, 76, "muted")
d.node("vms", ["Disques des VM", "libvirt · export manuel"], 980, 510, 260, 76, "muted")
d.node("borg", ["Borg · SSD externe XS1000", "ext4 · non chiffré"], 380, 650, 260, 76)
d.edge("e1", "pc", "host")
d.edge("e_use", "host", "g_use")
d.edge("e_root", "host", "root")
d.edge("e_data", "host", "data")
for nid in ("files", "media", "vms"):
    d.edge("c_" + nid, "data", nid)
d.edge("e_borg", "files", "borg", "sauvegarde quotidienne")
diagrams.append(d)

# 2. BACKUP_RESTORE — what Borg protects, where, and how a restore happens.
d = Diagram("sauvegarde-restauration", "Sauvegarde et restauration",
            "Trois familles de sources vont dans un dépôt Borg sur le SSD externe XS1000 (ext4, non chiffré) : les données "
            "de /data (Documents, Projets, IA/Openclaw), les dossiers personnels (Bureau, Images, Vidéos, Musique, "
            "~/Development) et les réglages (.config, .mozilla, .var/app, .local/share, configuration de l'hôte et du projet). "
            "La sauvegarde pré-APPLY est validée par borg check --verify-data et une restauration canari. Une restauration "
            "se fait d'abord dans ~/Restores, puis on inspecte et on copie à la main. Hors Borg : Téléchargements, ISO, Jeux "
            "et les VM, exportées manuellement ; le système est reconstruit depuis le dépôt.", 1320, 680)
d.group("g_src", "Sources sauvegardées", 40, 80, 420, 420)
d.node("s1", ["Données de /data", "Documents · Projets · IA/Openclaw"], 60, 126, 380, 86, "data")
d.node("s2", ["Dossiers personnels", "Bureau · Images · Vidéos · Musique", "~/Development"], 60, 236, 380, 96)
d.node("s3", ["Réglages", ".config · .mozilla · .var/app", ".local/share", "configuration de l'hôte et du projet"], 60, 356, 380, 124)
d.node("borg", ["Dépôt Borg", "SSD externe Kingston XS1000", "ext4 · non chiffré (ADR 0014)"], 520, 236, 300, 110, "main")
d.node("c1", ["Contrôles de validation", "borg check --verify-data", "restauration canari"], 960, 96, 320, 96)
d.node("c2", ["Restauration en staging", "~/Restores/fedora-gnome-custom"], 960, 246, 320, 86)
d.node("c3", ["Inspection, puis copie manuelle", "jamais d'écrasement en place"], 960, 392, 320, 86)
d.node("m1", ["Hors Borg", "Téléchargements · ISO · Jeux", "disques, XML et NVRAM des VM : export manuel"], 40, 540, 600, 110, "muted")
d.node("m2", ["T705 nº1 : système", "reconstruit depuis le dépôt, pas restauré"], 680, 540, 600, 110, "muted")
for nid in ("s1", "s2", "s3"):
    d.edge("b_" + nid, nid, "borg")
d.edge("e_c1", "borg", "c1", "pré-APPLY")
d.edge("e_c2", "borg", "c2", "restaurer")
d.edge("e_c3", "c2", "c3")
diagrams.append(d)

# 3. CI_VALIDATION — what must be green before a merge and before a release.
d = Diagram("ci-fusion-release", "Ce qui doit être vert : fusion puis release",
            "Le workflow Tests lance sept jobs : logic-contracts, installer-audit, borg-fedora, fedora-gnome-vm natif, "
            "fedora45-gnome-vm avec six extensions, upstream-kernel et rocky-devops-vm. Le job contracts exige leurs sept "
            "succès ; sur une pull request qui ne change que la documentation, il accepte seulement que les trois VM soient sautées. La fusion dans main exige contracts et cinq autres contextes : shellcheck, guards, packages, "
            "packages-and-integration et nautilus-ptyxis. Après la fusion, les mêmes workflows et le scan de sécurité "
            "tournent sur le commit de main ; release.yml ne publie la préversion que si tout est vert sur ce même commit.",
            1320, 760)
d.group("g_tests", "Workflow Tests : 7 jobs", 40, 80, 360, 520)
jobs = ["logic-contracts", "installer-audit", "borg-fedora", "fedora-gnome-vm (natif)",
        "fedora45-gnome-vm (6 ext.)", "upstream-kernel / rpm", "rocky-devops-vm"]
for i, job in enumerate(jobs):
    d.node(f"j{i}", [job], 60, 122 + i * 66, 320, 52)
d.node("contracts", ["contracts", "exige les 7 succès", "PR de doc. : VM sautées"], 450, 290, 270, 110, "main")
d.node("other", ["Autres contrôles obligatoires", "shellcheck · guards · packages", "packages-and-integration",
                 "nautilus-ptyxis"], 900, 110, 360, 124)
d.node("merge", ["Fusion autorisée", "6 contextes obligatoires verts"], 880, 300, 400, 90, "main")
d.node("push", ["push sur main", "mêmes workflows + Security scanning"], 880, 460, 400, 80)
d.node("release", ["release.yml", "préversion si tout est vert", "sur le même commit"], 880, 610, 400, 100, "data")
d.edge("e_c", "g_tests", "contracts")
d.edge("e_m1", "contracts", "merge")
d.edge("e_m2", "other", "merge")
d.edge("e_p", "merge", "push", "après la fusion")
d.edge("e_r", "push", "release")
diagrams.append(d)

# 4. CONTROL_CENTER — a thin façade over specialised engines.
d = Diagram("centre-de-controle", "Le centre de contrôle : une façade, des moteurs",
            "L'opérateur passe par ./control.sh, une façade sans logique métier. Chaque domaine appelle son moteur : "
            "install (install.sh, dry-run et APPLY protégé), update (update-system.sh), kernel (kernel-lifecycle.sh et "
            "secours Fedora), backup (backup-now.sh, restore.sh), kvm (création Rocky DevOps et garde réseau), doctor "
            "(diagnostics en lecture seule), validate et cert (Live USB, Gate 3, certification), status et logs.",
            1160, 700)
d.node("user", ["Opérateur"], 40, 300, 180, 70)
d.node("cc", ["./control.sh", "façade mince", "aucune logique métier"], 280, 275, 240, 120, "main")
d.group("g_dom", "Domaines et moteurs appelés", 620, 70, 500, 610)
domains = [("install", "install.sh : dry-run, APPLY protégé"),
           ("update", "scripts/maintenance/update-system.sh"),
           ("kernel", "kernel-lifecycle.sh · secours Fedora"),
           ("backup", "backup-now.sh · restore.sh"),
           ("kvm", "Rocky DevOps · garde réseau"),
           ("doctor", "diagnostics/*-doctor (lecture seule)"),
           ("validate · cert", "Live USB · Gate 3 · certification"),
           ("status · logs", "état du poste et journaux")]
for i, (name, engine) in enumerate(domains):
    d.node(f"d{i}", [name, engine], 640, 110 + i * 70, 460, 58)
d.edge("e_u", "user", "cc")
d.edge("e_d", "cc", "g_dom")
diagrams.append(d)

# 5. FEDORA_GNOME_CI_LAB — the disposable lab sequence.
d = Diagram("laboratoire-gnome", "Le laboratoire Fedora/GNOME sur GitHub",
            "Sur un runner GitHub jetable, sans toucher au PC : 1, une VM Fedora 45 démarre depuis l'image Cloud finale "
            "vérifiée ; 2, le dépôt est installé et la session GNOME 51 contrôlée ; 3, des données témoin survivent à un "
            "redémarrage ; 4, la VM est arrêtée puis sauvegardée à froid par Borg ; 5, l'original est supprimé et la VM "
            "restaurée redémarre ; 6, une image neuve est reconstruite et redémarrée ; 7, le rapport conserve preuves et "
            "journaux, et tout plantage fait échouer le laboratoire.", 1320, 540)
d.group("g_lab", "Runner GitHub jetable : aucune commande sur le PC", 30, 70, 1260, 440)
steps_top = [["1. VM Fedora 45", "image Cloud finale", "signature et SHA-256"],
             ["2. Dépôt et session", "GNOME 51 sous Wayland", "natif ou six extensions"],
             ["3. Données témoin", "redémarrage", "persistance vérifiée"],
             ["4. Arrêt propre", "Borg à froid : disque,", "UEFI et TPM"]]
steps_bottom = [["5. Restauration", "original supprimé,", "VM restaurée démarrée"],
                ["6. Reconstruction", "image neuve", "redémarrage et contrôles"],
                ["7. Rapport", "preuves et journaux", "plantage = échec"]]
for i, lines in enumerate(steps_top):
    d.node(f"t{i}", lines, 60 + i * 310, 120, 270, 110)
for i, lines in enumerate(steps_bottom):
    d.node(f"b{i}", lines, 990 - i * 310, 340, 270, 110, "data" if i == 2 else "box")
chain = ["t0", "t1", "t2", "t3", "b0", "b1", "b2"]
for a, b in zip(chain, chain[1:]):
    d.edge(f"e_{a}_{b}", a, b)
diagrams.append(d)

# 6. QUALIFICATION — from the CI to the Golden release.
d = Diagram("chaine-qualification", "La chaîne de qualification",
            "Onze étapes : 1, CI au commit exact sur GitHub ; 2, contrôle Live USB sur le PC (PREINSTALL_ONLY, preuve "
            "exportée) ; 3, analyse des résultats et décision humaine GO ou NO-GO avant installation ; "
            "4, installation de Fedora et import de la preuve ; 5, baseline matérielle ; 6, dry-run ; "
            "7, sauvegarde Borg pré-APPLY vérifiée ; 8, APPLY protégé sur le PC physique ; 9, redémarrage sur Linux "
            "amont N ; 10, Gate 3 du système installé ; 11, Golden release. Une évolution du matériel, du code ou de la configuration "
            "invalide les preuves concernées.", 1320, 600)
grid = [(60, 90), (370, 90), (680, 90), (990, 90), (990, 260), (680, 260), (370, 260), (60, 260), (60, 430), (370, 430), (680, 430)]
steps = [(["1. CI au commit exact", "GitHub : contrats,", "laboratoires QEMU"], "box"),
         (["2. Live USB sur le PC", "PREINSTALL_ONLY", "preuve exportée"], "box"),
         (["3. Accord du propriétaire", "résultats relus : GO / NO-GO", "avant tout effacement"], "warn"),
         (["4. Installation", "Fedora sur le SSD", "import de la preuve Live"], "box"),
         (["5. Baseline", "santé matérielle", "avant l'APPLY"], "box"),
         (["6. Dry-run", "plan de convergence", "aucun module appliqué"], "box"),
         (["7. Sauvegarde", "Borg pré-APPLY", "vérifiée, canari restauré"], "box"),
         (["8. APPLY protégé", "phrase de confirmation", "PC physique uniquement"], "box"),
         (["9. Redémarrage", "Linux amont N"], "box"),
         (["10. Gate 3", "doctors, cinq veilles", "certification du PC"], "main"),
         (["11. Golden release", "statut certifié", "preuves liées à l'état"], "data")]
for i, ((x, y), (lines, style)) in enumerate(zip(grid, steps)):
    d.node(f"q{i}", lines, x, y, 270, 110, style)
for i in range(len(steps) - 1):
    d.edge(f"eq{i}", f"q{i}", f"q{i + 1}")
diagrams.append(d)

# 7. REMOTE_ACCESS — tablet, Tailscale, relay and PC.
d = Diagram("acces-distant", "Accès distant : tablette, Tailscale et réveil",
            "La tablette Android (Moonlight, client SSH, Tailscale) atteint le PC Fedora par le tunnel privé Tailscale, "
            "sans port ouvert sur Internet : SSH par clés uniquement, Sunshine s'il est activé, GNOME Remote Desktop en "
            "repli configuré à la main. Pour réveiller le PC éteint, la tablette s'adresse au relais toujours allumé sur "
            "le réseau local, qui envoie le Magic Packet. Le profil est désactivé par défaut.", 1320, 480)
d.node("tablet", ["Tablette Android", "Moonlight · client SSH", "Tailscale"], 40, 110, 260, 110)
d.node("ts", ["Tailscale", "tunnel privé chiffré", "aucun port sur Internet"], 380, 110, 250, 110, "main")
d.node("pc", ["PC Fedora", "sshd : clés uniquement", "Sunshine, si activé", "repli manuel : GNOME Remote Desktop",
              "zone firewalld fgc-tailnet"], 840, 80, 440, 170, "main")
d.node("relay", ["Relais toujours allumé", "sur le réseau local"], 380, 330, 250, 100)
d.node("note", ["Profil désactivé par défaut", "REMOTE_ENABLE=false", "Gate 3 à faire"], 40, 330, 260, 100, "muted")
d.edge("e1", "tablet", "ts", both=True)
d.edge("e2", "ts", "pc", "SSH · flux vidéo", both=True)
d.edge("e3", "ts", "relay", "réveil")
d.edge("e4", "relay", "pc", "Magic Packet (LAN)", dashed=True)
diagrams.append(d)

for d in diagrams:
    d.check()
    (out / f"{d.name}.svg").write_bytes(d.svg().encode("utf-8"))
    (out / f"{d.name}.drawio").write_bytes(d.drawio().encode("utf-8"))
    print("built", d.name)
