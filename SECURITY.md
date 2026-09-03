# Security Policy

## Périmètre supporté

La branche `main` et la version indiquée dans `VERSION` représentent le contrat courant de la Golden Workstation. Les anciennes releases et documents historiques ne constituent pas une surface supportée pour les corrections de sécurité.

## Signaler un problème

Pour une vulnérabilité ou un problème susceptible d'exposer des secrets, des identifiants, le HOST ou les VM, privilégier un canal GitHub privé lorsqu'il est disponible. Ne jamais publier de token, clé SSH, passphrase Restic, mot de passe, dump de secrets ou autre donnée sensible dans une issue publique.

Une issue publique peut être utilisée pour un problème de durcissement non sensible, avec uniquement les informations nécessaires à la reproduction.

## Invariants de sécurité

Le projet considère notamment comme des régressions de sécurité :

- contourner le gate `--apply`, la baseline, le dry-run du même commit ou le backup pré-APPLY ;
- classer un environnement ambigu comme bare-metal ;
- désactiver SELinux ou firewalld pour contourner une incompatibilité ;
- introduire `force_probe`, un dépôt GPU tiers non qualifié ou du GPU passthrough ;
- affaiblir le guard KVM fail-closed ou réactiver IPv6 sans isolation équivalente ;
- installer silencieusement un binaire/artefact téléchargé sans la provenance, version et intégrité exigées par le contrat ;
- copier un QCOW2 actif comme sauvegarde cohérente ;
- introduire un secret dans Git ou dans un log/preuve publique ;
- activer le serveur SSH du HOST Golden sans décision explicite de politique.

## Validation

Une correction de sécurité doit conserver les workflows CI verts sur le SHA exact proposé. Les invariants matériels qui ne peuvent pas être prouvés en CI restent soumis à la certification bare-metal avant qu'une version soit considérée Golden 1.0.
