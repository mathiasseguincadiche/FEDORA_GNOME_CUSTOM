# Workstation Control Center

`./control.sh` est la façade opérateur de **FEDORA_GNOME_CUSTOM**. Elle reste mince : installation, Restic, DNF5, kernel lifecycle, KVM et diagnostics restent implémentés dans leurs moteurs dédiés.

```bash
./control.sh
```

`./menu.sh` lance la même interface pour compatibilité.

## Tableau de bord

```bash
./control.sh status
```

Le dashboard affiche :

- version et SHA Git ;
- Fedora / environnement runtime ;
- kernel courant et politique **N / N-1 · max 2** ;
- Intel Arc B580 / `xe` ;
- état Git ;
- second T705 `/data` EXT4 ;
- profil Gaming / Steam / Vulkan ;
- backup Restic ;
- certification Golden ;
- KVM / `devops-nat` ;
- besoin de reboot.

Une certification dont le fingerprint runtime ne correspond plus est affichée `STALE`.

## Validation en trois gates

```text
Gate 1 — Fedora 44 / WSL2
  système + logique, hardware DEFERRED
        ↓
Gate 2 — Fedora 44 GNOME / VirtualBox
  GNOME + UX, hardware DEFERRED
        ↓
Installation Fedora 44 bare-metal
        ↓
Gate 3 — vraie workstation
  hardware + runtime + KVM + Gaming + backup
        ↓
final-certification PASS
```

Statut :

```bash
./control.sh validate status
```

Gate 1 :

```bash
./control.sh validate gate1 run
./control.sh validate gate1 status
./control.sh validate export 1 /chemin/export
```

Gate 2, après import de Gate 1 :

```bash
./control.sh validate import /chemin/gate1-<commit>.json
./control.sh validate gate2 plan
./control.sh validate gate2 apply
./control.sh validate gate2 check
./control.sh validate gate2 sign
./control.sh validate export 2 /chemin/export
```

Gate 3, après installation bare-metal et import des preuves :

```bash
./control.sh validate import /chemin/gate1-<commit>.json
./control.sh validate import /chemin/gate2-<commit>.json
./control.sh validate gate3 status
./control.sh validate gate3 record-suspend
./control.sh validate gate3 certify
```

Seul Gate 3 peut produire `final-certification PASS` et `golden-release.json`.

Voir [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md).

## Installation

```bash
./control.sh install dry-run
./control.sh install backup
./control.sh install apply
```

Ces commandes délèguent à :

```text
install.sh --dry-run
prepare-preapply-backup.sh
install.sh --apply
```

Le chemin APPLY conserve ses protections : bare-metal, Git propre, baseline, cohérence dry-run/configuration/plan, **backup complet Restic** relu depuis le repository et confirmation opérateur.

## Mises à jour

```bash
./control.sh update check
./control.sh update all
./control.sh update dnf
./control.sh update flatpak
./control.sh update firmware
./control.sh update status
./control.sh update log
./control.sh update reboot
./control.sh update finalize
```

`update all` et `update dnf` préparent une transaction **DNF5 offline** après backup complet Restic.

```text
backup complet Restic
        ↓
résolution latest-stable Kernel Vanilla
        ↓
installonly_limit = 2
        ↓
dnf5 --refresh upgrade --offline
        ↓
./control.sh update reboot
        ↓
N = nouveau kernel par défaut
N-1 = kernel précédent
        ↓
./control.sh update finalize
```

La finalisation vérifie la transaction, `dnf5 check`, le kernel N, le défaut GRUB, applique `dnf5 remove --oldinstallonly --limit=2`, puis converge Flatpak si nécessaire et lance les diagnostics.

Pour le firmware : **aucun flash automatique**. `fwupdmgr` reste une surface d'inventaire/consultation.

## Kernel — N / N-1

La politique **Kernel Vanilla stable** est : latest stable direct, puis rétention N / N-1.

- `N` : dernier stable installé et défaut GRUB ;
- `N-1` : rollback ;
- maximum deux versions `kernel-core` ;
- aucun fallback Fedora permanent ;
- recovery Fedora explicite uniquement.

```bash
./control.sh kernel status
./control.sh kernel doctor
./control.sh kernel install-latest
./control.sh kernel prune
./control.sh kernel rollback
./control.sh kernel rollback-fedora
```

`rollback` sélectionne N-1 sans supprimer N. `rollback-fedora` sert uniquement à une récupération d'urgence.

## Diagnostics

```bash
./control.sh doctor all
./control.sh doctor baseline
./control.sh doctor kernel
./control.sh doctor graphics
./control.sh doctor storage
./control.sh doctor data
./control.sh doctor display
./control.sh doctor gnome
./control.sh doctor apps
./control.sh doctor media
./control.sh doctor gaming
./control.sh doctor kvm
./control.sh doctor backup
```

`doctor data` contrôle le second T705 EXT4 et les racines `/data/Documents`, `/data/Projets`, `/data/ISO`, `/data/Jeux`.

`doctor gaming` contrôle le profil Gaming canonique, `/data/Jeux`, Steam/Vulkan et les invariants Arc/Wayland/display disponibles sur bare-metal.

## KVM / machines virtuelles

### Diagnostic et réseau

```bash
./control.sh kvm status
./control.sh kvm guard-check
./control.sh kvm guard-reconcile
./control.sh kvm certify
./control.sh kvm nautilus-refresh
```

Le guard reste fail-closed. `guard-reconcile` passe d'abord par un état restrictif avant de reconstruire les règles normales.

### Création Ubuntu DevOps

Dans le menu interactif, **KVM → Créer Ubuntu DevOps** demande le chemin de l'image cloud et permet de préciser une clé SSH ou une clé Canonical locale.

CLI :

```bash
./control.sh kvm create-ubuntu \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

`SHA256SUMS` et `SHA256SUMS.gpg` sont attendus à côté de l'image par défaut et sont authentifiés avant création du disque.

### Création Windows 11

Dans le menu interactif, **KVM → Créer Windows 11** demande :

- ISO Windows ;
- ISO VirtIO ;
- SHA-256 Windows de confiance ;
- SHA-256 VirtIO de confiance.

Les quatre entrées sont obligatoires.

CLI :

```bash
./control.sh kvm create-windows \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso \
  --windows-sha256 '<sha256-windows-de-confiance>' \
  --virtio-sha256 '<sha256-virtio-de-confiance>'
```

`control.sh` transmet ces arguments au moteur durci `scripts/kvm/create_windows11_vm.sh`. Les hashes sont vérifiés avant `qemu-img create`.

Voir [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) et [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md).

## Backup / restauration

```bash
./control.sh backup now
./control.sh backup now-with-vms
./control.sh backup daily
./control.sh backup list
./control.sh backup check
./control.sh backup deep
./control.sh backup restore latest
./control.sh backup dr-plan
./control.sh backup prune
```

Les restores restent staging-first. Les VM doivent être arrêtées pour le backup de leurs disques.

## Certification

```bash
./control.sh cert status
./control.sh cert record-suspend
./control.sh cert certify
./control.sh cert baseline-status
./control.sh cert baseline-certify
```

La certification finale exige la chaîne Gate 1 → Gate 2, les preuves physiques, cinq cycles veille/réveil, hardware/display, `/data`, Gaming, backup et KVM selon le profil canonique.

### Archive Golden longue durée

Après certification réelle :

```bash
./control.sh cert archive /mnt/archive/golden-2026 \
  /chemin/Fedora-Workstation-Live-44.iso \
  /chemin/offline-rpm-flatpak-cache \
  /chemin/Windows11.iso \
  /chemin/virtio-win.iso
```

Le moteur exige un certificat PASS courant et scelle les payloads fournis par l'opérateur. Il ne télécharge aucun média externe automatiquement.

## Logs et rétention

```text
logs = 90 jours
reports = 180 jours
state/ = conservé
state/releases/ = conservé
```

```bash
./control.sh logs retention
./control.sh logs prune
```

Les preuves Golden et `state/releases/` ne sont jamais supprimées par cette rétention.

## Couleurs

```bash
NO_COLOR=1 ./control.sh status
```

`NO_COLOR=1` désactive les couleurs ANSI.
