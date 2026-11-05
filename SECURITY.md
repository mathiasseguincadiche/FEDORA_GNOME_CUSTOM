# Politique de sécurité

## Périmètre couvert

La branche `main` et la version indiquée dans [`VERSION`](VERSION) forment le contrat courant de la Golden Workstation. Les anciennes releases et les documents historiques ne reçoivent pas de correction de sécurité.

## Signaler un problème

Une vulnérabilité, ou un problème qui pourrait exposer des secrets, des identifiants, l'hôte ou les VM, se signale par un canal privé : le signalement privé de vulnérabilité de GitHub (onglet **Security** du dépôt) lorsqu'il est disponible. Ne jamais publier de jeton, de clé SSH, de mot de passe, de copie de secrets ni d'autre donnée sensible dans une issue publique.

Un problème de durcissement sans caractère sensible peut faire l'objet d'une issue publique, limitée aux informations nécessaires pour le reproduire.

## Invariants de sécurité

Le projet considère comme une régression de sécurité, notamment :

- contourner la barrière de `install.sh --apply`, la baseline, le dry-run du même commit ou la sauvegarde pré-APPLY ;
- classer un environnement ambigu comme matériel physique ;
- désactiver SELinux ou firewalld pour contourner une incompatibilité ;
- introduire `force_probe`, un dépôt GPU tiers non qualifié ou l'attribution du GPU à une VM (passthrough) ;
- affaiblir le garde réseau KVM fermé par défaut, ou réactiver IPv6 sans isolation équivalente ;
- installer sans le dire un binaire ou un artefact téléchargé sans la provenance, la version et l'intégrité exigées par le contrat ;
- copier un QCOW2 en cours d'utilisation comme s'il s'agissait d'une sauvegarde cohérente ;
- introduire un secret dans Git, dans un journal ou dans une preuve publique ;
- activer le serveur SSH de l'hôte Golden sans décision explicite de politique.

## Contrôles

Le workflow `Security scanning` analyse les sources Python avec CodeQL et recherche les secrets dans l'historique avec Gitleaks. Les versions de ses actions sont épinglées par commit. Ses résultats sont examinés avant la fusion ; un résultat ne se fait jamais disparaître en désactivant la détection. Les contrôles ShellCheck, de non-régression de l'architecture et les tests restent obligatoires.

Une correction de sécurité garde tous les workflows de la CI verts sur le SHA exact proposé. Les invariants matériels qu'aucune CI ne peut prouver restent soumis à la qualification sur le PC physique (Gate 3) avant qu'une version soit considérée comme Golden 1.0.
