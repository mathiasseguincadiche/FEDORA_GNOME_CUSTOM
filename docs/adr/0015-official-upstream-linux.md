# ADR 0015 — Linux amont officiel stable uniquement

Statut : accepté. Remplace ADR 0012 ; précise ADR 0010. Décision utilisateur du 4 octobre 2026.

## Décision

Retirer le noyau personnalisé, ses dépôts, ses options CPU et son réglage SELinux. N'accepter que Linux amont sans patch. Résoudre la dernière version finale sur kernel.org à chaque installation/mise à jour, refuser RC/linux-next et toute candidate RPM en retard.

Les RPM `@kernel-vanilla/stable` et leur dépendance amont `fedora` permettent de suivre Linux indépendamment des mises à jour du noyau Fedora. Leur publication peut cependant être postérieure à celle des sources ; ne jamais promettre une installation immédiate tant que le RPM n'existe pas. Les sources officielles signées peuvent être récupérées immédiatement par l'outil dédié, sans que cela soit annoncé comme une installation.

## Rétention et sécurité

N est le dernier stable installé, N-1 le noyau installé immédiatement précédent ; un seul canal `kernel-core`, limite deux. Au premier passage N-1 peut être Fedora. DNF protège le noyau démarré ; une purge bloquée reste un échec explicite. Pas de secours supplémentaire épinglé ni de suppression manuelle de /boot.

Secure Boot actif ou inconnu bloque la mutation. SELinux Enforcing et les autres politiques HOST restent requis. Toute nouvelle version demande requalification, sans promesse de performance ou de stabilité matérielle fondée uniquement sur la CI.

Voir [UPSTREAM_LINUX.md](../UPSTREAM_LINUX.md).
