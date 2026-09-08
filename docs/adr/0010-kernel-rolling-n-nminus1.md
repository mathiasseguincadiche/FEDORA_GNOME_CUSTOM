# ADR 0010 — Kernel Vanilla rolling N / N-1

**Statut : accepté**

## Contexte

La workstation utilise `@kernel-vanilla/stable` afin de suivre le noyau stable requis par le matériel cible. Le lifecycle historique `candidate → boot one-shot → certify` conservait également un kernel Fedora distinct comme fallback permanent.

Pour l'exploitation quotidienne, la politique retenue est désormais plus directe : une mise à jour complète doit installer le dernier stable disponible, tout en gardant un seul rollback immédiatement antérieur dans GRUB.

## Décision

Le lifecycle kernel est **rolling N / N-1** :

```text
latest stable disponible
        ↓
installation DNF5
        ↓
N = nouveau kernel, défaut GRUB
N-1 = kernel précédent conservé
        ↓
maximum deux versions kernel-core
        ↓
versions plus anciennes supprimées via DNF5 installonly
```

Invariants :

- `@kernel-vanilla/stable` reste la source ;
- le minimum projet reste `7.2.2` tant que la configuration ne le relève pas ;
- aucun `-rc`, mainline ou linux-next n'est accepté ;
- `installonly_limit=2` est imposé et vérifié ;
- `dnf5 remove --oldinstallonly --limit=2` est le mécanisme de purge ;
- N est le défaut GRUB normal ;
- N-1 reste installé pour rollback ;
- le kernel actuellement démarré n'est jamais effacé directement par le projet ;
- aucun `rpm -e` ni suppression directe de `/boot/vmlinuz-*` n'est utilisé ;
- un fallback Fedora permanent n'est plus requis ;
- `rollback-to-fedora.sh` reste une procédure de récupération explicite ;
- Secure Boot reste désactivé conformément à la politique HOST.

## Mises à jour

`./control.sh update all` et `./control.sh update dnf` résolvent le dernier stable et configurent la rétention avant la transaction DNF5 offline.

Après le reboot, `./control.sh update finalize` vérifie que N est installé, démarré et sélectionné par GRUB, puis purge les versions antérieures à N-1.

Si la machine a volontairement démarré sur N-1, N reste installé. `./control.sh kernel rollback` sélectionne N-1 comme défaut sans supprimer N.

## Certification Golden

Le nouveau kernel n'attend pas une certification préalable avant de devenir le noyau normal. En revanche, un changement de kernel modifie le runtime fingerprint et peut rendre l'ancienne certification Golden `STALE`.

La certification Gate 3 reste donc la preuve que **le runtime réellement utilisé** — kernel N inclus — fonctionne avec la B580/xe, le stockage, GNOME, KVM, les cycles veille/réveil et le reste de la workstation.

## Conséquences

Avantages :

- mises à jour kernel plus simples et naturelles ;
- rollback immédiat et lisible vers N-1 ;
- GRUB reste propre avec deux kernels au maximum ;
- absence d'accumulation de noyaux historiques ;
- la certification reste centrée sur la preuve runtime plutôt que sur la mécanique de promotion.

Compromis :

- la machine ne conserve plus un troisième kernel Fedora comme parachute permanent ;
- un défaut commun à N et N-1 nécessiterait la procédure de récupération Fedora ou le média d'installation ;
- la recertification post-update reste nécessaire lorsqu'une nouvelle pile invalide les preuves Golden.

Cette ADR remplace ADR 0003 pour la politique active du projet.
