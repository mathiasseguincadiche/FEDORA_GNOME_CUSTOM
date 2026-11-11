# Comprendre les résultats, les journaux et les réexécutions

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — diagnostics virtuels, retour firmware et messages du centre de contrôle comparés aux tests isolés ; ordre des mises à jour relu contre `UPDATE_COVERAGE.md` — matériel : non vérifié

Cette page explique **ce que l'opérateur peut réellement conclure**, sans masquer les messages techniques et sans promettre une idempotence générale. Pour les commandes, voir le [centre de contrôle](CONTROL_CENTER.md) ; pour le parcours d'installation, suivre le [guide officiel](INSTALLATION_GUIDE.md).

## 1. Lire le terminal : que signifient les états ?

| État affiché | Signification concrète | Suite logique |
| --- | --- | --- |
| `PASS` / `OK` | Contrôle ciblé réussi | Continuer seulement si les autres préconditions sont remplies |
| `WARN` | Écart ou résultat incomplet | Lire le détail ; vérifier avant une action risquée |
| `KO` / `FAIL` | Contrôle ou opération en échec | Arrêter le parcours, conserver les traces, diagnostiquer |
| `EXPECTED` / `N/A` | Résultat attendu dans cet environnement | Ne **pas** le transformer en preuve du matériel physique |
| `PENDING` | Étape en attente | Identifier la condition ou la preuve manquante |
| `DEFERRED` | Opération volontairement reportée | Rechercher la cause et les conditions d'une future reprise |
| `STALE` | Preuve plus cohérente avec l'état courant | Revalider le périmètre concerné |
| `rc=N` | Code numérique retourné par un moteur | Consulter la phase et son message ; **ne pas deviner** le sens de `N` seul |

Ces états ne garantissent pas tous le même niveau de preuve : un `PASS` d'inventaire logiciel n'est pas une certification de démarrage physique, et un `WARN` n'est pas nécessairement une panne.

**Exemple de contrat de résultat :** hors du PC physique, `./control.sh doctor all` affiche un `KO` d'environnement et renvoie `rc=20` : la qualification est refusée, même si le rapport a été produit. Dans la CI, l'impossibilité de certifier le matériel est `EXPECTED`, non une preuve physique. Un outil qui lit seulement le code de sortie ne doit jamais prendre un `KO` de virtualisation pour un succès.

## 2. Où se trouvent les informations ?

Chaque moteur initialisé crée une session `logs/<RUN_ID>/` : l'identifiant porte une date/heure **UTC** et un identifiant de processus. La session contient différents niveaux de détail :

| Support | Contenu | Présentation |
| --- | --- | --- |
| `operator.log` | Étapes, contrôles, avertissements, erreurs et bilans émis par les fonctions `ui_*` | **Horodaté**, destiné à comprendre les décisions de l'outil |
| `main.log` | Événements du logger technique (`INFO`, `WARN`, `ERROR`, domaine) | **Horodaté**, utile pour diagnostiquer |
| `modules.log` | Sorties natives des phases `precheck`, `plan`, `apply` et `postcheck` | **Brut** ; chaque ligne n'a pas forcément son propre horodatage |
| `reports/run-<RUN_ID>.txt` | Tableau des modules exécutés | Module, phase, retour, durée et détail |
| `reports/run-<RUN_ID>.json` | Même bilan dans un format structuré | Exploitable pour des vérifications automatisées |

`operator.log` **n'est pas une transcription complète du terminal**. Les outils externes (DNF5, `journalctl`, libvirt…) peuvent produire des messages natifs en anglais, dont tout le contenu n'est pas dupliqué dans ce fichier. En particulier, le journal spécifique d'une mise à jour hors ligne reste accessible via `./control.sh update log` après la transaction.

Les dossiers de session sont créés avec des permissions `0700` et leurs journaux principaux avec `0600` ; `operator.log` est également privé (`0600`). Ces permissions limitent l'accès local, mais ne dispensent pas de relire les traces avant un partage ou une exportation.

Pour consulter les traces, sans réparer ni mettre à jour :

```bash
./control.sh logs list  # dossiers, rapports et preuves disponibles
./control.sh logs tail  # dernière session comportant des traces utiles
./control.sh update status  # phase de la transaction DNF5, si elle existe
./control.sh update log  # journal de la dernière transaction hors ligne, si elle existe
```

`logs tail` ignore les **dossiers vides**, notamment celui créé lors de sa propre invocation en ligne de commande. Depuis le menu interactif, il peut aussi afficher la session courante si une opération y a déjà produit des traces. Il montre d'abord les messages destinés à l'opérateur, puis les extraits techniques disponibles. Il ne supprime aucune trace.

**Méthode en cas d'échec :** noter la commande, l'heure UTC, le `RUN_ID`, l'état (`WARN` ou `KO`), la phase du module et le code de retour ; consulter `operator.log`, puis `main.log` et `modules.log`. Conserver également `reports/` et les informations du noyau (`journalctl`) lorsque l'incident concerne le système. Ne pas partager publiquement un journal susceptible de contenir chemins personnels, identifiants ou détails réseau.

### Rétention : une politique, deux façons de l'appliquer

- La commande **manuelle** `./control.sh logs retention` présente les sessions et rapports éligibles ; `logs prune` applique explicitement la politique de `config/operator-retention.policy` (90 jours pour les logs, 180 jours pour les rapports par défaut).
- Le **nettoyage hebdomadaire facultatif**, uniquement si son timer utilisateur a été installé et activé, lit **la même politique**. Il inspecte les sessions de plus de 90 jours (valeur actuelle de `logs_days`), génère une fiche pour les erreurs reconnues et préserve les incidents ouverts.
- Le nettoyage manuel conserve les sessions d'incident, les logs portant des erreurs et les rapports d'incidents ouverts ou de runs échoués. Une fiche résolue ne bloque plus la rétention des rapports correspondants.
- **Les preuves `state/` et `state/releases/` ainsi que le journal système (`journalctl`) ne sont pas ciblés.** Les sorties brutes de commandes peuvent contenir des informations privées : relire et expurger avant partage.

Pour comprendre ou diagnostiquer une erreur avant le nettoyage, voir le [guide de dépannage](TROUBLESHOOTING.md#journaux-et-incidents).

## 3. Idempotence : ce qui se rejoue et ce qui crée volontairement un nouvel état

L'**idempotence** concerne une action précise : répéter une action idempotente ne change plus l'état cible une fois celui-ci atteint. Un verrou empêche deux exécutions simultanées, mais **n'est pas une preuve d'idempotence**. Un contrôle `postcheck` démontre un état attendu après exécution, pas à lui seul l'absence d'effets au second passage.

| Action | Comportement attendu et limite | Statut de preuve |
| --- | --- | --- |
| `install dry-run` | N'applique pas les mutations ; crée néanmoins un nouveau journal et des preuves | Comportement testé, pas une opération totalement sans écriture |
| `install apply` | Modules conçus pour converger ; peut modifier des fichiers et s'arrêter en cours d'exécution | **Idempotence globale non certifiée** ; réexécution uniquement après diagnostic et gardes |
| `update check` | Recherche des mises à jour, sans installer de RPM ni de firmware | Consultation ; crée une session de journalisation |
| `update all` | Crée une nouvelle sauvegarde Borg et prépare une transaction ; refuse une nouvelle préparation si une transaction est déjà en attente | **Non idempotent au niveau de l'historique** ; garde de transaction présent |
| `update flatpak` | Le gestionnaire applique les mises à jour disponibles | Réexécution généralement sans nouvelle mise à jour si tout est à jour ; pas une preuve matérielle |
| `backup now` / `backup daily` | De nouvelles archives peuvent être produites | **Volontairement non idempotent** : conservation des points de restauration |
| `backup restore` | Restauration dirigée vers une zone de staging | Destination à vérifier avant reprise ; ne pas supposer une répétition sans effet |
| `kernel install-latest` / `kvm create-rocky` | Changements sensibles du système ou de la VM | Pas de promesse de réexécution aveugle ; respecter préconditions et diagnostics |

**Tests complémentaires à réaliser avant certification complète :** sur un hôte isolé autorisé, comparer le système après deux APPLY successifs, vérifier qu'aucun fichier n'est dupliqué, que les timers et unités restent uniques, que les paramètres sont inchangés et que les preuves ne sont pas confondues avec un nouvel état matériel. Les tests automatisés actuels protègent certains contrats et cas de répétition, **pas l'ensemble du déploiement sur ton poste physique**.

## 4. Mettre à jour sans confondre noyau, pilotes et firmware matériel

**Commencer par l'observation**, depuis la racine du dépôt. Les trois commandes ci-dessous n'installent pas de mise à jour :

```bash
./control.sh update check      # recherche Fedora / Flatpak / noyau / firmware / périmètre
./control.sh update scope      # frontières RPM, Steam, Proton, extensions, AppImage
./control.sh update status     # état d'une éventuelle transaction DNF5 hors ligne
```

**Si les contrôles sont acceptables et si tu décides de mettre à jour**, appliquer les étapes **une par une** :

1. `./control.sh update all` : sauvegarder avec Borg, puis préparer les RPM disponibles pour DNF5 hors ligne ; cette étape **n'installe pas** les RPM préparés.
2. `./control.sh update status` : lire le résultat réel avant toute décision. Si une transaction RPM est **préparée**, organiser le redémarrage et lancer `./control.sh update reboot` ; sinon, **ne pas redémarrer pour DNF5**.
3. Après le redémarrage requis, exécuter `./control.sh update finalize` pour contrôler les RPM, le noyau, Flatpak et les diagnostics. Sans transaction RPM préparée, suivre le bilan retourné par `update all` et sa finalisation éventuelle, sans inventer une étape de reboot.

Pour les prérequis, les états possibles et le tableau **complet** des domaines (pilotes, codecs, Steam/Proton, GNOME, AppImage, firmware), suivre la [procédure de couverture transversale des mises à jour](UPDATE_COVERAGE.md#3-procédure-de-mise-à-jour-complète). Cette page explique avant tout la lecture des logs et des résultats ; elle ne remplace pas cette procédure.

La mise à jour n'est **pas terminée** tant que le redémarrage **s'il est requis**, la finalisation applicable et les diagnostics ne sont pas effectués. Un noyau `DEFERRED` reste en attente ; un échec de consultation Flatpak est `KO`, jamais « aucune mise à jour ».

Une consultation firmware non concluante produit `WARN` et un échec du bilan de **recherche** (`update check`, `rc=20`). Lors de la **finalisation** d'une transaction logicielle effectivement réussie, le contrôle firmware reste consultatif : le résumé annonce « firmware non vérifié » sans annuler ni relancer une transaction RPM déjà appliquée. Le résultat logiciel et l'état du firmware doivent donc être lus séparément.

### Contrôle après une mise à jour

```bash
./control.sh update status  # état de la transaction et du marqueur projet
./control.sh kernel status  # noyau démarré et paquets présents
./control.sh kernel doctor  # contrat de noyau et mécanisme de secours
./control.sh doctor all     # diagnostic global du poste
./control.sh logs tail      # explications opérateur et traces de la dernière session utile
```

Une certification physique complète nécessite ensuite les preuves et contrôles prévus dans la [qualification](QUALIFICATION.md). Aucun résultat obtenu en conteneur ou en CI ne remplace ces essais sur le matériel réel.
