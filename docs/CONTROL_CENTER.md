# Workstation Control Center

Le **Workstation Control Center** est l'interface opérateur principale de FEDORA_GNOME_CUSTOM. Il rassemble les entrypoints existants sans déplacer leur logique métier ni affaiblir leurs garde-fous.

```bash
./control.sh
```

`./menu.sh` reste disponible comme alias de compatibilité et ouvre exactement le même centre de contrôle.

## Principes

Le Control Center est volontairement une **façade mince** :

```text
                         ┌──────────────────────────┐
                         │       control.sh         │
                         │  interface + dispatcher  │
                         └────────────┬─────────────┘
                                      │
       ┌───────────────┬──────────────┼──────────────┬───────────────┐
       ▼               ▼              ▼              ▼               ▼
   install.sh      diagnostics/*  scripts/backup  scripts/kernel  scripts/kvm
       │                              │
       └──────────────────────────────┴── scripts/maintenance
```

Le cockpit :

- ne réimplémente pas `apply_gate_open` ;
- ne contourne pas la baseline matérielle ;
- ne fabrique aucune preuve bare-metal en VM/WSL2/CI ;
- ne remplace pas les checks Restic existants ;
- ne flashe jamais un firmware automatiquement ;
- ne fait jamais passer `mainline`, `-rc` ou `linux-next` dans le profil Golden ;
- conserve les scripts publics appelables directement pour CI, dépannage et automatisation.

## Tableau de bord

L'écran d'accueil affiche sans privilège élevé :

- version du projet ;
- version Fedora ;
- runtime détecté (`BAREMETAL`, `WSL2`, `VM`, `CI`, etc.) ;
- kernel réellement actif ;
- politique Golden `kernel-vanilla/stable latest-stable` ;
- Arc B580 / pilote `xe` lorsque la preuve physique est disponible ;
- état Git (`CLEAN` / `DIRTY`) ;
- preuve du dernier backup complet Restic ;
- présence de la certification finale ;
- état synthétique du réseau KVM `devops-nat` ;
- besoin de reboot lorsque `needs-restarting` est disponible.

Les statuts utilisent le vocabulaire du projet : `PASS`, `WARN`, `KO`, `EXPECTED`, `PENDING` et `REBOOT`.

Les couleurs ANSI sont utilisées uniquement sur un vrai terminal interactif. Pour une sortie neutre :

```bash
NO_COLOR=1 ./control.sh status
```

## Socles du menu interactif

```text
[1] Installation & convergence
[2] Mises à jour
[3] Sauvegarde & restauration
[4] Diagnostics & santé
[5] Kernel & boot
[6] KVM / machines virtuelles
[7] Maintenance
[8] Certification
[9] Logs & preuves
[0] Quitter
```

### Installation & convergence

Ce socle expose le chemin de confiance existant :

1. préflight complet non mutant ;
2. backup pré-APPLY ;
3. installation complète via `install.sh --apply` ;
4. état de la baseline matérielle ;
5. plan des modules de convergence.

Le choix « Installation complète » appelle **exactement** `install.sh --apply`. Toutes les protections de `apply_gate_open` restent donc obligatoires.

### Mises à jour

Le nouveau moteur `scripts/maintenance/update-system.sh` fournit :

```bash
./scripts/maintenance/update-system.sh --check
./scripts/maintenance/update-system.sh --apply
./scripts/maintenance/update-system.sh --dnf-only
./scripts/maintenance/update-system.sh --flatpak-only
./scripts/maintenance/update-system.sh --firmware-check
```

`--apply` suit ce chemin :

```text
runtime bare-metal obligatoire
        ↓
backup complet Restic + integrity check
        ↓
DNF upgrade --refresh
  Fedora + repos activés + kernel-vanilla/stable
        ↓
Flatpak update
        ↓
fwupdmgr get-updates
  INFORMATION UNIQUEMENT — aucun flash
        ↓
diagnostic global
        ↓
indication reboot
```

Le kernel Golden reste `kernel-vanilla/stable`, configuré pour suivre la **dernière stable upstream**, avec le kernel Fedora conservé comme fallback.

Le flash firmware reste volontairement hors de la mise à jour complète : une mise à jour BIOS/NVMe/firmware doit rester une opération explicitement décidée par l'opérateur.

### Sauvegarde & restauration

Le menu expose :

- backup complet HOST ;
- backup complet avec disques de VM **arrêtées** ;
- backup utilisateur locale-safe via XDG ;
- liste des snapshots ;
- backup doctor normal/profond ;
- restauration vers staging ;
- plan Disaster Recovery ;
- rétention Restic manuelle `full + daily` via `backup prune`.

La restauration proposée par le cockpit conserve la politique non destructive de `scripts/backup/restore.sh`.

### Diagnostics & santé

Les doctors restent indépendants. Le menu fournit une navigation par domaine : baseline, kernel/B580, graphics, T705, display, GNOME, applications, multimédia, KVM et backup.

### Kernel & boot

Le Control Center montre l'inventaire des kernels et rappelle la politique :

```text
Golden default     kernel-vanilla/stable → latest stable upstream
Fallback           kernel Fedora officiel
Golden interdit    mainline / -rc / linux-next
```

Le rollback utilise uniquement `scripts/kernel/rollback-to-fedora.sh`.

### KVM / machines virtuelles

Les actions couvrent le doctor, le guard réseau fail-closed, sa réconciliation, la certification runtime, l'accès Nautilus et les créateurs Ubuntu/Windows existants.

### Maintenance

Le socle maintenance reste conservateur : état charge/RAM/disques/services KO, réparation display certifiée, mesure cold-start Nautilus, suspend/resume doctor et consultation des mises à jour. Aucun `autoremove` ou nettoyage destructif silencieux n'est ajouté.

### Certification

Le cockpit donne accès au statut final, à l'enregistrement des cycles suspend et aux certifications baseline/finale. Les critères de certification restent dans leurs doctors, pas dans le menu.

### Logs & preuves

Le menu permet de lister les derniers runs, rapports et markers d'état, d'afficher le dernier `main.log`, de collecter une panne de boot et de montrer le SHA Git courant.

## Mode CLI

Le menu interactif n'est pas obligatoire. Les mêmes familles sont exposées en CLI :

```bash
./control.sh status
./control.sh install dry-run
./control.sh install backup
./control.sh install apply

./control.sh update check
./control.sh update all
./control.sh update dnf
./control.sh update flatpak
./control.sh update firmware

./control.sh backup now
./control.sh backup now-with-vms
./control.sh backup daily
./control.sh backup list
./control.sh backup deep
./control.sh backup restore latest
./control.sh backup prune

./control.sh doctor all
./control.sh doctor kernel
./control.sh doctor gnome
./control.sh doctor kvm

./control.sh kernel status
./control.sh kernel doctor
./control.sh kernel rollback

./control.sh kvm guard-check
./control.sh kvm guard-reconcile
./control.sh kvm certify

./control.sh cert status
./control.sh cert record-suspend
./control.sh cert certify

./control.sh logs list
./control.sh logs tail
```

Les codes de retour des moteurs sont conservés en mode CLI, ce qui rend le Control Center utilisable dans une automatisation sans analyser l'interface humaine.

## Compatibilité et sécurité

- `install.sh`, `diagnostic.sh`, `repair.sh` et les scripts spécialisés restent des entrypoints publics ;
- `menu.sh` est conservé pour les habitudes existantes ;
- aucune dépendance TUI externe n'est requise ;
- les confirmations du menu sont une protection UX supplémentaire, **jamais** un remplacement des gates internes ;
- un appel direct d'un moteur conserve exactement les mêmes protections qu'avant l'ajout du Control Center.
