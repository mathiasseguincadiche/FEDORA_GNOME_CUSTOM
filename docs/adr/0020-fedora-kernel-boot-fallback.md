# ADR 0020 — Noyau Fedora de secours à côté de Linux amont N / N-1

Statut : accepté. Précise ADR 0010 et ADR 0015 (rétention) ; décision utilisateur du 27 octobre 2026.

## Contexte

La rétention N / N-1 ne gardait que deux noyaux `@kernel-vanilla/stable`, et l’entrée GRUB `0-rescue` était supprimée. Une régression du pilote `xe` (Arc B580) présente dans deux versions amont consécutives laissait alors le poste sans noyau démarrable connu. La seule sortie était `rollback-to-fedora.sh`, qui suppose un système déjà démarré.

## Décision

- Linux amont reste le canal par défaut : N est le défaut GRUB, N-1 le retour arrière.
- **Un noyau Fedora signé** (dépôts `fedora` / `updates`) est conservé en plus. Il apparaît comme entrée GRUB normale, n’est jamais choisi par défaut et n’est jamais supprimé par la rétention.
- La purge n’utilise plus `dnf5 remove --oldinstallonly`, qui retire d’abord la plus petite version, donc le noyau Fedora. Le projet choisit les NEVRA exactes à retirer : noyaux amont plus anciens que N-1, noyaux Fedora plus anciens que le secours. Le noyau démarré n’est jamais retiré.
- `installonly_limit=4` : N, N-1, secours Fedora, plus une place pendant l’installation d’un nouveau N. La limite DNF n’est qu’un garde-fou ; la rétention réelle reste celle du projet.
- Le secours est installé à l’APPLY et à la finalisation des mises à jour s’il manque. Il n’est pas rafraîchi automatiquement, pour rester un noyau déjà connu ; `./control.sh kernel refresh-fallback` le remplace par le dernier noyau Fedora signé.
- Le versionlock amont n’admet que l’EVR vanilla. Il est levé pour la seule transaction Fedora, puis restauré sur N, y compris en cas d’échec.
- `KERNEL_KEEP_FEDORA_FALLBACK="false"` revient à l’ancien comportement (N / N-1 seuls).

## Utilisation

- Si N et N-1 démarrent mal : au démarrage, maintenir **Maj** ou appuyer sur **Échap** pour afficher GRUB, puis choisir l’entrée *Fedora Linux (…fc45.x86_64)* sans `vanilla`. Fedora réaffiche aussi le menu après un démarrage qui n’a pas abouti.
- Depuis une session démarrée : `./control.sh kernel fallback` rend le secours défaut GRUB sans rien supprimer ; `./control.sh kernel install-latest` revient au dernier amont.
- `./control.sh kernel rollback-fedora` reste la récupération complète (désactivation des dépôts amont).

## Conséquences

- Un noyau de plus dans `/boot` (environ 80 à 100 Mio).
- Le secours n’est pas certifié Golden : un démarrage dessus est une session de dépannage (`kernel-doctor` l’indique en WARN).
- Secure Boot reste désactivé par la politique HOST pour les noyaux amont : leur installation et le retour à N-1 sont bloqués s'il est actif ou indéterminé. Le secours, signé, ne change pas cette exigence. En revanche, `./control.sh kernel fallback` et `./control.sh kernel rollback-fedora` restent permis quel que soit l'état de Secure Boot, parce que le noyau Fedora signé est alors le seul qui démarre.
