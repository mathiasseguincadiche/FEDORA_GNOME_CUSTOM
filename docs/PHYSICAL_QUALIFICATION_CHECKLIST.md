# Fiche de qualification physique

Copier cette fiche dans le dossier de preuves de l'essai. Les commandes et critères sont dans [la qualification](QUALIFICATION.md) ; cette fiche sert à consigner ce qui a réellement été fait. Tout commence **NON EXÉCUTÉ** : un résultat ne devient PASS qu'après l'essai sur le PC, et cette fiche ne remplace aucun fichier de preuve Live ou Gate 3.

Ne pas lancer ces essais depuis un runner GitHub ou une VM en prétendant tester la B580, les T705 ou le BIOS. Avant de publier des journaux, retirer mots de passe, clés privées, jetons, enregistrements micro et inventaire personnel.

## Identités à figer

- Date et opérateur : NON RENSEIGNÉ
- Commit Git propre et exact, plan de modules, configuration effective : NON RENSEIGNÉ
- Rapport CI de ce commit : NON RENSEIGNÉ
- Média Fedora Workstation vérifié (nom, SHA-256) : NON RENSEIGNÉ
- Séries du T705 système, du T705 `/data` et du support externe : NON RENSEIGNÉ
- Dépôt Borg, nom et identifiant de l'archive complète : NON RENSEIGNÉ
- SHA-256 de la preuve Live (même commit, même PC) : NON RENSEIGNÉ

Cible : Ryzen 7 7700, MSI MAG B850M Mortar WiFi, Intel Arc B580, 48 Gio DDR5, deux Crucial T705, Kingston XS1000 externe, ASUS ROG Strix OLED XG27AQDMES 2560×1440/~240 Hz. Relever l'inventaire réel au moment de l'essai et noter tout remplacement.

## Avant installation et APPLY

| Essai | État | Preuve attendue |
|---|---|---|
| Live USB Fedora 45 / GNOME 51 | NON EXÉCUTÉ | JSON `PREINSTALL_ONLY` + SHA exportés hors du Live, puis importés sur le SSD |
| Identités Wi-Fi, Bluetooth, refroidissement, `/data` | NON EXÉCUTÉ | verrous enrôlés, trois canaux de ventilation distincts |
| RAM 5600 puis 6000 | NON EXÉCUTÉ | vitesse UEFI réelle, 60 min chacune, durée et erreurs consignées |
| CPU | NON EXÉCUTÉ | 30 min, températures, aucune erreur MCE/EDAC |
| Deux T705 | NON EXÉCUTÉ | séries distinctes, SMART, PCIe x4, intégrité fio |
| Baseline certifiée | NON EXÉCUTÉ | `baseline-doctor certify` PASS |
| Dry-run, sauvegarde pré-APPLY, APPLY | NON EXÉCUTÉ | même état, restauration canari vérifiée, APPLY terminé, reboot sur Linux amont N |

## Système installé (Gate 3)

| Composant / usage | État | Preuve attendue |
|---|---|---|
| Arc B580 | NON EXÉCUTÉ | `xe`, ReBAR, PCIe x8, Vulkan/VA-API/OpenCL réels, `gpu-soak` 15 min sans erreur |
| Écran | NON EXÉCUTÉ | EDID physique, 2560×1440/~240 Hz actif, VRR et HDR essayés, reconnexion |
| Ethernet / Wi-Fi | NON EXÉCUTÉ | interface identifiée, DNS/HTTPS, transfert réel et débit mesuré |
| Bluetooth | NON EXÉCUTÉ | appairage réel, usage prolongé, reprise après veille |
| Audio | NON EXÉCUTÉ | lecture et capture réelles, sortie et volume conservés après veille |
| Webcam, USB, XS1000 | NON EXÉCUTÉ | 60 images 1080p, branchements et reprise, données copiées comparées |
| Veille | NON EXÉCUTÉ | cinq cycles distincts enregistrés ; écran, audio, réseau, USB revérifiés |
| Bureau GNOME | NON EXÉCUTÉ | matrice UX : Bureau/Corbeille, Super+D, Vitals, Nautilus (aperçu, recherche), Ptyxis, portails. Une capture d'écran seule ne prouve pas les interactions |
| Arrêt et reboot GNOME | NON EXÉCUTÉ | fermeture normale, reboot avec bureau ouvert et reboot précoce : aucune extension désactivée ni crash dans le journal du boot précédent |
| Applications | NON EXÉCUTÉ | `application-usage-doctor --interactive` : modification enregistrée, PDF, Flatpak démarrés |
| Gaming | NON EXÉCUTÉ | jeu réellement lancé, durée, erreurs, frametimes |
| Rocky DevOps | NON EXÉCUTÉ | VM démarrée, guard réseau, SFTP depuis Nautilus, réseau Docker qualifié |
| Sauvegarde et restauration | NON EXÉCUTÉ | `backup-doctor --certify`, restauration en staging, contenu/modes/liens comparés |
| Reprise isolée Fedora / VM | NON EXÉCUTÉ | voir [reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md) |
| Noyau de secours Fedora | NON EXÉCUTÉ | entrée GRUB présente, démarrage testé une fois, retour sur N |

Les doctors (baseline, graphics, arc-compute, display, storage, hardware-components, suspend, usb-resume, virtualization, backup, performance) sont des points de contrôle : leur PASS s'accompagne des essais d'usage ci-dessus. Une lecture de journaux seule ne prouve ni stabilité, ni débit, ni fluidité, ni silence.

## Affichage : blanc, RGB, HDR

Mesure visuelle avec la B580 réelle. Un mode 2560×1440 annoncé n'est pas forcément actif.

1. Relever les sorties connectées, les écrans et leur arrangement dans GNOME.
2. `./diagnostics/display-color-audit`, **sans privilèges**, pour un inventaire DRM anonymisé.
3. Noter la résolution et la fréquence **actives**, VRR/HDR.
4. Aplat blanc, dégradé noir/blanc et gris neutres à réglages fixes ; noter la plage RGB côté écran, l'ICC et l'éclairage nocturne.
5. Comparer SDR puis HDR, HDMI puis DisplayPort, en ne changeant **qu'un facteur** à la fois.
6. Refaire après veille ; vérifier les messages `xe`/DRM/PCIe.

Causes possibles et décisions en cas d'échec : [diagnostic couleur](DISPLAY_COLOR_DIAGNOSTIC.md).

## AV1 et streaming vers la tablette (facultatif)

1. `./diagnostics/arc-b580-av1 --format json` : un seul render node B580 `8086:e20b` sur `xe` doit exposer `VAProfileAV1Profile0` avec `VAEntrypointVLD` et `VAEntrypointEncSlice` (ou `EncSliceLP`). Sinon : `NOT_TESTED` ou `MISSING_AV1_CAPABILITY`, et arrêt.
2. Sunshine activé volontairement, session GNOME ouverte : relever dans les journaux le codec et l'encodeur **réellement** retenus.
3. Depuis la tablette, Moonlight : codec décodé, résolution, FPS, pertes et latence, en LAN puis via Tailscale.
4. Après arrêt complet, Wake-on-LAN depuis un relais LAN ; répéter, relever les erreurs, vérifier le verrouillage de session.
5. Consigner toute bascule H.264/HEVC, intervention locale, absence de 240 Hz ou artefact.

Procédure d'activation et retour arrière : [accès distant](REMOTE_ACCESS.md).

## Clôture

- Échecs et parties non testées : NON RENSEIGNÉ
- Corrections et nouveau commit éventuel : NON RENSEIGNÉ
- `validate gate3 certify` et bundle Golden : NON EXÉCUTÉ
- Mesures A/B avant toute optimisation : NON EXÉCUTÉ

En cas d'échec, ouvrir une [issue matérielle](../.github/ISSUE_TEMPLATE/hardware_validation.yml) avec commit, noyau, domaine, commande et erreur.

L'invité Rocky garde son noyau EL10 et Docker stable. Les notices nft_compat / ip_set ne prouvent pas une panne du matériel Fedora ; la [qualification réseau Docker](ROCKY_DEVOPS_READY.md#qualification-réseau-docker) vérifie bridges, DNS, échanges entre conteneurs et port publié avant et après redémarrage.
