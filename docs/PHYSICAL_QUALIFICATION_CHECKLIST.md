# Qualification réelle du poste — fiche d'exécution

> Fait partie du parcours de certification : vue d'ensemble dans [`CERTIFICATION.md`](CERTIFICATION.md).

Cette fiche prépare les essais sur le PC cible. Les résultats physiques restent **PENDING** tant que les commandes n'ont pas été exécutées sur ce PC et les contrôles humains réalisés. Les laboratoires GitHub Rocky/Fedora ne remplacent pas ces mesures.

La procédure autoritaire reste [THREE_GATE_VALIDATION.md](THREE_GATE_VALIDATION.md). Utiliser le profil Fedora/GNOME effectivement promu pour la production ; la préparation Fedora 45/GNOME 51 ne constitue pas cette promotion.

## La machine cible : ce qu'il faudra pouvoir montrer

**L'objectif Fedora 45 / GNOME 51 ne sera atteint que lorsque le profil final sera promu et que cette checklist aura été exécutée sur le PC réel.** Les workflows GitHub Fedora et Rocky ne vérifient pas le comportement physique de ces périphériques.

| Composant | Ce qu'il faut observer sur place | Pourquoi |
|---|---|---|
| Ryzen 7 7700 et 48 Gio DDR5 | identité, fréquence, stabilité | éviter de certifier un profil appliqué à une autre machine |
| Intel Arc B580 | pilote `xe`, ReBAR, rendu Vulkan/VA-API | mesurer les performances et l'accélération réelles |
| Deux Crucial T705 | identité NVMe, SMART, emplacements, `/data` EXT4 | distinguer système réinstallable et données persistantes |
| ASUS QD-OLED | EDID, 2560×1440/~240 Hz, veille/reprise | confirmer image et fréquence sans artefacts |
| Wi-Fi 7 / 5 GbE / audio / webcam | connectivité et usage effectifs | ne pas confondre paquet pilote installé et matériel fonctionnel |
| Backup Borg sur XS1000 | sauvegarde et vraie restauration en staging | prouver la récupération au-delà d'une simple archive créée |

**État initial : `PENDING`.** Remplir les preuves observées, puis requalifier après tout changement majeur de noyau, version Fedora, profil GNOME ou matériel. Pour la procédure exacte et les gardes, voir [THREE_GATE_VALIDATION.md](THREE_GATE_VALIDATION.md).


## Qualification de l'affichage B580 : blanc, RGB, HDR, double écran

L'affichage est une **mesure visuelle** à conduire avec l'Intel Arc B580 réelle. Ne pas afficher un PASS parce qu'un connecteur annonce un mode 2560×1440 : ce mode peut être simplement disponible, pas actif.

1. Relever les sorties réellement connectées, le modèle des écrans et leur arrangement dans GNOME.
2. Exécuter `./diagnostics/display-color-audit` **sans privilèges** pour obtenir un inventaire DRM anonymisé.
3. Observer avec GNOME **la résolution et la fréquence active** sur chaque écran, ainsi que les éventuels VRR/HDR.
4. Tester un aplat blanc, un dégradé noir/blanc et des gris neutres à réglages fixes ; noter la plage RGB côté moniteur, l'ICC et Night Light.
5. Refaire la comparaison en SDR puis, si disponible, en HDR ; comparer HDMI et DisplayPort en ne changeant **qu'un facteur** à la fois.
6. Refaire les observations après veille/réveil et vérifier les éventuels messages `xe`/DRM/PCIe.

Le protocole complet, les causes possibles du blanc grisâtre et les décisions en cas d'échec sont dans [DISPLAY_COLOR_DIAGNOSTIC.md](DISPLAY_COLOR_DIAGNOSTIC.md). La validation ne doit pas contourner `xe`, désactiver SELinux ni imposer des profils couleur non vérifiés.


## AV1 sur le poste et la tablette (qualification distincte)

1. Sur l'hôte Fedora, observer `./diagnostics/arc-b580-av1 --format json` : **un seul** render node B580 `8086:e20b` lié à `xe` doit exposer `VAProfileAV1Profile0` avec `VAEntrypointVLD` et `VAEntrypointEncSlice` ou `VAEntrypointEncSliceLP`. Sinon : `NOT_TESTED` ou `MISSING_AV1_CAPABILITY`, et arrêt de la qualification AV1.
2. Avec Sunshine activé **volontairement** et une session GNOME ouverte, vérifier le codec/encodeur réellement retenu dans les journaux, et non dans une simple liste de codecs disponibles.
3. Depuis la tablette Android, lancer Moonlight ; relever codec décodé, résolution, FPS, pertes réseau et latence sur LAN puis via Tailscale.
4. Après arrêt complet, demander Wake-on-LAN depuis un **relais LAN** ; répéter les cycles exigés, mesurer les erreurs et vérifier le verrouillage de session.
5. Consigner la présence éventuelle de bascule H.264/HEVC, d'intervention locale, d'absence de 240 Hz ou d'artefacts. **Aucun résultat n'est simulé par GitHub Actions.**

Le diagnostic ne modifie ni les pilotes, ni l'ouverture du pare-feu, ni le compte GNOME, ni Sunshine. Voir [REMOTE_ACCESS.md](REMOTE_ACCESS.md) pour la procédure d'activation et de retour arrière.

## Avant les charges

1. Conserver le même commit Git propre et le même plan de modules pour les trois gates.
2. Exécuter Gate 1 sous Fedora/WSL2, puis Gate 2 sous VirtualBox avec sa validation visuelle et exporter les preuves.
3. Sur le Fedora physique cible, importer ces deux preuves dans l'ordre et lire l'état :

~~~bash
git rev-parse HEAD
git status --short
./control.sh validate import /chemin/gate1-<commit>.json
./control.sh validate import /chemin/gate2-<commit>.json
./control.sh validate gate3 status
~~~

Ne pas lancer ces essais depuis un runner GitHub public ou une VM en prétendant tester la B580, les T705 ou le BIOS. Un éventuel runner personnel ne remplace pas la session Wayland ni les confirmations audio, HDR/VRR et visuelles.

4. Suivre l'installation, la sauvegarde pré-APPLY et la convergence du [guide de validation](THREE_GATE_VALIDATION.md). La baseline RAM/CPU/NVMe et les identités Bluetooth/refroidissement sont préparées **avant APPLY**. L'opérateur reste présent pendant les charges.

## Baseline avant APPLY

~~~bash
./diagnostics/peripherals-doctor list
# Remplacer cardN/videoN après inspection :
./diagnostics/peripherals-doctor enroll audio cardN
./diagnostics/peripherals-doctor enroll camera videoN
./diagnostics/baseline-doctor enroll-wifi
./diagnostics/baseline-doctor enroll-bluetooth
./diagnostics/baseline-doctor list-cooling
~~~

Identifier les canaux réels pompe/CPU/boîtier avant d'exécuter enroll-cooling avec trois entrées fanN distinctes. Aucun flash BIOS, overclocking ou réglage forcé de ventilateur n'est appliqué par cette fiche.

~~~bash
./diagnostics/baseline-doctor run-memory-test 5600
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-cpu-soak
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
~~~

Les deux essais RAM exigent chacun la vitesse réellement configurée dans l'UEFI ; lancer la commande 6000 alors que la RAM est à 5600 ne certifie pas 6000. Les essais NVMe écrivent seulement dans un fichier temporaire unique sur chaque système de fichiers ; ils ne visent jamais un disque brut.

Les seuils minimaux de qualification sont une heure par vitesse RAM et trente minutes CPU. Le CPU exige une température lisible avant, pendant et après l'essai. La charge s'arrête si une mesure manque ou atteint la limite choisie, plafonnée à 95 °C. Un processus terminé trop tôt ne produit aucune preuve PASS.

## Après APPLY et redémarrage

Exécuter dans la vraie session GNOME/Wayland, avec l'écran et les périphériques utilisés au quotidien :

~~~bash
./diagnostics/kernel-doctor
./diagnostics/peripherals-doctor test-camera
./diagnostics/hardware-components-doctor
./diagnostics/graphics-doctor
./diagnostics/arc-compute-doctor
./diagnostics/storage-doctor
./control.sh validate gate3 gpu-soak
./control.sh validate gate3 network-lan
./control.sh validate gate3 network-wifi
./control.sh validate gate3 audio-cert
./control.sh validate gate3 display-cert
scripts/kvm/runtime_certification.sh
~~~

Le test Vulkan impose au moins quinze minutes et une à huit instances (deux par défaut). Fermer les fenêtres prématurément, réduire la durée ou fournir zéro instance fait échouer la qualification. Les workers CPU/RAM/GPU sont arrêtés avec leur groupe de processus lorsqu'un essai échoue ou est interrompu.

Le LAN et le Wi-Fi doivent être connectés lors de leurs essais respectifs. L'audio demande une écoute réelle et une capture microphone ; l'affichage demande un contrôle actif HDR/VRR sur l'EDID cible. La certification KVM attend les invités Rocky Linux 10.2 **et Windows**, leur intégration et le guard réseau.

Faire ensuite cinq cycles physiques distincts veille/réveil et les enregistrer selon le guide :

~~~bash
./control.sh validate gate3 record-suspend
~~~

Après les cycles, refaire la capture Brio, l'écoute/capture audio et le partage réel :

~~~bash
./diagnostics/peripherals-doctor test-camera
./diagnostics/physical-runtime-doctor audio
./diagnostics/portal-functional-doctor --interactive --gate3
./diagnostics/application-usage-doctor --interactive
~~~

Voir [DESKTOP_COMPLETION.md](DESKTOP_COMPLETION.md) pour les identités, les blocages Wi-Fi et l'afficheur LD240 facultatif.

Conserver une sauvegarde Borg contenant les disques/NVRAM des VM et exercer la [restauration isolée](ISOLATED_RECOVERY_RUNBOOK.md) avant le verdict final.

## Résultats à conserver

| Domaine | Preuve attendue | État initial |
|---|---|---|
| CPU / RAM | Charges complètes, mesures thermiques, journaux et SHA-256 | PENDING |
| B580 | xe, ReBAR, PCIe x8, Vulkan, VA-API/OpenCL et charge complète | PENDING |
| Deux T705 | Identités distinctes, SMART, PCIe x4 et intégrité fio | PENDING |
| Affichage / audio | EDID, mode, essais actifs et confirmations humaines | PENDING |
| LAN / Wi-Fi / Bluetooth | Identité, lien, DNS/HTTPS et périphériques réels | PENDING |
| Veille | Cinq cycles physiques actuels | PENDING |
| KVM / sauvegarde | Rocky, Windows, isolation et restauration à froid | PENDING |

Les preuves CPU/RAM/GPU utilisent qualification_policy=2 et enregistrent durée demandée et durée écoulée. Les anciens markers ne comportant pas ces mesures sont refusés : rejouer les essais concernés, sans éditer les markers. Une nouvelle tentative valide invalide d'abord la preuve concernée et la certification courante ; un échec ne peut donc laisser un ancien PASS actif. Les bundles Golden archivés restent conservés.

~~~bash
./control.sh perf status
./control.sh validate gate3 certify
./control.sh validate status
~~~

Seul le dernier verdict réel peut produire state/final/certified.ok et le bundle golden-release.json. En cas d'échec, ouvrir une [issue matérielle](../.github/ISSUE_TEMPLATE/hardware_validation.yml) avec le commit, le noyau, le domaine, la commande et l'erreur. Relire les journaux avant publication : ne transmettre ni mots de passe, clés privées, jetons cloud, enregistrement microphone ni inventaire personnel complet.

## Réserve Rocky / Docker

L'invité Rocky garde son noyau EL10 et Docker stable. Les notices de maintenance nft_compat / ip_set restent visibles ; elles ne constituent pas une preuve de panne du matériel Fedora. La [qualification réseau Docker](ROCKY_DEVOPS_READY.md#qualification-réseau-docker) vérifie bridges interne/de publication, DNS, échanges entre conteneurs et port publié sur localhost avant/après redémarrage, puis après restauration sans téléchargement. Le backend nftables natif reste [expérimental selon Docker](https://docs.docker.com/engine/network/firewall-nftables/) ; il n'est pas activé pour masquer une notice.
