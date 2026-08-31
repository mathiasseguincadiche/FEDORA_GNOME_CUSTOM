# Validation intermédiaire Fedora 44 sous WSL2

## Objectif

Fedora 44 sous WSL2 sert de banc de validation **intermédiaire** entre GitHub Actions et la workstation Fedora 44 bare-metal.

Ce profil peut valider :

- l'identité Fedora 44 ;
- la visibilité du CPU hôte ;
- systemd sous WSL2 ;
- les outils de base (`bash`, `dnf`, `rpm`, `git`, `systemctl`) ;
- la cohérence du catalogue de modules ;
- la syntaxe et une partie des contrats statiques ;
- la détection explicite de WSL2 ;
- le blocage du REAL APPLY et de la certification hardware bare-metal.

Il ne remplace jamais la certification physique.

## Ce qui reste bare-metal uniquement

Sous WSL2, les éléments suivants sont volontairement différés :

- Intel Arc B580 PCI `8086:e20b` et pilote Linux natif `xe` ;
- inventaire/SMART/I/O des deux Crucial T705 ;
- GNOME Shell 50, Mutter, Wayland et timing 2560×1440/240 Hz ;
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
- `EXPECTED` : contrôle volontairement différé au bare-metal ;
- `KO` : problème réel dans ce qui devrait fonctionner sous WSL2.

Un statut `EXPECTED` n'est jamais une preuve physique.

Pour exécuter les contrats statiques locaux :

```bash
for test in tests/test_*.sh; do
  bash "$test"
done
```

Certains tests d'intégration Fedora/VM restent mieux couverts par GitHub Actions que par WSL2.

## Interdictions sous WSL2

Ne jamais utiliser WSL2 pour approuver une machine réelle :

```text
REAL_MACHINE_APPROVED=false
```

Le moteur détecte automatiquement WSL2 et refuse :

```bash
./install.sh --apply
```

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
Fedora 44 WSL2
scripts / Fedora / systemd / contrats / détection runtime
      ↓
Fedora 44 bare-metal
GPU / NVMe / GNOME / Wayland / KVM / suspend / APPLY
      ↓
runtime certification
```

Un `WSL2 VALIDATION PASS` signifie uniquement que la couche intermédiaire est saine. La workstation devient Golden runtime-certified uniquement après les preuves physiques sur Fedora 44 native.
