# Politique HOST — Secure Boot et chiffrement local

## Décision Golden

La politique de la workstation physique est **fixe et non optionnelle** :

```text
Secure Boot du HOST             OFF obligatoire
Chiffrement des SSD locaux      interdit
LUKS / LUKS2                    interdit
Partitionnement Golden          Btrfs non chiffré
```

La source de vérité versionnée est `config/golden-host.policy` :

```text
HOST_SECURE_BOOT_POLICY=disabled-required
HOST_STORAGE_ENCRYPTION_POLICY=forbidden
HOST_LUKS_POLICY=forbidden
```

Il n'existe pas de profil `luks2`, de bascule d'activation, ni de chemin d'installation chiffré dans le Golden HOST.

## Portée exacte

Cette interdiction concerne **Fedora Golden HOST et ses périphériques bloc locaux**. Elle ne doit pas être confondue avec :

- le chiffrement du dépôt de sauvegarde Restic, qui reste requis pour protéger les sauvegardes externes/remote ;
- GNOME Keyring ou d'autres coffres applicatifs destinés aux secrets ;
- les besoins propres d'un système invité dans une VM. Une VM n'est pas le firmware ni le stockage bloc du HOST.

Le projet ne doit donc jamais affaiblir les sauvegardes ou la gestion de secrets au nom de cette politique de stockage local.

## Enforcement fail-closed

`diagnostics/host-security-policy-doctor` valide :

- la politique versionnée ;
- `mokutil --sb-state` sur bare-metal et exige Secure Boot désactivé ;
- l'absence de périphérique bloc de type `crypt` ;
- l'absence d'entrée active dans `/etc/crypttab` ;
- l'absence de cible device-mapper `crypt` lorsqu'elle est observable.

Sur bare-metal, Secure Boot actif ou un stockage local chiffré est un **KO**, pas un avertissement.

Ce doctor entre dans :

- `diagnostics/workstation-doctor` ;
- `diagnostics/final-certification`.

Une machine qui viole cette politique ne peut donc pas recevoir le verdict Golden certifié.

## Installation

Le générateur Kickstart conserve explicitement :

```text
autopart --type=btrfs
```

sans `--encrypted`, sans `cryptsetup`, sans LUKS.

Le contrat `tests/test_host_security_policy_contract.sh` empêche l'ajout futur d'un chemin de chiffrement bloc dans les scripts d'installation/convergence.

## Secure Boot et Kernel Vanilla

Le lifecycle kernel est déjà fail-closed : un candidat Kernel Vanilla ne peut pas être staged si Secure Boot est actif ou si son état ne peut pas être établi. La certification finale ajoute maintenant la même règle au niveau de la workstation entière.

## Changement de politique

Aucun changement implicite n'est accepté. Modifier cette décision nécessiterait une évolution explicite de l'architecture, des tests et de la documentation. Tant que cette politique est en vigueur, **Secure Boot HOST et chiffrement local restent interdits**.
