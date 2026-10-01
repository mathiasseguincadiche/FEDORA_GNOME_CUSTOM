# Dossier de qualification opérateur

Copier cette fiche dans le dossier de preuves de l'essai. Toutes les cases
commencent NON EXÉCUTÉ ; un résultat ne devient PASS qu'après l'exercice réel.
Cette fiche de suivi ne remplace aucun fichier de preuve des trois gates.

## Identités à figer

- Date et opérateur : NON RENSEIGNÉ
- Commit Git propre et exact : NON RENSEIGNÉ
- Configuration effective / plan de modules / empreintes : NON RENSEIGNÉ
- Rapport du laboratoire GitHub sur ce commit : NON RENSEIGNÉ
- Média Fedora Workstation vérifié, nom et SHA-256 : NON RENSEIGNÉ
- Numéros de série du T705 système, du T705 données et du support externe : NON RENSEIGNÉ
- Dépôt Borg, nom et identifiant de l'archive complète incluant les VM : NON RENSEIGNÉ
- SHA-256 des preuves Gate 1 et Gate 2 liées au même commit : NON RENSEIGNÉ

La cible matérielle est Ryzen 7 7700, MSI MAG B850M Mortar WiFi, Intel Arc
B580, 48 Gio DDR5, deux Crucial T705, support externe XS1000 et écran ASUS
OLED 2560×1440/~240 Hz. Relever l'inventaire réel au moment de l'essai et
documenter tout remplacement ; une ancienne fiche matérielle ne suffit pas.

## Validation et reprise

| Essai | État initial | Acceptation / preuve |
|---|---|---|
| Gate 1 Fedora WSL2 | NON EXÉCUTÉ | Commande officielle réussie, JSON + SHA exportés |
| Gate 2 Fedora GNOME/VirtualBox | NON EXÉCUTÉ | LAB, doctors, matrice UX réellement exécutée, signature humaine et référence Gate 1 |
| Fichiers isolés | NON EXÉCUTÉ | Archive exacte, verify-data, contenu/modes/liens comparés |
| Fedora reconstruit | NON EXÉCUTÉ | Support cible distinct, boot, GNOME, données, diagnostics puis convergence répétée |
| VM Ubuntu récupérée | NON EXÉCUTÉ | Membres correspondants, boot, documents/services, redémarrage et isolation |
| VM Windows récupérée | NON EXÉCUTÉ | Disque/NVRAM/swtpm/UUID, boot, TPM, documents et isolation |
| Arrêt/reboot GNOME | NON EXÉCUTÉ | Fermeture normale, reboot direct avec bureau ouvert et reboot précoce : aucune désactivation d'extensions ni crash dans le journal du boot précédent |
| APPLY réel et noyau | NON EXÉCUTÉ | Baseline + dry-run + backup + APPLY, démarrage CachyOS BORE, entrée N-1 disponible |

Suivre [les gates](THREE_GATE_VALIDATION.md) et
[la reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md). Archiver les erreurs aussi.
La matrice UX inclut DING/Corbeille, Show Desktop Plus/Super+D, Resource
Monitor, Nautilus/prévisualisation/recherche, Ptyxis et les portals.
Une capture d'écran seule ne démontre pas les interactions.

## Essais physiques

| Composant / usage | État initial | Acceptation / mesures |
|---|---|---|
| CPU / RAM | NON EXÉCUTÉ | Baseline et charge selon le guide, erreurs/thermique/durée consignées |
| Arc B580 | NON EXÉCUTÉ | xe natif, ReBAR et PCIe relevés, Vulkan/OpenCL/VA-API réels, absence d'erreurs/crash |
| Deux T705 | NON EXÉCUTÉ | Séries distinctes, SMART, liens PCIe, température et I/O sur fichiers temporaires |
| Écran | NON EXÉCUTÉ | EDID physique et 2560×1440/~240 Hz, reconnexion, HDR/VRR uniquement si utilisés |
| Veille/reprise | NON EXÉCUTÉ | Cinq cycles uniques enregistrés par Gate 3 ; écran, audio, réseau et USB revérifiés |
| Wi-Fi / Ethernet | NON EXÉCUTÉ | Interface identifiée, DNS/HTTPS, transfert réel et débit mesuré |
| Bluetooth | NON EXÉCUTÉ | Appairage réel, usage prolongé et reprise après veille |
| Audio | NON EXÉCUTÉ | Lecture et capture réelles, périphérique/volume conservés après veille |
| USB / webcam / XS1000 | NON EXÉCUTÉ | Branchements et reprise, données copiées comparées, backup réel vérifié |
| Gaming | NON EXÉCUTÉ | Jeu effectivement lancé, durée et erreurs consignées, frametimes mesurés |
| Usage équilibré | NON EXÉCUTÉ | Profil balanced, température/bruit observés, aucun gain annoncé sans comparaison |

Les doctors existants servent de points de contrôle : baseline, graphics,
arc-compute, display, storage, hardware-components, suspend, usb-resume,
virtualization, windows-guest, backup et performance. Leur PASS doit être
accompagné des essais d'usage ci-dessus ; une lecture de journaux seule ne
prouve pas stabilité, débit, fluidité ou silence.

## Clôture

- Échecs et parties non testées : NON RENSEIGNÉ
- Corrections et nouveau commit éventuel : NON RENSEIGNÉ
- Gate 3 / final-certification / bundle Golden : NON EXÉCUTÉ
- Mesures A/B avant toute optimisation supplémentaire : NON EXÉCUTÉ

Tout nouveau commit ou plan de modules invalide les preuves Gate 1/Gate 2
précédentes. Rejouer la chaîne officielle avant une certification finale.
