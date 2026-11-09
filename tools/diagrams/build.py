"""Build desktop and mobile documentation diagrams as matching .drawio + .svg pairs."""
import sys
from pathlib import Path

from diagramkit import Diagram
from mobile import mobile_counterpart

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
diagrams = []

# 1. ARCHITECTURE — what the workstation contains and where the data lives.
d = Diagram("architecture-poste", "Un poste Fedora, deux rôles de stockage",
            "Le PC cible utilise Fedora 45 avec GNOME 51, DevOps/KVM, jeu et noyau Linux amont. "
            "Sur deux SSD Crucial T705 distincts, le système Btrfs peut être réinstallé tandis que /data ext4 "
            "est conservé. Sur /data, Documents, Projets et IA sont inclus dans Borg, mais ISO et Jeux ne le "
            "sont pas automatiquement ; disques VM exportés manuellement. Borg sauvegarde également des "
            "dossiers personnels et réglages décrits dans BACKUP_RESTORE.md. Le SSD Kingston XS1000 est externe. "
            "Les contrôles physiques Live USB et Gate 3 restent à réaliser.", 1440, 820)
d.group("g_work", "01  ENVIRONNEMENT DE TRAVAIL", 40, 94, 1360, 270)
d.node("pc", ["PC cible", "Ryzen 7 7700 · Intel Arc B580", "48 Go DDR5 · Wi-Fi 7 · 5 GbE"], 65, 163, 360, 138)
d.node("host", ["Fedora 45 Workstation", "GNOME 51 · SELinux · firewalld", "Configuration pilotée par Git"], 534, 163, 360, 138, "main")
d.group("g_uses", "Quatre usages", 1005, 145, 350, 173)
d.node("desktop", ["Bureau GNOME"], 1020, 183, 162, 52)
d.node("dev", ["DevOps · KVM"], 1188, 183, 162, 52)
d.node("game", ["Jeux · Vulkan"], 1020, 248, 162, 52)
d.node("kernel", ["Noyau Linux"], 1188, 248, 162, 52)
d.edge("pc_to_host", "pc", "host")
d.edge("host_to_uses", "host", "g_uses")
d.group("g_storage", "02  STOCKAGE ET PROTECTION DES DONNÉES", 40, 419, 1360, 345)
d.node("root", ["SSD 01 · Système Btrfs", "Crucial T705 · Fedora et logiciels", "Fedora réinstallé, profil Git rejoué"], 65, 509, 390, 174)
d.node("data", ["SSD 02 · Données /data ext4", "Crucial T705 · données conservées", "Borg : Documents, Projets, IA", "Hors Borg : ISO, Jeux, disques VM"], 520, 498, 415, 196, "main")
d.node("borg", ["SSD externe · Borg", "Kingston XS1000 · dépôt non chiffré", "Contrôler, restaurer en zone isolée"], 1005, 509, 350, 174, "data")
d.edge("data_to_borg", "data", "borg")
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
            "tournent sur le commit de main. Le workflow release.yml ne démarre que si son manifeste ou ses fichiers "
            "de workflow/résolution changent ; il exige alors les contrôles verts du même commit avant publication.",
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
d.node("release", ["release.yml (déclenchement conditionnel)", "préversion après contrôles verts", "sur le même commit"], 880, 610, 400, 100, "data")
d.edge("e_c", "g_tests", "contracts")
d.edge("e_m1", "contracts", "merge")
d.edge("e_m2", "other", "merge")
d.edge("e_p", "merge", "push", "après la fusion")
d.edge("e_r", "push", "release", "si fichiers release modifiés")
diagrams.append(d)

# 4. CONTROL_CENTER — a thin façade over specialised engines.
d = Diagram("centre-de-controle", "Le centre de contrôle : une façade, des moteurs",
            "L'opérateur passe par ./control.sh, une façade sans logique métier. Chaque domaine appelle son moteur : "
            "install (install.sh, dry-run et APPLY protégé), update (update-system.sh), kernel (kernel-lifecycle.sh et "
            "secours Fedora), backup (backup-now.sh, restore.sh), kvm (création Rocky DevOps et garde réseau), doctor "
            "(observations et essais actifs explicites), validate et cert (Live USB, Gate 3, certification), status et logs. "
            "Les huit blocs représentent des regroupements, pas toutes les routes du centre de contrôle.",
            1160, 700)
d.node("user", ["Opérateur"], 40, 300, 180, 70)
d.node("cc", ["./control.sh", "façade mince", "aucune logique métier"], 280, 275, 240, 120, "main")
d.group("g_dom", "Exemples de domaines et moteurs", 620, 70, 500, 610)
domains = [("install", "install.sh : dry-run, APPLY protégé"),
           ("update", "scripts/maintenance/update-system.sh"),
           ("kernel", "kernel-lifecycle.sh · secours Fedora"),
           ("backup", "backup-now.sh · restore.sh"),
           ("kvm", "Rocky DevOps · garde réseau"),
           ("doctor", "observation · essais actifs explicites"),
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
d = Diagram("chaine-qualification", "De la CI à la certification du poste",
            "Onze étapes : 1, CI au commit exact sur GitHub ; 2, contrôle Live USB sur le PC (PREINSTALL_ONLY, preuve "
            "exportée) ; 3, analyse des résultats et décision humaine GO ou NO-GO avant installation ; "
            "4, installation de Fedora et import de la preuve ; 5, baseline matérielle ; 6, dry-run ; "
            "7, sauvegarde Borg pré-APPLY vérifiée ; 8, APPLY protégé sur le PC physique ; 9, redémarrage sur Linux "
            "amont N ; 10, Gate 3 du système installé ; 11, Golden release. Une évolution du matériel, du code ou de la configuration "
            "invalide les preuves concernées.", 1440, 855)
d.group("g_before", "01  AVANT INSTALLATION", 40, 90, 408, 715)
d.group("g_change", "02  INSTALLER ET CONFIGURER", 513, 90, 414, 715)
d.group("g_after", "03  QUALIFIER ET PUBLIER", 992, 90, 408, 715)
steps_before = [(["1. CI au commit exact", "Contrats et laboratoires logiciels"], "box"),
                (["2. Gate 2 · Live USB", "PREINSTALL_ONLY · preuve exportée"], "main"),
                (["3. Revue et accord humain", "GO / NO-GO avant tout effacement"], "warn")]
steps_change = [(["4. Installer Fedora", "SSD système et preuve Live importée"], "box"),
                (["5. Certifier la baseline", "Contrôles de santé matérielle"], "box"),
                (["6. Exécuter le dry-run", "Plan sans modification réelle"], "box"),
                (["7. Sauvegarder avec Borg", "Pré-APPLY vérifié et canari restauré"], "box"),
                (["8. Exécuter l'APPLY", "Gardes et confirmation physique"], "main")]
steps_after = [(["9. Redémarrer", "Linux amont N sur le vrai PC"], "box"),
               (["10. Gate 3 · système installé", "Diagnostics et essais physiques"], "main"),
               (["11. Golden release", "Preuves courantes et certification"], "data")]
for i, (lines, style) in enumerate(steps_before):
    d.node(f"b{i}", lines, 63, 162 + i * 175, 362, 114, style)
for i, (lines, style) in enumerate(steps_change):
    d.node(f"m{i}", lines, 536, 142 + i * 128, 366, 102, style)
for i, (lines, style) in enumerate(steps_after):
    d.node(f"a{i}", lines, 1014, 162 + i * 175, 362, 114, style)
d.edge("stage_one_to_two", "g_before", "g_change")
d.edge("stage_two_to_three", "g_change", "g_after")
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
d.node("note", ["Profil désactivé par défaut", "REMOTE_ENABLE=false", "Gate 3 à faire"], 40, 330, 280, 100, "muted")
d.edge("e1", "tablet", "ts", both=True)
d.edge("e2", "ts", "pc", "SSH · flux vidéo", both=True)
d.edge("e3", "ts", "relay", "réveil")
d.edge("e4", "relay", "pc", "Magic Packet (LAN)", dashed=True)
diagrams.append(d)

# Desktop and portrait variants share one semantic model, not two sets of facts.
diagrams += [mobile_counterpart(original) for original in diagrams]

for d in diagrams:
    d.check()
    (out / f"{d.name}.svg").write_bytes(d.svg().encode("utf-8"))
    (out / f"{d.name}.drawio").write_bytes(d.drawio().encode("utf-8"))
    print("built", d.name)
