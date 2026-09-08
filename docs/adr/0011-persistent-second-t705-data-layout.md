# ADR 0011 — Second T705 persistant : données utilisateur + KVM

**Statut : accepté**

## Contexte

Le T705 principal contient Fedora sur Btrfs et reste le disque système. Une réinstallation ou une perte de ce disque ne doit pas imposer la perte des documents, projets de travail, bibliothèque ISO ni bibliothèque de jeux.

Le second T705 était déjà préparé manuellement en EXT4 sur `/data` pour KVM. Le réserver exclusivement aux VM laisserait cependant les données utilisateur importantes dépendantes du disque système.

## Décision

Le second T705 devient le **disque persistant de la workstation** :

```text
/data/
├── Documents/
├── Projets/
├── ISO/
├── Jeux/
└── libvirt/
```

- `/data/Documents` est le répertoire XDG `DOCUMENTS` de l'utilisateur ;
- `/data/Projets` contient les projets de travail ;
- `/data/ISO` contient la bibliothèque ISO utilisateur ;
- `/data/Jeux` contient la bibliothèque de jeux persistante de la workstation ;
- `/data/libvirt` reste exclusivement géré selon le contrat KVM/libvirt.

Le dépôt ne partitionne, ne formate et ne purge jamais automatiquement le second SSD. L'APPLY ne fait que vérifier son montage EXT4, créer les répertoires manquants de manière idempotente et normaliser leurs droits/labels sans supprimer le contenu existant.

Les répertoires utilisateur utilisent un mode `0750` et un contexte SELinux persistant adapté aux données utilisateur. Le sous-arbre libvirt conserve ses contextes `virt_image_t` séparés.

## Sauvegarde

La séparation physique protège contre la perte ou la réinstallation du **T705 système**, mais ne protège pas contre la panne du second T705.

Le backup Restic quotidien et le backup full incluent donc :

- `/data/Documents` via XDG `DOCUMENTS` ;
- `/data/Projets` explicitement.

`/data/ISO` et `/data/Jeux` sont exclus des backups automatiques par défaut, car ces payloads sont généralement volumineux et reproductibles/retéléchargeables. Une archive Golden longue durée ou une sauvegarde opérateur dédiée peut conserver les éléments non reproductibles si nécessaire.

## Jeux

`/data/Jeux` fournit un emplacement persistant indépendant du T705 système. Le projet ne configure pas automatiquement une bibliothèque Steam ou un launcher vers ce chemin tant que le profil gaming n'est pas explicitement activé/configuré. Cette séparation évite de coupler le socle de stockage à une plateforme de jeu précise.

## KVM

Le pool libvirt reste :

```text
/data/libvirt/images
```

La bibliothèque utilisateur `/data/ISO` n'est pas exposée automatiquement à libvirt. Les médias destinés aux VM restent préparés explicitement sous `/data/libvirt/iso`, ce qui évite d'élargir les permissions de QEMU à toutes les données utilisateur.

## Conséquences

Une réinstallation normale suit donc le modèle :

```text
T705 système perdu/réinstallé
        ↓
Fedora 44 réinstallé sur le premier T705
        ↓
second T705 remonté sur /data SANS formatage
        ↓
APPLY rétablit droits, labels et XDG
        ↓
Documents + Projets + ISO + Jeux + VM restent présents
```

Cette décision remplace ADR 0004 sans changer son invariant fondamental : root et `/data` restent deux NVMe physiques distincts et le projet ne réalise aucune opération de partitionnement/formatage automatique du second disque.
