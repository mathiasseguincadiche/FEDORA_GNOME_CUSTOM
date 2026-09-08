# Archivage des payloads Golden

Le bundle Golden courant capture l'état certifié : commit, configuration effective, inventaires RPM/Flatpak/extensions, média Fedora verrouillé, matériel et preuves. Cela suffit pour identifier précisément une Golden Workstation, mais pas pour garantir qu'un mirror externe conservera éternellement chaque payload historique.

L'archivage de payloads est donc une couche **optionnelle de conservation long terme**. Il ne participe pas à la certification runtime et ne doit jamais être stocké dans Git.

## Principe

Après une certification Golden PASS, préparer sur un support externe les fichiers que l'on souhaite pouvoir reconstruire sans dépendre de leur disponibilité future, par exemple :

- ISO Fedora 44 certifiée + CHECKSUM/keyring conservés par l'opérateur ;
- caches/export RPM explicitement préparés pour cette Golden ;
- dépôts ou bundles Flatpak offline préparés par l'opérateur ;
- artefacts tiers déjà approuvés et verrouillés ;
- médias Windows/VirtIO uniquement lorsque leur conservation est autorisée et assumée par l'opérateur.

Puis créer l'archive :

```bash
bash scripts/release/archive-golden-payloads.sh \
  --destination /media/backup-golden \
  --payload /chemin/Fedora-Workstation-Live-44-1.7.x86_64.iso \
  --payload /chemin/payloads-rpm \
  --payload /chemin/payloads-flatpak
```

Le helper :

1. exige un `state/final/certified.ok` en PASS ;
2. retrouve le `golden_release_manifest` associé ;
3. refuse d'écrire dans le checkout Git ;
4. copie les métadonnées Golden certifiées ;
5. copie uniquement les payloads fournis explicitement ;
6. produit `PAYLOADS.sha256` et `METADATA.sha256`.

Il **ne télécharge rien** et ne prétend pas transformer un fichier arbitraire en source de confiance. La provenance reste celle documentée dans `SUPPLY_CHAIN.md` : signature ou hash attendu obtenu depuis une source indépendante et approuvée.

## Ce que l'archive apporte

Elle permet de conserver ensemble :

```text
état Golden certifié
        +
métadonnées exactes
        +
payloads explicitement archivés
        +
SHA-256 de tous les fichiers copiés
```

Cela réduit la dépendance aux mirrors et aux changements de dépôts dans le temps.

## Ce qu'elle ne promet pas

- elle n'archive pas automatiquement toutes les dépendances transitives ;
- elle ne contourne aucune licence de redistribution ;
- elle ne remplace pas Restic pour les données utilisateur ;
- elle ne remplace pas Gate 3 ni la certification physique ;
- elle ne garantit une reconstruction totalement offline que si l'opérateur a réellement fourni l'ensemble des payloads nécessaires.

Pour une conservation maximale, stocker l'archive sur au moins un support distinct de la workstation et vérifier périodiquement `PAYLOADS.sha256`.
