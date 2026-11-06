# Linux amont officiel stable

> Mise à jour : 2026-11-04 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-04 — politique relue contre `config/kernel.conf` et `lib/kernel_lifecycle.sh` — matériel : non vérifié

Le projet retire le noyau personnalisé et suit uniquement Linux publié par kernel.org, sans patch de distribution. Le canal de paquets est `@kernel-vanilla/stable` ; sa dépendance `@kernel-vanilla/fedora` contient également des noyaux amont sans patch. Ce nom ne désigne pas le noyau Fedora modifié. Les canaux mainline, stable-rc et next sont exclus.

## Version et provenance

À chaque installation ou préparation d'une mise à jour, le projet lit [le flux officiel](https://www.kernel.org/releases.json). La candidate RPM doit correspondre exactement à `latest_stable`, être une version numérique finale et porter la provenance Vanilla. Une nouvelle version finale peut encore être classée « mainline » par kernel.org ; elle est acceptée uniquement si elle est aussi la `latest_stable` officielle. Les RC et linux-next sont toujours refusés. L'encodage RPM `X.Y.0` est reconnu comme la même version finale que `X.Y` sur kernel.org.

`./control.sh kernel status` affiche la version stable courante et celle qui est installée. `KERNEL_MIN_VERSION` (`config/kernel.conf`) est un plancher de sécurité, pas une version figée : le projet suit automatiquement chaque nouvelle stable.

```bash
./control.sh kernel status
./control.sh kernel install-latest
sudo reboot
./diagnostics/kernel-doctor
```

Les RPM sont empaquetés par les mainteneurs Kernel Vanilla : kernel.org ne distribue pas de binaires. Leur cadence est indépendante des noyaux Fedora, mais la compilation et la publication COPR peuvent retarder leur disponibilité.

**En CI uniquement**, un décalage de publication formellement identifié entre kernel.org et COPR est enregistré comme `DEFERRED`, pas comme une transaction RPM réussie : le résumé et l'artefact du workflow conservent cette distinction, même si son statut GitHub est vert. Les autres erreurs restent bloquantes. **Cela ne change pas la règle du poste réel** : aucune installation du dernier noyau n'est autorisée tant que les cinq RPM exacts ne sont pas disponibles et vérifiés. Voir [CI et validation](CI_VALIDATION.md).

Si le RPM de la dernière stable manque, ou si kernel.org est injoignable, le projet n'installe jamais une RC ou un ancien noyau en le présentant comme dernier stable :

- lors d'une **mise à jour système**, seul le noyau est reporté : il est exclu de la transaction DNF, le noyau en cours reste N, et toutes les autres mises à jour, sécurité comprise, sont appliquées. L'état enregistre `kernel_deferred=true`, le bilan final l'indique, et relancer la mise à jour plus tard installe le noyau. Pour bloquer toute la mise à jour dans ce cas, régler `KERNEL_DEFER_WHEN_UNAVAILABLE="false"` ;
- une installation explicite (`./control.sh kernel install-latest`) échoue toujours, avec le même message.

## Récupérer les sources dès leur publication

```bash
bash scripts/kernel/download-upstream-stable.sh --output /chemin/absolu/linux-stable-sources
```

Le répertoire doit être nouveau. Le script récupère la dernière archive amont et sa signature détachée, puis vérifie la signature sur le tar décompressé avec les empreintes publiées de Greg Kroah-Hartman et Linus Torvalds. Il conserve le résultat de signature et le SHA256.

**Ce téléchargement ne compile ni n'installe le noyau.** Le chemin installé et testé par le projet reste celui des RPM Vanilla. Compiler immédiatement depuis les sources sans attendre les RPM demanderait un autre parcours de packaging, de signature et de rétention ; il n'est pas déclaré qualifié ici.

## Transaction RPM

Le moteur conserve un bloc DNF5 versionlock pour les cinq paquets du noyau amont exact. Il le renouvelle à chaque nouveau N ; les règles administrateur sur d'autres paquets sont conservées. Une règle externe qui couvre les mêmes paquets bloque le changement plutôt que d'être supprimée. Les mises à jour complètes et la migration contrôlent aussi le hash du verrou avant le reboot, pour que la transaction reste liée au noyau préparé.

Le retour aux RPM Fedora retire uniquement ce bloc géré. Un administrateur qui passe par DNF directement doit tenir compte du verrou ; utiliser les commandes du projet pour renouveler le noyau selon kernel.org.

## N et N-1

N désigne la dernière stable effectivement installée et le défaut GRUB. N-1 est la version installée immédiatement précédente, conservée pour revenir au démarrage antérieur. Si une version intermédiaire n'a jamais été installée, elle n'est pas reconstituée artificiellement. N et N-1 ne comptent que les noyaux amont ; un noyau Fedora signé est conservé à part comme secours ([ADR 0020](adr/0020-fedora-kernel-boot-fallback.md)).

```bash
./control.sh kernel rollback
sudo reboot
./control.sh kernel prune
```

Le projet conserve au maximum deux versions amont et le noyau Fedora de secours. La purge désigne les versions exactes à retirer et ne touche jamais le noyau démarré ; si cela laisse plus de deux versions amont, le contrôle échoue et demande de démarrer sur N avant de relancer la purge. `installonly_limit=4` laisse la place au nouveau N pendant son installation.

Secure Boot actif ou indéterminé bloque l'installation d'un noyau amont et le retour à N-1. Le passage au noyau Fedora signé (`kernel fallback`, `kernel rollback-fedora`) reste permis, car c'est le seul qui démarre quand Secure Boot est actif. Le projet ne modifie ni l'UEFI ni la confiance MOK automatiquement. SELinux reste Enforcing, sans le réglage de chargement de modules auparavant associé au noyau personnalisé.

La commande `./control.sh kernel rollback-fedora` est une récupération explicite vers les paquets Fedora ; elle sort du suivi amont. Requalifier les performances, l'Arc B580, la veille et les VM après tout changement du noyau utilisé.

Référence : [Kernel Vanilla Repositories, Fedora Project](https://fedoraproject.org/wiki/Kernel_Vanilla_Repositories), [signatures kernel.org](https://www.kernel.org/signature.html).
