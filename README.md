# FEDORA_GNOME_CUSTOM

**Golden Workstation 0.10.0** pour Fedora Linux 44 Workstation + GNOME 50, conçue pour une workstation AMD Ryzen + Intel Arc B580 avec deux NVMe T705, écran 2560×1440/240 Hz et environnement KVM/DevOps.

Le projet traite le poste de travail comme une infrastructure versionnée : **mesurer → préflight → sauvegarder → converger → redémarrer → certifier**.

## Contrat Golden Workstation

```text
FEDORA 44 WORKSTATION
        ↓
BASELINE MATÉRIELLE
  CPU / RAM / 2× T705 / Arc B580 / EDID
        ↓
PREFLIGHT NON-MUTANT + BACKUP RESTIC
        ↓
APPLY PROTÉGÉ
  kernel stable + firmware/microcode
  GNOME 50 / Wayland / codecs / applications
  Bash UX / portals / secrets / print-scan / VPN / power
  Arc Level Zero/OpenCL
  KVM sur /data + réseau privé
  lifecycle sécurisé + backup quotidien
        ↓
REBOOT
        ↓
CERTIFICATION BARE-METAL
  kernel réellement le plus récent disponible
  hardware + firmware + Arc B580/xe
  display actif 1440p/~240 Hz
  desktop/portals/lifecycle/Bash/apps/dock
  socle KVM host
  Nautilus cold-start
  5 cycles veille/réveil physiques uniques
  matrice software known-good
```

La CI complète cette certification ; elle ne prétend pas remplacer les preuves physiques.

## 0.10.0 — consolidation pré-1.0

Cette version privilégie le durcissement et la cohérence plutôt que de nouvelles fonctions :

- détection explicite VM/conteneur : aucun environnement virtualisé n'est considéré bare-metal ;
- `--dry-run` défini honnêtement comme **preflight non-mutant / plan de convergence** ;
- Kernel Vanilla `@kernel-vanilla/stable` : minimum 7.2.2 **et** dernier `kernel-core` disponible réellement installé ;
- fallback kernels Fedora conservé, Secure Boot fail-closed tant qu'un workflow de signature/MOK n'est pas implémenté ;
- preuves suspend/Nautilus liées au hardware + kernel + linux-firmware + firmware GPU + Mesa + Mutter + GNOME Shell ;
- KVM host obligatoire dans la certification finale lorsqu'il est activé ;
- réseau KVM IPv4 uniquement, activation IPv6 fail-closed tant que l'isolation dual-stack n'est pas certifiée ;
- Kickstart lié au **SHA Git exact** qui l'a généré ;
- Ubuntu DevOps : SSH par clé uniquement, Kubernetes 1.37.x, kind v0.33.0, Minikube v1.38.1, AWS CLI v2 signé/vérifié ;
- politique Flatpak explicite : mises à jour manuelles via GNOME Software ou `flatpak update`, jamais silencieuses par le projet ;
- provenance des applications documentée ;
- prétests externes Fedora/Flathub/Ubuntu exécutés chaque semaine ;
- draw.io intégré au catalogue professionnel et désormais enregistré dans une vraie release.

Voir `docs/PRE1_HARDENING.md` et `docs/SUPPLY_CHAIN.md`.

## Matériel ciblé

Le profil versionné attend notamment : Ryzen 7 7700, MSI MAG B850M Mortar WiFi, 48 Gio DDR5, Intel Arc B580 PCI `8086:e20b` sur pilote `xe`, deux Crucial T705 et écran ASUS 2560×1440/240 Hz. Cette précision est volontaire : un changement de composant majeur doit être traité comme une évolution de plateforme et recertifié.

## Kernel, Arc et stabilité

```bash
./diagnostics/kernel-doctor
./diagnostics/firmware-doctor
./diagnostics/hardware-components-doctor
./diagnostics/graphics-doctor
./diagnostics/arc-compute-doctor
```

Aucun `force_probe`, aucun dépôt GPU tiers, aucun tweak ASPM/APST/C-State aveugle. Mesa/Fedora reste la base ; le média Intel/RPM Fusion n'est convergé qu'en fonction des capacités mesurées par VA-API.

## GNOME et applications

GNOME reste proche de l'upstream Adwaita/libadwaita. Dash to Dock et AppIndicator apportent les fonctions manquantes sans multiplier les extensions cosmétiques. Blur My Shell et Just Perfection restent désactivés par défaut.

Dock certifié, ordre exact :

1. Nautilus
2. Brave
3. Ptyxis
4. Visual Studio Code
5. Bitwarden
6. Slack
7. LibreOffice
8. GNOME Software

Applications professionnelles supplémentaires : VLC, FileZilla, ONLYOFFICE, MarkText, Remmina et **draw.io**. La provenance est documentée dans `manifests/application-provenance.tsv` ; un paquet Flathub communautaire n'est jamais présenté comme un paquet officiel de l'éditeur.

## Bash host

Ptyxis ouvre Bash avec une couche légère et versionnée : `bash-completion`, `fzf`, `zoxide`, `direnv`, historique long/synchronisé, prompt Git local-only et quelques aliases Git/Docker/Kubernetes/Terraform non destructifs.

```bash
./diagnostics/shell-doctor
```

## Affichage et veille

Le repair GNOME cible 2560×1440, ~240 Hz, scale 1.0 et Full RGB. `display-doctor` valide le mode actif avec la tolérance configurée. Chaque cycle suspend certifié doit correspondre à une reprise physique unique et saine.

```bash
./diagnostics/nautilus-coldstart-doctor
./diagnostics/final-certification record-suspend
./diagnostics/final-certification certify
```

Une mise à jour du kernel, firmware GPU, Mesa, Mutter ou GNOME Shell invalide les anciennes preuves sensibles et impose une recertification.

## KVM / VMs

KVM reste `qemu:///system`, CLI-first, avec `/data` EXT4 sur le deuxième T705, Q35/OVMF/TPM/VirtIO et réseau privé `devops-nat` 192.168.50.0/24. Le garde nftables propre au projet bloque le forwarding entre VMs et LAN physique sans purger le firewall global.

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
scripts/kvm/runtime_certification.sh
```

L'Arc B580 reste propriétaire du host : aucun GPU passthrough.

### Ubuntu DevOps Ready

La VM Ubuntu Server 26.04 est provisionnée automatiquement pour `clone → build/test → containerize → deploy` : Git/GitHub/GitLab, Docker, Terraform, Ansible, AWS/Azure, kubectl/Helm/kind/Minikube/K9s, Node 22, Java 21/Maven, Python et outils Ops.

Le mot de passe créé à la génération reste pour console/sudo ; **SSH n'accepte que la clé publique injectée**. Aucun token cloud/forge n'est embarqué.

Voir `docs/UBUNTU_DEVOPS_READY.md`.

## Backup / recovery

Le pré-APPLY Restic est fail-closed : cible externe/remote, chiffrement, intégrité, restore test, snapshot lié au même commit et arrêt des VMs pour les disques. Les restores sont staging-first. La sauvegarde quotidienne tolère proprement l'absence du dépôt externe et n'inclut jamais le secret Restic.

```bash
./prepare-preapply-backup.sh
./diagnostics/backup-doctor
./diagnostics/daily-backup-doctor
```

## Installation

### 1. Kickstart piné

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le générateur affiche la cible, exige `EFFACER /dev/...` et inscrit le SHA Git courant. Le `%post` fetch/checkout exactement ce SHA et échoue si ce checkout ne peut pas être obtenu.

### 2. Baseline

```bash
./diagnostics/baseline-doctor snapshot
./diagnostics/baseline-doctor run-memory-test 5600
# profil mémoire BIOS à 6000 puis reboot
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

### 3. Preflight, backup, APPLY

```bash
./install.sh --dry-run
./prepare-preapply-backup.sh
# après revue : REAL_MACHINE_APPROVED=true dans config/local.conf
./install.sh --apply
```

Le gate exige bare-metal réel, Git propre, preflight du même commit, baseline valide, backup Restic du même commit et confirmation exacte.

## CI et gouvernance

Les workflows couvrent : contrats, ShellCheck, non-régression, résolution Fedora 44, intégration host Fedora 44 et vraie VM Ubuntu 26.04. Les prétests dépendant de services externes sont aussi programmés chaque semaine.

La politique cible pour `main` exige PR + checks verts et interdit force-push/suppression. Voir `docs/GITHUB_GOVERNANCE.md`. Le script `scripts/development/check-main-protection.sh` permet d'en contrôler l'état public ; l'activation du ruleset GitHub reste un réglage de dépôt hors de l'APPLY Fedora.

## Version

`0.10.0` — **Pre-1.0 Hardening & Consolidation**.

La 1.0 sera justifiée par une installation bare-metal complète, une certification finale réussie et une période d'usage réel stable — pas par l'ajout artificiel de fonctionnalités.

Documentation principale : `docs/INSTALLATION_GUIDE.md`, `docs/PRE1_HARDENING.md`, `docs/SUPPLY_CHAIN.md`, `docs/CI_VALIDATION.md`, `docs/GITHUB_GOVERNANCE.md`, `docs/BACKUP_RESTORE.md`, `docs/UBUNTU_DEVOPS_READY.md`, `docs/HARDWARE_BASELINE_CERTIFICATION.md` et `docs/HARDWARE_KVM_COMPLETION.md`.
