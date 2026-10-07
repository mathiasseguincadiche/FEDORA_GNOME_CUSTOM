# ADR 0012 — Canal noyau CachyOS (BORE) à côté de Kernel Vanilla

> Décision historique remplacée par [ADR 0015](0015-official-upstream-linux.md). Le noyau personnalisé n'est plus accepté par le projet.

**Statut : remplacé par ADR 0015** (décision du propriétaire du 4 octobre 2026 : Linux amont officiel uniquement). Conservé pour l'historique de la décision.

## Contexte

L'objectif de la workstation est d'offrir sur Fedora la **réactivité desktop** d'une distribution orientée performance comme CachyOS. Jusqu'à la 0.15, la couche « Fedora-Cachy » ne faisait que du réglage runtime (TuneD, EPP, zram, GameMode) : le noyau restait `@kernel-vanilla/stable`, sans les patchs qui donnent son caractère à CachyOS.

L'équipe CachyOS publie pour Fedora un noyau officiel, `kernel-cachyos`, via le COPR `bieszczaders/kernel-cachyos`. Il apporte notamment l'ordonnanceur **BORE** (Burst-Oriented Response Enhancer, qui favorise les tâches interactives), le support `sched_ext` et une compilation ciblant `x86-64-v3`.

## Décision

Le projet gère désormais un **canal noyau** choisi par `KERNEL_CHANNEL` dans `config/kernel.conf` :

| Canal | Source | Paquet géré | Usage |
|---|---|---|---|
| `cachyos` (défaut Golden) | `bieszczaders/kernel-cachyos` | `kernel-cachyos-core` | réactivité desktop |
| `vanilla` | `@kernel-vanilla/stable` | `kernel-core` | noyau upstream sans patch |

Invariants communs (hérités d'ADR 0010) : dernier stable installé directement, N/N-1 maximum, aucun `-rc`/mainline, défaut GRUB vérifié, sauvegarde Borg obligatoire avant installation, Secure Boot désactivé.

Garde-fous propres au canal `cachyos`, vérifiés **avant** toute mutation :

1. **CPU `x86-64-v3` prouvé** par le chargeur dynamique. Sinon le noyau ne démarrerait pas : blocage `EXIT_SECURITY_BLOCK`.
2. **Compromis SELinux explicite.** CachyOS documente que son noyau exige le booléen `domain_kernel_load_modules=on`. Ce booléen autorise des domaines SELinux à demander le chargement de modules noyau : c'est un léger assouplissement. Il n'est appliqué que si `KERNEL_CACHYOS_SELINUX_MODULE_LOAD="true"` ; sinon `EXIT_CONFIG_FAILED`. SELinux reste en mode *enforcing*.
3. **Noyau de secours.** `kernel-cachyos-core` et `kernel-core` sont deux noms de paquets distincts : la limite DNF `installonly_limit=2` s'applique à chacun. Le noyau `kernel-core` (Fedora officiel, ou Kernel Vanilla si son COPR reste activé) reste donc installé et visible dans GRUB comme entrée de secours.
4. Seul le COPR `kernel-cachyos` exact est accepté : `-addons`, `-lto`, `-lts` et `-rc` ne correspondent pas au motif de dépôt.

## Conséquences

Avantages :

- réactivité desktop (BORE) et `sched_ext` disponibles nativement ;
- retour arrière simple : `KERNEL_CHANNEL="vanilla"` puis `./control.sh kernel install-latest`, ou `./control.sh kernel rollback-fedora` en urgence ;
- un noyau Fedora signé reste toujours démarrable.

Coûts assumés :

- noyau patché par un tiers (l'équipe CachyOS), comme Kernel Vanilla était déjà un COPR ;
- `domain_kernel_load_modules=on` ;
- jusqu'à quatre entrées noyau dans GRUB (2 CachyOS + 2 `kernel-core`) ;
- une mise à jour du noyau de secours dans la même transaction peut demander un redémarrage supplémentaire : `update finalize` remet toujours CachyOS N par défaut.

Un changement de canal modifie l'empreinte runtime : la certification Gate 3 devient `STALE` et doit être rejouée.
