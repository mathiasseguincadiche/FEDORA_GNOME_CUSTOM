# Validation intermédiaire Fedora 44 sous WSL2

## Objectif

Fedora 44 sous WSL2 sert de banc de validation **intermédiaire** entre GitHub Actions et le GATE 2 Fedora 44 GNOME/VirtualBox, puis la workstation Fedora 44 bare-metal.

Ce profil peut valider :

- l'identité Fedora 44 ;
- la visibilité du CPU hôte ;
- systemd sous WSL2 ;
- les outils de base (`bash`, `dnf`, `rpm`, `git`, `grep`, `awk`, `free`, `lscpu`, `lsblk`, `findmnt`, `systemctl`) ;
- la cohérence du catalogue de modules ;
- la syntaxe et une partie des contrats statiques ;
- la détection explicite de WSL2 ;
- le blocage du REAL APPLY et de la certification hardware bare-metal ;
- le contrat statique du LAB GNOME VirtualBox sans prétendre exécuter sa preuve graphique.

Il ne remplace jamais la certification VirtualBox graphique ni la certification physique.

## Ce qui reste hors de portée WSL2

Sous WSL2, les éléments suivants sont volontairement différés :

- DING réellement rendu sur le bureau GNOME et action Show Desktop avec de vraies fenêtres — **GATE 2 VirtualBox puis bare-metal** ;
- Intel Arc B580 PCI `8086:e20b` et pilote Linux natif `xe` — bare-metal ;
- inventaire/SMART/I/O des deux Crucial T705 — bare-metal ;
- GNOME Shell 50, Mutter, Wayland et timing 2560×1440/240 Hz physique ;
- suspend/resume et interactions BIOS/UEFI ;
- SELinux Enforcing comme état réel de la workstation ;
- KVM/libvirt `qemu:///system`, `devops-nat`, firewalld/nftables et isolation LAN réelle ;
- baseline RAM/NVMe bare-metal ;
- certification finale Golden Workstation.

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

L'image Fedora WSL peut être plus minimale qu'une Fedora Workstation. Installer explicitement les outils utilisés par le protocole avant de lancer les diagnostics :

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

Le `wsl2-doctor` actuel vérifie ce socle **avant** sa première utilisation et transforme une dépendance absente en `KO Core tools` lisible au lieu de terminer brutalement avec un code 127.

## Cloner le dépôt

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
git checkout main
git pull --ff-only
cat VERSION
git rev-parse HEAD
```

## Validation recommandée

```bash
./diagnostic.sh
./diagnostics/wsl2-doctor
```

Le diagnostic WSL2 utilise :

- `OK` : contrôle réellement validable sous WSL2 ;
- `EXPECTED` : contrôle volontairement différé à un gate ultérieur ;
- `KO` : problème réel dans ce qui devrait fonctionner sous WSL2.

Un statut `EXPECTED` n'est jamais une preuve VirtualBox ou physique.

### Production dry-run depuis WSL2

Le protocole de prévalidation peut aussi lancer :

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

Le dry-run WSL2 sert donc à vérifier le fail-closed et à observer le premier blocage production ; il ne remplace pas le dry-run complet qui sera obligatoirement rejoué sur Fedora bare-metal avant APPLY.

Pour exécuter les contrats statiques locaux :

```bash
for test in tests/test_*.sh; do
  bash "$test"
done
```

Le contrat `tests/test_virtualbox_gnome_lab_contract.sh` est statique sous WSL2 : il vérifie la séparation architecture/sécurité mais **ne constitue pas un PASS graphique GATE 2**. Les tests d'intégration Fedora/VM restent mieux couverts par GitHub Actions que par WSL2.

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

Cette commande doit terminer avec le code de sécurité du LAB hors VirtualBox ; il ne faut pas chercher à contourner ce refus.

Les commandes qui produisent de vraies preuves RAM/NVMe ou une certification bare-metal doivent être exécutées uniquement sur Fedora native. Sous WSL2, utiliser seulement les modes non destructifs/read-only prévus, par exemple :

```bash
./diagnostics/baseline-doctor status
./diagnostics/baseline-doctor snapshot
```

Ne créer jamais manuellement des fichiers de preuve ou markers pour transformer un environnement WSL2 en pseudo bare-metal.

## Chaîne de confiance

```text
GitHub Actions
      ↓
GATE 1 — Fedora 44 WSL2
scripts / Fedora / systemd / contrats / détection runtime
      ↓
GATE 2 — Fedora 44 GNOME 50 / VirtualBox
DING / ~/Bureau / Corbeille / Show Desktop / Super+D / persistance
      ↓
GATE 3 — Fedora 44 bare-metal
GPU / NVMe / GNOME physique / KVM / suspend / APPLY
      ↓
runtime certification
```

Un `WSL2 VALIDATION PASS` signifie uniquement que la couche GATE 1 est saine. La workstation devient Golden runtime-certified uniquement après GATE 2 puis les preuves physiques sur Fedora 44 native.
