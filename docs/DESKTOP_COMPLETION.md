# Intégration desktop et périphériques — octobre 2026

## Maintenance cohérente

Le module lifecycle conserve le téléchargement DNF automatique, mais interdit l'installation/redémarrage sans intervention. Il installe une base dconf système dédiée fgc, conserve les entrées du profil dconf existant et verrouille org.gnome.software download-updates=false et allow-updates=false. Le catalogue et l'installation de nouvelles applications restent disponibles ; les mises à jour RPM utilisent la transaction sauvegardée du projet. Les mises à jour Flatpak restent manuelles via flatpak update. GNOME Logiciels ne propose plus sa voie parallèle de mise à jour.

Après APPLY, se déconnecter/reconnecter et exécuter diagnostics/lifecycle-doctor. Une valeur utilisateur ou un profil dconf personnalisé qui empêche la politique effective bloque le contrôle. Ne pas supprimer PackageKit/DNF5 ni désactiver arbitrairement des services.

## Outils et tests des usages

GNOME Disques (gnome-disk-utility) est un contrat explicite de la couche intégration, sans promettre GTK4 sur toutes les versions Fedora. Flatseal est livré depuis Flathub, avec une provenance upstream-maintained ; aucun badge verified-publisher n'est supposé.

Les tests package/sandbox de application-runtime-doctor restent des smoke tests. La qualification d'usage est une action distincte :

~~~bash
./diagnostics/application-usage-doctor --interactive
~~~

Elle ouvre de vraies applications, exige une modification/enregistrement et un PDF, vérifie que les Flatpak démarrent effectivement et demande une confirmation humaine des interfaces, notifications, communication et VS Code → Rocky. Elle ne crée ni compte cloud ni jeton. La preuve est liée au commit, à la configuration et aux versions des applications. Un échec invalide l'ancienne preuve.

Les réponses ScreenCast/Camera doivent être autorisées. SelectSources et Start précèdent OpenPipeWireRemote ; le diagnostic consomme au moins dix images via GStreamer. Annuler, refuser ou ne recevoir aucun flux fait échouer le test. Aucune image n'est enregistrée.

~~~bash
./diagnostics/portal-functional-doctor --interactive --gate2
./diagnostics/portal-functional-doctor --interactive --gate3
~~~

Gate 2 teste le partage d'écran dans la VM ; Gate 3 exige aussi la caméra réelle. Les essais Slack/WebRTC et les confirmations humaines complètent ce contrôle du flux.

## Identités matérielles et reprise

Avant le postcheck hardware, identifier les périphériques physiques et sélectionner la carte audio de la carte mère (Realtek USB/ALC4080) et le nœud vidéo Brio 100 :

~~~bash
./diagnostics/peripherals-doctor list
./diagnostics/peripherals-doctor enroll audio cardN
./diagnostics/peripherals-doctor enroll camera videoN
~~~

cardN/videoN sont des exemples à remplacer par les indices effectivement inspectés. Aucun numéro USB ou ALSA n'est figé : la résolution suit VID/PID, produit, série et pilote après reboot. La caméra exige Logitech/Brio 100 et uvcvideo ; l'audio exige l'identité MSI **0db0:cc78** de cet ALC4080 et snd_usb_audio. Cet identifiant figure dans la [table officielle ALSA UCM](https://github.com/alsa-project/alsa-ucm-conf/blob/master/ucm2/USB-Audio/USB-Audio.conf) et est rapporté par le [correctif ALSA soumis le 23 septembre 2026](https://lists.openwall.net/linux-kernel/2026/09/23/2799) ; ce correctif de nommage des sorties ne vaut pas preuve de son inclusion dans chaque noyau stable. Si la machine présente un autre VID/PID, arrêter la qualification et documenter la révision matérielle avant d'adapter la liste. Aucun contournement ALSA/kernel n'est appliqué automatiquement. Un micro USB générique ne valide plus l'audio de la carte mère. Si plusieurs périphériques restent indistinguables, la résolution bloque.

~~~bash
./diagnostics/peripherals-doctor test-camera
./diagnostics/physical-runtime-doctor audio
./diagnostics/hardware-components-doctor
~~~

La caméra consomme 60 images en 1080p MJPEG et vérifie le format négocié. Le test audio utilise explicitement la sortie enrôlée et le micro USB de la Brio ; il exige un signal réel et une écoute, puis supprime l'enregistrement temporaire. Les commandes n'agissent que lors d'une exécution explicite sur le PC ; elles ne constituent aucune preuve GitHub du matériel.

Répéter après reconnexion USB et après les cinq cycles veille/reprise. Vérifier Snapshot, puis une application WebRTC et Slack : image, microphone, choix des sorties et notifications.

Wi-Fi 7/EHT et canaux 6 GHz absents produisent BLOCKED lorsque les options correspondantes sont obligatoires. Inspecter iw phy, le firmware et iw reg get. Un point d'accès ou une réglementation qui ne permet pas le 6 GHz ne doit pas être assimilé à une panne du contrôleur ; documenter l'environnement et adapter explicitement le contrat si nécessaire. Aucun domaine réglementaire n'est forcé automatiquement.

## Afficheur LD240 facultatif

La ventilation et la pompe conservent leurs réglages UEFI. Seul l'affichage USB est concerné. Le binaire communautaire Nortank12/deepcool-digital-linux v0.11.0-alpha est verrouillé par URL/version/SHA256 dans hardware/deepcool-ld240.lock. Cette version alpha ne devient pas une dépendance du profil stable.

L'installation explicite refuse une VM et exige la carte MSI attendue ainsi que l'USB 3633:000a. La règle udev accorde l'accès à la session locale pour ce VID/PID seulement, sans MODE=0666. Le service utilisateur est limité à l'affichage et ne démarre pas pendant l'installation.

~~~bash
bash scripts/hardware/ld240-display.sh install
# Reconnecter le périphérique USB, puis :
bash scripts/hardware/ld240-display.sh start
bash scripts/hardware/ld240-display.sh status
# Retour arrière :
bash scripts/hardware/ld240-display.sh remove
~~~

Vérifier visuellement les valeurs puis la reprise après veille. Une incompatibilité du binaire, des permissions ou de SELinux doit rester visible ; ne pas désactiver SELinux ni élargir l'accès à tous les périphériques HID pour la contourner.

## Laboratoires et limites

Le laboratoire Fedora 44 contrôle Dash to Dock, AppIndicator, DING, Show Desktop Plus, Resource Monitor et Tiling Assistant dans la session Wayland après démarrage, reboot, restauration de VM et reconstruction. Il vérifie la politique GNOME Logiciels et un aller-retour LibreOffice TXT → ODT → PDF avec contrôle du contenu.

Fedora 45/GNOME 51 reste un profil de production pending tant que les médias finaux, extensions et preuves ne sont pas prêts. Le laboratoire natif de préversion utilise une image Beta signée et épinglée : il exerce GNOME 51, redémarrage et restauration isolée avec les extensions personnalisées marquées DEFERRED. Le contrôle de leur compatibilité reste séparé. Un résultat natif vert ne promeut pas le profil de production et ne certifie pas les six extensions sous GNOME 51.

Références : [politique GNOME Logiciels](https://github.com/GNOME/gnome-software/blob/50.0/data/org.gnome.software.gschema.xml), [portail ScreenCast](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html), [afficheur communautaire](https://github.com/Nortank12/deepcool-digital-linux), [Flatseal](https://github.com/tchx84/Flatseal).
