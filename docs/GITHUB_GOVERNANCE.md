# GitHub governance — pre-1.0

`main` est une branche de production : aucun changement ne doit contourner la validation automatisée.

## Ruleset attendu sur `main`

Configurer dans GitHub un ruleset ciblant `refs/heads/main` avec :

- pull request obligatoire avant fusion ;
- interdiction des force-push et suppressions de `main` ;
- branche à jour avant fusion ;
- checks obligatoires : **Tests**, **Shell quality**, **Architecture non-regression**, **Fedora 44 package preflight**, **Fedora 44 host integration pretest** ;
- le workflow Ubuntu 26.04 reste path-scoped et doit être vert lorsqu'il est déclenché par une modification de la VM/du bootstrap.

Le dépôt contient `scripts/development/check-main-protection.sh` pour vérifier l'état public de la branche. Le script ne modifie aucun réglage GitHub.

## Discipline de release

Toute modification fonctionnelle fusionnée dans `main` doit être reflétée dans `VERSION`, `CHANGELOG.md` et, lorsqu'elle affecte le contrat utilisateur, `README.md`.

## Limite d'automatisation

La connexion GitHub utilisée pour maintenir ce dépôt sait lire les protections/rulesets mais ne dispose pas d'une action d'écriture de ces réglages. Le ruleset doit donc être activé dans les paramètres GitHub du dépôt ; cette opération est volontairement hors de l'APPLY Fedora.
