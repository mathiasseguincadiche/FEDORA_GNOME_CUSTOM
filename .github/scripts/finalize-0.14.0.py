from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def write(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")


def replace(path, old, new, required=True):
    text = read(path)
    if old not in text:
        if required and new not in text:
            raise SystemExit(f"expected text not found in {path}: {old!r}")
        return
    write(path, text.replace(old, new))


# Release metadata: prepend only; never rewrite historical entries.
path = "CHANGELOG.md"
text = read(path)
if "## 0.14.0 — 2026-09-03" not in text:
    entry = """## 0.14.0 — 2026-09-03

- **Final Hardening / Release Candidate** : fermeture des écarts pré-1.0 sans ajout d'un nouveau socle fonctionnel.
- Runtime fail-closed : un environnement dont le bare-metal n'est pas positivement prouvé devient `unknown` et ne peut pas ouvrir l'APPLY.
- Orchestrateur durci : chaque module doit fournir `precheck`, `plan`, `apply` et `postcheck`; un APPLY en échec conserve son code retour et produit un rapport durable de convergence partielle.
- Correction Arc B580/VA-API : le render node est résolu par PCI `8086:e20b` au lieu de supposer `/dev/dri/renderD128` sur un HOST multi-GPU.
- DING review `74408`, Show Desktop Plus review `70326` et Resource Monitor review `70909` sont vérifiés par SHA-256 exact avant installation.
- Backup quotidien lié au SHA réellement appliqué; le prune reste manuel mais applique la rétention aux snapshots `full` et `daily`.
- Kickstart : serveur `sshd` HOST désactivé, `openssh-clients` conservé pour les connexions HOST → VM.
- Guard KVM étendu aux routes IPv4 non-default du HOST afin de bloquer LAN, VPN, réseaux d'entreprise et tunnels routés tout en conservant la sortie Internet via la route par défaut.
- Les Flatpaks `community-unverified` doivent être présents dans une allowlist versionnée explicite.
- Service KVM nftables renforcé avec sandbox systemd et capacités réseau bornées.
- Choix Golden confirmés : pas de LUKS imposé, pas de Secure Boot HOST, `kernel-vanilla/stable` latest-stable avec kernels Fedora conservés comme fallback.
- Ajout de `SECURITY.md`, `CODEOWNERS`, d'un template de PR et de contrats comportementaux supplémentaires pour le hardening.
- Documentation synchronisée avec Resource Monitor, la supply-chain GNOME, la rétention Restic et la portée LAN/VPN du guard KVM.

"""
    if not text.startswith("# Changelog\n\n"):
        raise SystemExit("unexpected CHANGELOG header")
    write(path, text.replace("# Changelog\n\n", "# Changelog\n\n" + entry, 1))

# Documentation portal: Resource Monitor belongs to GATE 2 GNOME convergence.
replace(
    "docs/README.md",
    "vraie convergence graphique DING + Show Desktop dans une VM strictement identifiée VirtualBox",
    "vraie convergence graphique DING + Show Desktop + Resource Monitor dans une VM strictement identifiée VirtualBox",
    required=False,
)

# Backup lifecycle and disaster-recovery secret contract.
path = "docs/BACKUP_RESTORE.md"
text = read(path)
if "Le timer est lié au **SHA appliqué**" not in text:
    text = text.replace(
        "Le script refuse une source XDG ambiguë qui résoudrait directement vers `$HOME`,",
        "Le timer est lié au **SHA appliqué** : si le checkout versionné change ou si ses fichiers suivis sont modifiés sans nouvel APPLY, le backup automatique bloque au lieu de sourcer silencieusement un runtime différent.\n\nLe script refuse une source XDG ambiguë qui résoudrait directement vers `$HOME`,",
    )
text = text.replace(
    "Pour appliquer la rétention 7 daily / 4 weekly / 6 monthly en même temps :",
    "Pour appliquer **manuellement** la rétention 7 daily / 4 weekly / 6 monthly aux snapshots `full` **et** `daily` :",
)
text = text.replace(
    "scripts/backup/backup-now.sh --include-vms --prune",
    "scripts/backup/backup-now.sh --prune\n# ou, pour inclure aussi les disques VM arrêtés :\nscripts/backup/backup-now.sh --include-vms --prune",
)
text = text.replace(
    "Le pruning n'est jamais lancé automatiquement par la convergence.",
    "Le pruning n'est jamais lancé automatiquement par la convergence ni par le timer quotidien. `--prune` applique les deux politiques `forget` (`full` puis `daily`) puis exécute un unique `restic prune`.",
)
if "## Secret de récupération" not in text:
    text = text.replace(
        "## Disaster Recovery\n",
        "## Secret de récupération\n\nLa passphrase Restic n'est volontairement jamais incluse dans les snapshots. Une **copie de récupération hors machine** (gestionnaire de mots de passe ou coffre indépendant) est donc obligatoire pour qu'un dépôt Restic reste exploitable après perte totale du SSD système. Le projet ne copie jamais ce secret automatiquement.\n\n## Disaster Recovery\n",
    )
write(path, text)

# Supply-chain: exact content digests and explicit community exceptions.
path = "docs/SUPPLY_CHAIN.md"
text = read(path)
if "## Extensions GNOME revues" not in text:
    text += """

## Extensions GNOME revues

Les extensions téléchargées directement depuis GNOME Extensions sont verrouillées par review, version **et SHA-256** :

```text
DING 74408 / v95             48175f0b5c1f8a1a724d761198c91d6994e91e28aec685605ae6a240b0a95aae
Show Desktop Plus 70326 / v8 9ceab00be63b93c4eade16cf804bf4edd587632750aa89b78e317673fd6016a9
Resource Monitor 70909 / v28  18f49cf20bd8f96f22f6048d7404e51cb414c1aea94ca16d0c2ad3634e9d8bf2
```

Un changement de contenu derrière une URL review existante est refusé **avant** `gnome-extensions install`.

## Exceptions Flathub communautaires

Les entrées classées `community-unverified` dans `manifests/application-provenance.tsv` ne sont installables que si leur App ID figure aussi dans `UNVERIFIED_FLATHUB_ALLOWLIST`. Cette allowlist transforme l'exception de confiance en décision versionnée et testable au lieu d'une simple note documentaire.
"""
write(path, text)

# KVM documentation: current implementation protects all explicit non-default IPv4 HOST routes.
path = "docs/KVM_NETWORK.md"
text = read(path)
text = text.replace("qui filtre le LAN", "qui filtre les réseaux protégés du HOST")
text = text.replace("VM → LAN uplink     bloqué", "VM → LAN/VPN/route HOST protégée   bloqué")
text = text.replace("LAN uplink → VM     bloqué en forwarding", "LAN/VPN/route HOST → VM             bloqué en forwarding")
text = text.replace("nftables guard : interdit le LAN uplink", "nftables guard : interdit LAN/VPN/routes HOST protégées")
text = text.replace(
    "les VM de laboratoire ne doivent pas pouvoir atteindre directement le réseau local du poste.",
    "les VM de laboratoire ne doivent pas pouvoir atteindre directement les réseaux privés/routés connus du HOST (LAN, VPN, entreprise, tunnels explicites).",
)
text = text.replace(
    "Il découvre les réseaux IPv4 directement attachés à l'uplink courant et construit le set :\n\n```text\nblocked_physical_ipv4\n```",
    "Il lit la table de routage IPv4 principale du HOST, exclut la route `default`, le loopback et `devops-nat`, puis construit le set :\n\n```text\nblocked_host_ipv4\n```",
)
text = text.replace("virbr50 → réseau uplink      REJECT", "virbr50 → réseau HOST protégé      REJECT")
text = text.replace("réseau uplink → virbr50      DROP", "réseau HOST protégé → virbr50      DROP")
text = text.replace(
    "Le HOST lui-même peut toujours parler aux VM parce que ce trafic n'est pas du forwarding entre le LAN physique et `virbr50`.",
    "Le HOST lui-même peut toujours parler aux VM parce que ce trafic n'est pas du forwarding entre une route protégée et `virbr50`.",
)
old_scope = """## Portée exacte de « LAN physique »

Le contrat courant bloque les **réseaux IPv4 directement connectés aux interfaces physiques et l'uplink IPv4 par défaut** détectés par le host.

Il ne prétend pas, à lui seul, constituer une politique générique de segmentation pour toutes les routes d'entreprise, tous les VPN ou tous les tunnels qu'un opérateur pourrait ajouter ultérieurement.

Si une future version doit interdire aussi des réseaux routés/VPN spécifiques, ils devront être intégrés explicitement au contrat et recertifiés. Cette précision évite de présenter une portée de sécurité plus large que l'implémentation réelle.
"""
new_scope = """## Portée exacte des réseaux protégés

Le contrat courant bloque toutes les **routes IPv4 explicites non-default de la table principale du HOST** : réseaux directement connectés, LAN, routes VPN/entreprise et tunnels explicitement routés. Le CIDR KVM lui-même et le loopback sont exclus.

La route IPv4 `default` reste volontairement hors du set afin de conserver **VM → Internet**. Un nouveau VPN ou une nouvelle route d'entreprise déclenche le reconcile via NetworkManager ; si la nouvelle table ne peut pas être découverte, validée ou appliquée, le guard conserve le mode `emergency` qui bloque tout forwarding via `virbr50`.
"""
if old_scope in text:
    text = text.replace(old_scope, new_scope)
text = text.replace("redécouverte uplink + CIDR", "redécouverte des routes HOST protégées")
text = text.replace("physical_networks=192.168.1.0/24", "protected_networks=192.168.1.0/24")
text = text.replace("blocked_physical_ipv4", "blocked_host_ipv4")
text = text.replace("normal block VM to physical LAN", "normal block VM to protected host networks")
text = text.replace("normal block physical LAN to VM", "normal block protected host networks to VM")
text = text.replace("tous les CIDR uplink détectés", "tous les CIDR HOST protégés détectés")
write(path, text)

# Runtime certification and virtualization doctor must consume the new KVM guard vocabulary.
path = "scripts/kvm/runtime_certification.sh"
text = read(path)
text = text.replace("normal block VM to physical LAN", "normal block VM to protected host networks")
text = text.replace("normal block physical LAN to VM", "normal block protected host networks to VM")
text = text.replace("physical_networks=", "protected_networks=")
text = text.replace("physical_networks", "protected_networks")
text = text.replace("physical_cidrs", "protected_cidrs")
text = text.replace("KVM LAN CIDR coverage", "KVM protected CIDR coverage")
text = text.replace("every discovered uplink CIDR", "every discovered protected HOST CIDR")
text = text.replace("no connected physical uplink CIDR to prove", "no protected non-default HOST CIDR to prove")
write(path, text)

path = "diagnostics/virtualization-doctor"
text = read(path)
text = text.replace("grep -Fq 'block VM to physical LAN'", "grep -Fq 'block VM to protected host networks'")
text = text.replace("record OK 'LAN isolation' enforced", "record OK 'Host-network isolation' 'LAN/VPN routes enforced'")
text = text.replace("record KO 'LAN isolation' 'guard rule missing'", "record KO 'Host-network isolation' 'guard rule missing'")
text = text.replace("record WARN 'LAN isolation' 'guard service active; privileged nft inspection unavailable'", "record WARN 'Host-network isolation' 'guard service active; privileged nft inspection unavailable'")
text = text.replace("record KO 'LAN isolation' 'guard inactive'", "record KO 'Host-network isolation' 'guard inactive'")
write(path, text)

# Control Center: manual retention is an explicit operator action, never automatic.
path = "lib/control_center.sh"
text = read(path)
if "cc_option 9 'Appliquer rétention Restic'" not in text:
    text = text.replace(
        "    cc_option 8 'Plan Disaster Recovery'\n    cc_option 0 'Retour'",
        "    cc_option 8 'Plan Disaster Recovery'\n    cc_option 9 'Appliquer rétention Restic' 'manuel: full + daily'\n    cc_option 0 'Retour'",
    )
    text = text.replace(
        "      8) cc_interactive_exec 'PLAN DISASTER RECOVERY' \"$REPO_ROOT/scripts/backup/disaster-recovery.sh\" ;;\n      0) return 0 ;;",
        "      8) cc_interactive_exec 'PLAN DISASTER RECOVERY' \"$REPO_ROOT/scripts/backup/disaster-recovery.sh\" ;;\n      9)\n        if cc_confirm 'Créer un backup complet puis appliquer la rétention Restic full + daily ?'; then\n          cc_interactive_exec 'RÉTENTION RESTIC MANUELLE' \"$REPO_ROOT/scripts/backup/backup-now.sh\" --prune\n        fi\n        ;;\n      0) return 0 ;;",
    )
text = text.replace(
    "./control.sh backup now|now-with-vms|daily|list|check|deep|restore [snapshot]|dr-plan",
    "./control.sh backup now|now-with-vms|daily|list|check|deep|restore [snapshot]|dr-plan|prune",
)
if "        prune) \"$REPO_ROOT/scripts/backup/backup-now.sh\" --prune ;;" not in text:
    text = text.replace(
        "        dr-plan) \"$REPO_ROOT/scripts/backup/disaster-recovery.sh\" ;;",
        "        dr-plan) \"$REPO_ROOT/scripts/backup/disaster-recovery.sh\" ;;\n        prune) \"$REPO_ROOT/scripts/backup/backup-now.sh\" --prune ;;",
    )
write(path, text)

path = "docs/CONTROL_CENTER.md"
text = read(path)
if "rétention Restic manuelle" not in text:
    text = text.replace(
        "- plan Disaster Recovery.",
        "- plan Disaster Recovery ;\n- rétention Restic manuelle `full + daily` via `backup prune`.",
    )
if "./control.sh backup prune" not in text:
    text = text.replace(
        "./control.sh backup restore latest\n",
        "./control.sh backup restore latest\n./control.sh backup prune\n",
    )
write(path, text)

# Keep contract tests aligned with operator-visible capabilities.
path = "tests/test_workstation_control_center_contract.sh"
text = read(path)
if 'backup prune' not in text:
    text = text.replace(
        'grep -Fq "\\"\\$REPO_ROOT/scripts/backup/restore.sh\\" restore" "$ROOT/lib/control_center.sh"',
        'grep -Fq "\\"\\$REPO_ROOT/scripts/backup/restore.sh\\" restore" "$ROOT/lib/control_center.sh"\ngrep -Fq "backup-now.sh\\\" --prune" "$ROOT/lib/control_center.sh"',
    )
write(path, text)

path = "tests/test_backup_recovery_contract.sh"
text = read(path)
if "fedora-gnome-custom-daily" not in text.split("echo 'backup/recovery contract: PASS'", 1)[0]:
    text = text.replace(
        "echo 'backup/recovery contract: PASS'",
        "grep -Fq 'fedora-gnome-custom-full fedora-gnome-custom-daily' \"$ROOT/scripts/backup/backup-now.sh\"\ngrep -Fq 'FEDORA_GNOME_CUSTOM_APPLIED_SHA' \"$ROOT/scripts/backup/daily-user-backup.sh\"\n\necho 'backup/recovery contract: PASS'",
    )
write(path, text)

print("0.14.0 finalization patch applied")
