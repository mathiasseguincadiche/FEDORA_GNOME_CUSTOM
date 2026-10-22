# ADR 0018 — Installation neuve Fedora 45 / GNOME 51

Statut : accepté. Remplace le choix actif 44 de l’ADR 0001 et la sélection transitoire décrite par l’ADR 0016 ; conserve leurs règles de promotion et de qualification.

Le propriétaire installe directement Fedora 45 Workstation / GNOME 51. La configuration centrale, les manifestes et verrous canoniques, les scripts publics d’installation, les guides et la CI principale sélectionnent donc cette version. La migration d’un système 44 déjà installé et le laboratoire 44 deviennent des parcours historiques facultatifs et explicites.

La sélection d’une version pour la préparation n’autorise pas l’APPLY. Le profil reste `pending` jusqu’au média final signé, aux composants GNOME 51 revus et disponibles dans les dépôts stables, puis à une CI verte sur le commit de promotion exact. Les tests de candidat peuvent utiliser des composants signés de test uniquement dans leur VM jetable. Ils ne produisent aucune certification physique.

Les verrous canoniques d’extensions et de Nautilus sont identiques à ceux du profil 45 ; leur divergence est refusée. Les verrous 44 restent dans `profiles/fedora44/`. Le parcours principal ne nécessite aucune installation intermédiaire de Fedora 44.

Le second T705 EXT4 `/data` et les sauvegardes `/data/IA/Openclaw` sont conservés. Après préparation : configuration définitive, dry-run final, sauvegarde vérifiée, APPLY, redémarrage, Gate 3 matérielle. Voir [FEDORA45_PRIMARY.md](../FEDORA45_PRIMARY.md).
