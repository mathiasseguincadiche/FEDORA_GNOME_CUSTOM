# Journaux et incidents — guide opérateur

## Organisation

Les exécutions existantes sont conservées sous `logs/<RUN_ID>/main.log` et `modules.log`. Les identifiants sont horodatés en UTC. Les incidents ouverts sont suivis sous `logs/incidents/<RUN_ID>.json`. Les comptes rendus de nettoyage sont dans `reports/nettoyage-*.json`.

Les catégories logiques sont : système, installation, matériel, accès distant, sécurité et sauvegardes. Le champ `category` d'une fiche incident permet de les retrouver. Les journaux bruts sont préservés : traduire ou masquer une erreur technique risquerait de perdre la preuve du diagnostic.

## Explications en français

Les fiches d'incident fournissent automatiquement un titre, une explication, une action recommandée et un niveau d'incertitude. Les règles couvrent notamment permissions, SELinux, stockage, réseau, services, signatures, sauvegardes, Wake-on-LAN et Sunshine. Une explication est une **hypothèse de diagnostic**, jamais une preuve de cause racine. Les fichiers main.log et modules.log originaux restent inchangés.

## Lecture simple

- `status: open` : problème non résolu ; le journal associé ne doit pas être supprimé.
- `status: resolved` : résolution explicitement confirmée ; le journal devient éligible à la purge s'il est assez ancien.
- `summary` : explication lisible par une personne ; compléter après investigation.
- `resolution` : description vérifiable de la correction et du test qui l'a confirmée.

Une disparition d'erreur après redémarrage ne clôture pas l'incident.

## Nettoyage

```bash
python3 scripts/maintenance/weekly-log-cleanup.py                # simulation
python3 scripts/maintenance/weekly-log-cleanup.py --apply        # purge prudente
```

Le nettoyage considère seulement les dossiers de sessions de plus de sept jours au nom attendu. Il conserve les incidents ouverts, les dossiers inattendus, les fichiers symboliques et les fichiers d'une session en cours. Il ne touche jamais aux journaux systemd, à `state/`, aux sauvegardes Borg, ni aux rapports de certification.

**Activation volontaire :** les unités fournies sont des unités *utilisateur* et supposent que le dépôt est installé dans `~/FEDORA_GNOME_CUSTOM`. Si le dépôt se trouve ailleurs, adapter `ExecStart` et `ConditionPathIsDirectory` avant activation.

```bash
mkdir -p ~/.config/systemd/user
cp systemd/user/fgc-weekly-log-cleanup.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now fgc-weekly-log-cleanup.timer
systemctl --user list-timers fgc-weekly-log-cleanup.timer
```

Le lundi à 03:00 est interprété dans le fuseau local de la machine. `Persistent=true` permet une exécution de rattrapage après une période où la session utilisateur n'était pas active ; un timer utilisateur ne garantit pas une exécution à 03:00 si le gestionnaire utilisateur est arrêté. Tester d'abord en simulation. Pour une exécution sans session ouverte, il faut une installation système revue séparément.

## Clôture d'un incident

Modifier explicitement sa fiche JSON : `status` devient `resolved`, renseigner `resolution` avec la cause corrigée, la commande ou le test de vérification, et la date. Ne jamais clore un incident sans preuve. La prochaine purge du lundi pourra retirer son journal s'il a plus de sept jours.
