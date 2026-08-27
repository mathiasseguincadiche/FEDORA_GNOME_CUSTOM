# Validation intermédiaire Fedora 44 sous WSL2

## Objectif

Fedora 44 sous WSL2 sert de banc de validation **intermédiaire** entre GitHub Actions et la future workstation Fedora 44 bare-metal.

Ce profil valide notamment :

- l'identité Fedora 44 ;
- la visibilité du CPU hôte ;
- systemd sous WSL2 ;
- la disponibilité des outils de base (`bash`, `dnf`, `rpm`, `git`, `systemctl`) ;
- la cohérence du catalogue de modules et de ses dépendances ;
- la syntaxe des scripts suivis par Git ;
- la détection explicite de WSL2 ;
- le blocage du REAL APPLY et de toute certification hardware bare-metal.

Il ne remplace jamais la certification physique.

## Ce qui reste bare-metal uniquement

Les éléments suivants doivent apparaître comme `EXPECTED`/différés sous WSL2 et ne peuvent jamais devenir des preuves de certification physique :

- Intel Arc B580 PCI `8086:e20b` et pilote Linux natif `xe` ;
- inventaire/SMART/I/O des deux Crucial T705 ;
- GNOME Shell 50, Mutter, Wayland et timing écran 2560×1440/240 Hz ;
- suspend/resume et interactions BIOS/UEFI ;
- SELinux Enforcing comme état réel de la workstation ;
- KVM/libvirt `qemu:///system`, `devops-nat`, firewalld/nftables et isolation LAN ;
- certification hardware baseline.

## Installation WSL2

Depuis Windows 11 Pro, installer/mettre à jour WSL2 puis Fedora 44. Vérifier côté PowerShell que la distribution fonctionne en version WSL 2.

Dans Fedora 44 :

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

Le diagnostic WSL2 utilise trois statuts :

- `OK` : contrôle réellement validable sous WSL2 ;
- `EXPECTED` : contrôle volontairement différé au bare-metal ;
- `KO` : problème réel à corriger avant de poursuivre.

Les éléments `EXPECTED` ne doivent jamais être transformés manuellement en preuves `PASS`.

Pour vérifier aussi les contrats statiques localement :

```bash
for test in tests/test_*.sh; do
  bash "$test"
done
```

## Interdictions sous WSL2

Ne pas utiliser WSL2 pour approuver une machine réelle :

```bash
REAL_MACHINE_APPROVED="false"
```

Le moteur détecte automatiquement WSL2 et refuse `./install.sh --apply` avant les autres gates.

Les commandes d'enregistrement/certification de baseline sont également bloquées :

```bash
./diagnostics/baseline-doctor record-memory 6000 PASS
./diagnostics/baseline-doctor record-nvme-io PASS
./diagnostics/baseline-doctor record-suspend PASS
./diagnostics/baseline-doctor certify
```

Un snapshot read-only reste autorisé :

```bash
./diagnostics/baseline-doctor snapshot
```

## Chaîne de confiance

```text
GitHub Actions
      ↓
Fedora 44 WSL2
  scripts / Fedora / systemd / contrats / sécurité
      ↓
Fedora 44 bare-metal
  GPU / NVMe / GNOME / Wayland / KVM / suspend / APPLY
      ↓
runtime certification
```

Un `WSL2 VALIDATION PASS` signifie uniquement que la couche intermédiaire est saine. La workstation n'est `runtime-certified` qu'après les preuves physiques sur Fedora 44 native.
