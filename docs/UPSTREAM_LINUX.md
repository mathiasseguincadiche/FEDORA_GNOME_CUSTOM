# Linux amont officiel stable

Le projet retire le noyau personnalisé et suit uniquement Linux publié par kernel.org, sans patch de distribution. Le canal de paquets est `@kernel-vanilla/stable` ; sa dépendance `@kernel-vanilla/fedora` contient également des noyaux amont sans patch. Ce nom ne désigne pas le noyau Fedora modifié. Les canaux mainline, stable-rc et next sont exclus.

## Version et provenance

À chaque installation ou préparation d'une mise à jour, le projet lit [le flux officiel](https://www.kernel.org/releases.json). La candidate RPM doit correspondre exactement à `latest_stable`, être une version numérique finale et porter la provenance Vanilla. Une nouvelle version finale peut encore être classée « mainline » par kernel.org ; elle est acceptée uniquement si elle est aussi la `latest_stable` officielle. Les RC et linux-next sont toujours refusés.

Au contrôle du 4 octobre 2026, la stable est **7.2.9** ; **7.3-rc6** est une préversion. Le projet passera automatiquement à 7.3 lorsqu'elle sera publiée comme finale. Le minimum 7.2.9 est un plancher de sécurité, pas une version figée.

```bash
./control.sh kernel status
./control.sh kernel install-latest
sudo reboot
./diagnostics/kernel-doctor
```

Les RPM sont empaquetés par les mainteneurs Kernel Vanilla : ils ne sont pas distribués comme binaires par kernel.org. La cadence est indépendante des mises à jour de noyau Fedora, mais la compilation et la publication COPR peuvent retarder la disponibilité. Si le RPM de la toute dernière stable manque, le projet bloque et explique ce retard. Il n'installe pas une RC ou un ancien noyau en le présentant comme dernier stable.

## Récupérer les sources dès leur publication

```bash
bash scripts/kernel/download-upstream-stable.sh --output /chemin/absolu/linux-stable-sources
```

Le répertoire doit être nouveau. Le script récupère la dernière archive amont et sa signature détachée, puis vérifie la signature sur le tar décompressé avec les empreintes publiées de Greg Kroah-Hartman et Linus Torvalds. Il conserve le résultat de signature et le SHA256.

**Ce téléchargement ne compile ni n'installe le noyau.** Le chemin installé et testé par le projet reste celui des RPM Vanilla. Compiler immédiatement depuis les sources sans attendre les RPM demanderait un autre parcours de packaging, de signature et de rétention ; il n'est pas déclaré qualifié ici.

## N et N-1

N désigne la dernière stable effectivement installée et le défaut GRUB. N-1 est la version installée immédiatement précédente, conservée pour revenir au démarrage antérieur. Si une version intermédiaire n'a jamais été installée, elle n'est pas reconstituée artificiellement. Le premier N-1 peut être le noyau Fedora initial.

```bash
./control.sh kernel rollback
sudo reboot
./control.sh kernel prune
```

DNF conserve au maximum deux versions `kernel-core`. Il protège le noyau démarré ; si cela laisse plus de deux versions, le contrôle échoue et demande de démarrer sur N avant de relancer la purge. Aucun noyau en cours d'exécution n'est supprimé et aucun troisième secours n'est épinglé.

Secure Boot actif ou indéterminé bloque les mutations. Le projet ne modifie ni l'UEFI ni la confiance MOK automatiquement. SELinux reste Enforcing, sans le réglage de chargement de modules auparavant associé au noyau personnalisé.

La commande `./control.sh kernel rollback-fedora` est une récupération explicite vers les paquets Fedora ; elle sort du suivi amont. Requalifier les performances, l'Arc B580, la veille et les VM après tout changement du noyau utilisé.

Référence : [Kernel Vanilla Repositories, Fedora Project](https://fedoraproject.org/wiki/Kernel_Vanilla_Repositories), [signatures kernel.org](https://www.kernel.org/signature.html).
