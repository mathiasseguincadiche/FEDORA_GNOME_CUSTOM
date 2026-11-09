# Politique de sécurité de l'hôte — Secure Boot et chiffrement local

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — politique et deux chemins distincts de récupération relus contre les doctors, `lib/kernel_lifecycle.sh` et `scripts/kernel/rollback-to-fedora.sh` — matériel : non vérifié

## La décision

Sur le PC physique, la politique est fixe et sans option :

| Élément | Politique |
|---|---|
| Secure Boot | désactivé, obligatoirement |
| Chiffrement des SSD locaux, LUKS ou LUKS2 | interdit |
| Partitionnement du système | Btrfs non chiffré |

Elle est versionnée dans `config/golden-host.policy` :

```text
HOST_SECURE_BOOT_POLICY=disabled-required
HOST_STORAGE_ENCRYPTION_POLICY=forbidden
HOST_LUKS_POLICY=forbidden
```

Il n'existe ni profil `luks2`, ni bascule, ni chemin d'installation chiffré. Les raisons et les risques acceptés sont dans l'[ADR 0002](adr/0002-no-secureboot-no-local-luks.md) : la possession physique d'un disque donne accès à ses données, ce qui impose de protéger le matériel lui-même.

## Portée

L'interdiction vise l'hôte Fedora et ses périphériques bloc locaux. Elle ne s'applique pas :

- aux sauvegardes : le dépôt Borg externe n'est pas chiffré non plus, par une décision distincte ([ADR 0014](adr/0014-borg-unencrypted-backups.md)), et ne contient jamais de clé SSH ni GnuPG ([ADR 0021](adr/0021-no-private-keys-in-unencrypted-backups.md)) ;
- à GNOME Keyring et aux autres coffres de secrets des applications ;
- aux systèmes invités : une VM n'est ni le firmware ni le stockage de l'hôte.

Cette politique ne justifie donc jamais d'affaiblir la gestion des secrets.

## Contrôle

`diagnostics/host-security-policy-doctor` vérifie :

| Contrôle | Résultat en cas d'écart |
|---|---|
| valeurs de `config/golden-host.policy` | KO |
| `mokutil --sb-state` sur le PC physique : Secure Boot désactivé ; `mokutil` absent | KO ; hors du PC physique, WARN (l'état du firmware n'est pas observable) |
| aucun périphérique bloc de type `crypt` (`lsblk`) | KO |
| aucune entrée active dans `/etc/crypttab` | KO |
| aucune cible device-mapper `crypt` (`dmsetup`) | KO ; WARN si les tables sont illisibles sans root ou si `dmsetup` manque, les deux contrôles précédents restant appliqués |

Ce doctor est appelé par `diagnostics/workstation-doctor` et par `diagnostics/final-certification` : une machine qui enfreint la politique ne peut pas être certifiée.

## Installation

Le Kickstart généré par `installer/lib/generate-kickstart.sh` contient `autopart --type=btrfs`, sans `--encrypted`, `cryptsetup` ni LUKS. `tests/test_host_security_policy_contract.sh` empêche d'ajouter un chemin de chiffrement dans les scripts d'installation et de convergence.

## Secure Boot et noyau

L'installation du noyau Linux amont est bloquée si Secure Boot est actif ou si son état ne peut pas être établi (`KERNEL_BLOCK_SECURE_BOOT` dans `config/kernel.conf`). Deux **solutions alternatives**, aux effets différents, permettent de sélectionner un noyau Fedora signé ([ADR 0020](adr/0020-fedora-kernel-boot-fallback.md)) :

```bash
./control.sh kernel fallback  # sélectionne le noyau Fedora installé comme défaut GRUB
```

`fallback` conserve les noyaux amont installés. **En cas de retour durable à l'écosystème de paquets Fedora**, utiliser plutôt `./control.sh kernel rollback-fedora` : cette commande désactive les dépôts Kernel Vanilla, nettoie le verrou de version et lance un `dnf5 distro-sync` après confirmation humaine. **Ne pas exécuter les deux commandes à la suite par automatisme**. Dans les deux cas, vérifier le noyau choisi avec `./control.sh kernel status`, puis décider du redémarrage et de la requalification. Consulter le [guide noyau](UPSTREAM_LINUX.md#n-et-n-1) avant d'agir.

Le projet ne désactive jamais Secure Boot lui-même et ne gère aucune clé MOK : le réglage se fait dans l'UEFI, par le propriétaire.

## Changer cette politique

Aucun changement implicite n'est accepté. Revenir sur cette décision demande un nouvel ADR, puis l'évolution coordonnée de la politique, des doctors, des tests et de la documentation.
