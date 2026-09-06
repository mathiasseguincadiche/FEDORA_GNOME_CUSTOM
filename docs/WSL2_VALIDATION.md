# GATE 1 — Fedora 44 sous WSL2

## Objectif

Fedora 44 sous WSL2 est le **GATE 1 officiel** de la chaîne de validation :

```text
GitHub Actions
      ↓
GATE 1 — Fedora 44 / WSL2
      ↓ preuve JSON portable
GATE 2 — Fedora 44 GNOME / VirtualBox
      ↓ preuve JSON liée à Gate 1
GATE 3 — Fedora 44 / bare-metal
      ↓
Golden Workstation
```

Gate 1 valide la **couche système et la logique du projet**. Il ne valide jamais le matériel physique de la workstation.

Le protocole complet est défini dans [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md).

## Ce que Gate 1 valide

- identité Fedora 44 ;
- détection explicite WSL2 ;
- visibilité CPU/mémoire disponible dans WSL2 ;
- systemd sous WSL2 ;
- outils de base (`bash`, `dnf`, `rpm`, `git`, `grep`, `awk`, `free`, `lscpu`, `lsblk`, `findmnt`, `systemctl`) ;
- schéma de configuration ;
- catalogue et plan de modules ;
- totalité des contrats listés par `.github/workflows/tests.yml` ;
- comportement dry-run et suppression des mutations ;
- logique fail-closed ;
- logique Kernel Vanilla candidat/certifié ;
- logique APPLY/Restic/KVM ;
- contrats/fixtures B580, T705 et EDID sans prétendre observer le matériel réel ;
- blocage du REAL APPLY et de la certification bare-metal.

La preuve produite porte explicitement :

```text
hardware_certification=DEFERRED
```

## Ce qui reste hors de portée WSL2

Sous WSL2, les éléments suivants sont volontairement différés :

- DING réellement rendu sur le bureau GNOME et action Show Desktop avec de vraies fenêtres — **GATE 2 VirtualBox puis bare-metal** ;
- Intel Arc B580 PCI `8086:e20b` et pilote Linux natif `xe` — bare-metal ;
- ReBAR et PCIe x8 réels — bare-metal ;
- inventaire/SMART/I/O/PCIe x4 des deux Crucial T705 — bare-metal ;
- EDID physique de l'écran ASUS et 2560×1440/~240 Hz — bare-metal ;
- VA-API/OpenCL exécutés sur la vraie B580 — bare-metal ;
- BIOS/UEFI et firmware/microcode — bare-metal ;
- suspend/resume physique — bare-metal ;
- SELinux Enforcing comme état réel de la workstation ;
- KVM/libvirt `qemu:///system`, `devops-nat`, firewalld/nftables et isolation LAN réelle ;
- certification finale Golden Workstation.

Un `GATE 1 PASS` signifie donc : **la logique est saine dans son périmètre**. Il ne signifie jamais « matériel validé ».

## Préparer WSL2

Depuis Windows 11 Pro, installer/mettre à jour WSL2 et Fedora 44. Vérifier que la distribution s'exécute bien en WSL 2.

Dans Fedora :

```bash
cat /etc/os-release
uname -a
systemd-detect-virt || true
systemctl is-system-running || true
```

### Installer le socle CLI requis

L'image Fedora WSL peut être plus minimale qu'une Fedora Workstation. Installer explicitement les outils utilisés par le protocole :

```bash
sudo dnf upgrade --refresh -y
sudo dnf install -y \
  git \
  gawk \
  procps-ng \
  util-linux \
  grep \
  curl \
  jq \
  tar \
  gzip
```

Le paquet Fedora `gawk` fournit la commande `awk`. `procps-ng` fournit notamment `free`, et `util-linux` fournit notamment `lscpu`, `lsblk` et `findmnt`.

Vérification rapide :

```bash
for cmd in git awk free lscpu lsblk findmnt grep; do
  command -v "$cmd" || echo "MANQUANT: $cmd"
done
```

Aucune ligne `MANQUANT` ne doit apparaître.

Le `wsl2-doctor` vérifie ce socle **avant** sa première utilisation et transforme une dépendance absente en `KO Core tools` lisible au lieu de terminer brutalement avec un code 127.

## Utiliser exactement le commit à qualifier

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
git switch main
git pull --ff-only
git status --short
git rev-parse HEAD
```

Le worktree doit être propre. Le même SHA devra être utilisé à Gate 2 puis Gate 3.

## Exécuter Gate 1

Commande officielle :

```bash
./control.sh validate gate1 run
```

Le runner exécute notamment :

```bash
./diagnostics/wsl2-doctor
./scripts/config/validate-config.sh config
```

puis tous les tests de contrats explicitement déclarés dans `.github/workflows/tests.yml`.

Statut :

```bash
./control.sh validate gate1 status
```

La preuve locale est créée sous :

```text
state/validation/outbox/gate1-<commit>.json
```

## Exporter vers Gate 2

Par exemple vers Windows :

```bash
./control.sh validate export 1 /mnt/c/GoldenValidation
```

Deux fichiers sont transférés :

```text
gate1-<commit>.json
gate1-<commit>.json.sha256
```

Gate 2 rejettera la preuve si elle ne correspond pas à son commit/module-plan courant.

## Production dry-run depuis WSL2

On peut également observer le comportement du preflight production :

```bash
./install.sh --dry-run
```

Ce test utilise volontairement le **même preflight production** que le futur hôte bare-metal. Il n'est donc pas censé convertir WSL2 en pseudo-workstation.

La première baseline production exige notamment :

```text
/sys/firmware/efi
```

WSL2 n'expose pas cette preuve UEFI bare-metal. Un arrêt sur `baseline.preflight` est donc **EXPECTED sous WSL2**.

Le contrat attendu est :

```text
PREFLIGHT FAIL rc=<non-zero>
process exit code=<same non-zero>
```

Un blocage UEFI/bare-metal propre est une preuve que le preflight refuse correctement l'environnement. En revanche :

```text
PREFLIGHT FAIL rc=0
process exit code=0
```

est un **KO logiciel**, car un preflight échoué ne doit jamais être signalé comme succès au shell ou à la CI.

Le dry-run WSL2 sert donc à vérifier le fail-closed et à observer le premier blocage production ; il ne remplace pas le dry-run complet obligatoirement rejoué sur Fedora bare-metal avant APPLY.

## Interdictions sous WSL2

Ne jamais utiliser WSL2 pour approuver une machine réelle :

```text
REAL_MACHINE_APPROVED=false
```

Le moteur détecte automatiquement WSL2 et refuse :

```bash
./install.sh --apply
```

Le LAB VirtualBox doit également refuser WSL2 :

```bash
./scripts/lab/apply-gnome-virtualbox.sh --check
```

Les commandes qui produisent de vraies preuves RAM/NVMe ou une certification bare-metal doivent être exécutées uniquement sur Fedora native. Sous WSL2, les contrôles hardware ne sont que des validations de logique/fixtures.

Ne créer jamais manuellement des fichiers de preuve ou markers pour transformer WSL2 en pseudo bare-metal.

## Passage à Gate 2

Gate 1 est terminé seulement lorsque :

```text
Gate 1 proof = PASS
hardware_certification = DEFERRED
worktree = clean
preuve exportée avec SHA-256
```

La suite se fait dans [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md).
