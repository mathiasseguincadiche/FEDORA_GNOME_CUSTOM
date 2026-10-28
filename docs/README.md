# Documentation — Fedora Golden Workstation

Choisir le parcours correspondant à votre besoin. La cible d’installation neuve est **Fedora 45 Workstation / GNOME 51** ; l’état de promotion du profil est centralisé dans la [fiche Fedora 45](FEDORA45_PRIMARY.md).

## Commencer par son objectif

| Je veux… | Point de départ | Étape suivante |
|---|---|---|
| Comprendre le projet | [Vision](VISION.md) | [Architecture expliquée](ARCHITECTURE_PEDAGOGIQUE.md) |
| Installer ce PC | [Contrôle Live](FEDORA45_LIVE_PREFLIGHT.md) | [Installation neuve](INSTALLATION_GUIDE.md) |
| Utiliser et entretenir le poste | [Centre de contrôle](CONTROL_CENTER.md) | [Maintenance](DESKTOP_LIFECYCLE.md) · [Sauvegardes](BACKUP_RESTORE.md) |
| Configurer le bureau, jouer ou utiliser KVM | [GNOME](GNOME.md) · [Gaming](GAMING.md) | [Démarrage KVM](KVM_QUICKSTART.md) |
| Résoudre un problème | [Dépannage](TROUBLESHOOTING.md) | Runbook du domaine concerné dans le catalogue ci-dessous |
| Qualifier ou contribuer | [Validation Live USB et Gate 3](THREE_GATE_VALIDATION.md) | [Fiche de qualification physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) · [Contribution](../CONTRIBUTING.md) |

Le [parcours d’apprentissage](LEARNING_PATH.md) accompagne une découverte progressive. Le [glossaire](GLOSSARY.md) explique les termes techniques.

## Installation et qualification

Suivre le guide d’installation pour les commandes et leurs préconditions :

**Configuration définitive → dry-run final → sauvegarde vérifiée → APPLY → redémarrage → qualification matérielle Gate 3.**

La CI vérifie le logiciel. Le [Live USB](FEDORA45_LIVE_PREFLIGHT.md) permet les essais sur le PC avant installation ; son compte rendu est exporté puis importé sur Fedora installé. Il ne déverrouille jamais `install.sh --apply` dans la session Live. La Gate 3 qualifie ensuite le système installé, ses usages et Rocky DevOps.

## Utilisation quotidienne

```bash
./control.sh
```

Les procédures spécialisées précisent le résultat attendu et la conduite à tenir en cas d’échec. Les commandes détaillées restent dans leur guide canonique.

## Catalogue des guides et références

<details>
<summary>Afficher les références par domaine</summary>

### Normes — ce que la workstation doit être

Ces documents définissent les invariants. Ils répondent à **« qu'est-ce qui est autorisé ou obligatoire ? »**.

- [`CAHIER_DES_CHARGES.md`](CAHIER_DES_CHARGES.md) — exigences normatives ;
- [`GOLDEN_WORKSTATION.md`](GOLDEN_WORKSTATION.md) — architecture et invariants Golden ;
- [`EXECUTION_CONTRACT.md`](EXECUTION_CONTRACT.md) — dry-run/APPLY/mutations ;
- [`HOST_SECURITY_POLICY.md`](HOST_SECURITY_POLICY.md) — politique sécurité HOST ;
- [`SOFTWARE_INVENTORY.md`](SOFTWARE_INVENTORY.md) — inventaire logiciel de référence ;
- [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md) — provenance et intégrité ;
- [`adr/README.md`](adr/README.md) — décisions d'architecture acceptées/superseded.

---

### Installation — construire et préparer la machine

Lire dans cet ordre pour une installation bare-metal :

1. [`FEDORA45_LIVE_PREFLIGHT.md`](FEDORA45_LIVE_PREFLIGHT.md) — média signé, essais directs sur le PC et export du compte rendu ;
2. [`INSTALLATION_GUIDE.md`](INSTALLATION_GUIDE.md) — installation graphique, Kickstart avancé, second T705, baseline, dry-run, backup, APPLY ;
3. [`HARDWARE_BASELINE_CERTIFICATION.md`](HARDWARE_BASELINE_CERTIFICATION.md) — qualification CPU/RAM/NVMe/hardware ;
4. [`HARDWARE_STABILITY.md`](HARDWARE_STABILITY.md) — stabilité et critères de rejet ;
5. [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) — CI logicielle → Live USB → installation → Gate 3.

Les [corrections avant installation](PREINSTALL_SAFETY_REVIEW.md) relient les défauts déjà traités à leurs tests.

**Résultat attendu :** une machine installée, diagnostiquée puis certifiée physiquement. Le compte rendu Live ne remplace pas la Gate 3.

---

### Usage quotidien — quoi lancer au quotidien

Ces documents répondent à **« que dois-je lancer et quel résultat dois-je attendre ? »**.

- [`CONTROL_CENTER.md`](CONTROL_CENTER.md) — cockpit interactif et CLI ;
- [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) — cycle de vie VM courant ;
- [`PERFORMANCE.md`](PERFORMANCE.md) — AMD P-State/EPP, TuneD, sched_ext, zram, NVMe et frametimes ;
- [`GAMING.md`](GAMING.md) — Steam/Vulkan/GameMode/`/data/Jeux` ;
- [`REMOTE_ACCESS.md`](REMOTE_ACCESS.md) — accès distant : Tailscale, SSH, Wake-on-LAN, Sunshine (profil optionnel) ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — Borg (non chiffré), restore et disaster recovery ;
- [`DESKTOP_LIFECYCLE.md`](DESKTOP_LIFECYCLE.md) — maintenance desktop ;
- [`GNOME.md`](GNOME.md) — favoris GNOME ;
- [`APPIMAGE.md`](APPIMAGE.md) — politique AppImage lorsque nécessaire.

---

### Références techniques — comment c'est construit

Les références répondent à **« comment ce contrat est-il implémenté ? »**. Elles servent surtout au diagnostic avancé, à la revue et à la maintenance.

#### Hardware / kernel / drivers

- [`STACK_CERTIFICATION.md`](STACK_CERTIFICATION.md) — contrat de stack ;
- [`GOLDEN_COMPLETENESS_CLOSURE.md`](GOLDEN_COMPLETENESS_CLOSURE.md) — fermeture des socles ;
- [`GLOSSARY.md`](GLOSSARY.md) — vocabulaire.

#### GNOME / desktop

- [`GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md`](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md) ;
- [`GNOME.md`](GNOME.md) ;
- [`GNOME.md`](GNOME.md) ;
- [`GNOME.md`](GNOME.md) ;
- [`GNOME.md`](GNOME.md) ;
- [`NAUTILUS.md`](NAUTILUS.md) ;
- [`PTYXIS.md`](PTYXIS.md).

#### Applications / multimédia

- [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md) ;
- [`MULTIMEDIA_CODECS.md`](MULTIMEDIA_CODECS.md).

#### Virtualisation

- [`VIRTUALIZATION.md`](VIRTUALIZATION.md) — architecture KVM/libvirt ;
- [`VM_PROFILES.md`](VM_PROFILES.md) — profil exécutable Rocky Linux ;
- [`KVM_NETWORK.md`](KVM_NETWORK.md) — réseau `devops-nat` fail-closed ;
- [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md) — accès fichiers ;
- [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md) — référence CLI avancée ;
- [`ROCKY_DEVOPS_READY.md`](ROCKY_DEVOPS_READY.md) — état attendu du guest Rocky ;
- [`ROCKY_DEVOPS_PROVISIONING.md`](ROCKY_DEVOPS_PROVISIONING.md) — provisioning Rocky.

---

### Runbooks — partir d'un symptôme

Commencer par l'état réel :

```bash
./control.sh status
./control.sh doctor all
```

Puis choisir le domaine :

- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — triage transversal ;
- [`RUNBOOK_GOLDEN_HARDWARE.md`](RUNBOOK_GOLDEN_HARDWARE.md) — BIOS, P-State, ReBAR, PCIe, NVMe, EDID, kernel, offline update ;
- [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md) — libvirt, pool, réseau, guard, Rocky Linux, QGA, exports VM manuels ;
- [`RUNBOOK_PERSISTENT_DATA_GAMING.md`](RUNBOOK_PERSISTENT_DATA_GAMING.md) — `/data`, EXT4, ownership, SELinux, XDG Documents, Borg, Steam/Vulkan ;
- [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) — restauration et DR ;
- [`KVM_NETWORK.md`](KVM_NETWORK.md) — détails d'isolation réseau.

Un runbook suit la logique :

```text
symptôme → observation → diagnostic → correction sûre → revalidation
```

Ne pas désactiver SELinux, firewalld ou les garde-fous fail-closed pour masquer une erreur.

---

### Qualification et contribution

- [`CI_VALIDATION.md`](CI_VALIDATION.md) — validation automatisée ;
- [`FEDORA_GNOME_CI_LAB.md`](FEDORA_GNOME_CI_LAB.md) — démarrage GNOME et récupération QEMU sur GitHub ;
- [`ISOLATED_RECOVERY_RUNBOOK.md`](ISOLATED_RECOVERY_RUNBOOK.md) — reprise fichiers/OS/VM hors production ;
- [`QUALIFICATION_EVIDENCE_TEMPLATE.md`](QUALIFICATION_EVIDENCE_TEMPLATE.md) — fiche de preuves à remplir pendant les essais ;
- [`GOLDEN_RELEASE.md`](GOLDEN_RELEASE.md) — bundle Golden et archivage ;
- [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md) — gouvernance du dépôt ;
- [`DOCUMENTATION_MODEL.md`](DOCUMENTATION_MODEL.md) — règles de cohérence documentation ↔ code ;
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — contribution.

---


</details>

## Comprendre les décisions et contribuer

Le [modèle documentaire](DOCUMENTATION_MODEL.md) définit les rôles des guides et l’ordre d’autorité. La [traçabilité code / documentation](CODE_DOCUMENTATION_TRACEABILITY.md) permet de retrouver l’implémentation et les tests d’un parcours. Les [décisions d’architecture](adr/README.md) expliquent les choix conservés.

## Historique et migrations

L’installation neuve Fedora 45 ne passe pas par Fedora 44. Les anciens essais et migrations sont séparés : [Fedora 44 historique](HISTORICAL_FEDORA44.md), [mise à niveau facultative 44 → 45](UPGRADE_FEDORA_45.md), [comptes rendus passés](history/README.md).

<details>
<summary>Autres références spécialisées</summary>

- [Accueil du projet](../README.md)
- [Certification de la plateforme](CERTIFICATION.md)
- [Intégration du bureau et des périphériques](DESKTOP_COMPLETION.md)
- [Diagnostic des couleurs](DISPLAY_COLOR_DIAGNOSTIC.md)
- [Finition du bureau](GNOME.md)
- [Noyau Linux amont](PERFORMANCE.md#noyau-officiel-linux-amont)
- [Suivi de fiabilité](RELIABILITY_QUALIFICATION.md)
- [Feuille de route Fedora 45](ROADMAP_FEDORA45_2026.md)
- [Noyau amont et politique N/N-1](UPSTREAM_LINUX.md)
- [Décision sur l’accès distant](adr/0017-remote-access.md)

</details>
