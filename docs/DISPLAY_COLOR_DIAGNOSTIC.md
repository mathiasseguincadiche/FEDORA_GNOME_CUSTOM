# Diagnostic d'affichage — Intel Arc B580, GNOME Wayland et fidélité des couleurs

**Objectif.** Comprendre un blanc qui paraît gris, délavé ou irrégulier sur plusieurs écrans, sans supposer que la carte graphique est défectueuse et **sans modifier automatiquement** les réglages du GPU ou de GNOME.

Ce guide concerne Fedora Workstation (cible Fedora 45 / GNOME 51), Intel Arc B580 avec pilote `xe`, écrans DisplayPort/HDMI et configuration à deux moniteurs. Le profil de production Fedora 45 est encore `pending` : les mesures réelles sont à conduire avant la Gate 3 et à répéter après toute migration.

## Ce qui peut changer le rendu du blanc

| Hypothèse | Symptôme possible | Information qui permet de trancher |
|---|---|---|
| Plage RGB **complète (0–255)** vs limitée (16–235) | image délavée ou niveaux écrasés | état effectif du GPU **et** plage attendue par l'OSD du moniteur |
| SDR / HDR et conversion tonale | blanc visuellement plus gris dans certaines fenêtres | même scène comparée en SDR puis HDR, avec même luminosité |
| Profil ICC / gestion des couleurs | blancs plus chauds, gris colorés | profil attribué dans GNOME, comparaison après neutralisation contrôlée |
| Veilleuse / température de couleur | blanc jaune ou gris chaud | état de Night Light et réglage température écran |
| Chaîne d'affichage / câble / EDID | modes ou couleurs différents selon DP et HDMI | connecteur, mode réellement actif, EDID, journal `xe`/DRM et OSD |
| Limite de luminosité / gestion OLED | blanc étendu visuellement moins lumineux | comportement OSD et réglage ABL, selon le modèle |
| Compositor ou pilote | artefacts, décrochages après veille | journaux noyau, redémarrage du moniteur, reproductibilité sur différents écrans |

**Aucune de ces hypothèses n'est un diagnostic acquis.** Le fait que plusieurs moniteurs montrent un problème commun rend pertinente l'inspection du pipeline graphique, mais ne prouve pas que la B580 est la cause.

## 1. Observer sans rien changer

Dans une session GNOME Wayland installée, ou en Live Fedora 45 :

```bash
echo "$XDG_SESSION_TYPE"
gnome-shell --version
./diagnostics/display-color-audit
./diagnostics/display-color-audit --format json
```

Le nouveau diagnostic interroge **seulement les connecteurs DRM lisibles dans sysfs** : connexion, activation et **liste des modes pris en charge**. Il ne demande ni `sudo`, ni accès à `/dev/mem`, ni modification d'affichage. Il ne collecte pas l'EDID brut, les numéros de série, les adresses réseau ou les captures d'écran. En l'absence d'information, il renvoie `NOT_TESTED`.

**Important :** une résolution `2560x1440` dans la liste des modes n'est **pas** une preuve que le moniteur fonctionne actuellement en 240 Hz.

Sur la machine **déjà installée et qualifiée**, le diagnostic canonique plus complet reste :

```bash
./diagnostics/display-doctor
./diagnostics/graphics-doctor
```

Ces doctors peuvent exiger une baseline EDID physique et écrire des rapports locaux. Le script Python ci-dessus reste l'outil léger pour découvrir les signaux d'affichage en Live et partager un inventaire dépourvu d'identifiants.

## 2. Mesurer le mode réellement affiché

Ouvrir **Paramètres GNOME → Écrans** pour vérifier, **écran par écran** :

- l'identité du moniteur et l'arrangement des deux écrans ;
- `2560×1440`, la fréquence active (environ 240 Hz pour l'écran cible), VRR et HDR **si proposés** ;
- les différences entre HDMI et DisplayPort, sans les confondre avec un changement simultané de profil colorimétrique.

La commande `gdctl show --verbose`, lorsqu'elle est disponible et compatible avec le GNOME utilisé, peut compléter ces données. **Ne pas coller publiquement sa sortie brute** sans enlever les identifiants du moniteur.

Dans l'OSD du moniteur, relever **la plage RGB d'entrée** (Auto/Full/Limited), la présence du mode HDR, la température de couleur et la luminosité. Une preuve de plage complète côté GPU doit correspondre à celle attendue par l'écran : la seule présence du mot `full` dans un journal ne démontre pas que toute la chaîne est calibrée.

## 3. Comparaison A/B strictement contrôlée

1. Conserver le même câble, le même écran et la même image test (dégradé noir→blanc, aplats gris neutres et fond blanc).
2. Noter les valeurs initiales et l'heure ; fermer les applications qui modifient la couleur.
3. Comparer **SDR** avec HDR désactivé, puis HDR activé si le matériel le permet.
4. Comparer Night Light désactivé puis activé, sans mélanger ces mesures avec celles de HDR.
5. Inspecter le profil ICC assigné, sans installer de profil téléchargé arbitrairement.
6. Refaire la même comparaison sur DisplayPort puis HDMI et, si possible, sur le deuxième moniteur.
7. Observer une sortie de veille puis réexaminer `journalctl -k -b` pour les messages `xe`, DRM, AER et erreurs de liaison.

**Un seul paramètre change à la fois.** Il est interdit de déclarer « corrigé » sur la simple base d'une impression isolée ou d'un résultat provenant d'un écran différent.

## 4. Décision

| Résultat observé | Suite raisonnable |
|---|---|
| Rendu correct en SDR, dégradé uniquement en HDR | documenter le chemin HDR/tonemapping et vérifier la compatibilité logicielle |
| Dérive dépendant d'un écran seulement | examiner OSD, plage RGB, profil ICC et câble de cet écran |
| Dérive identique sur plusieurs écrans et câbles | vérifier la configuration GNOME, la plage de sortie et la pile Mesa/`xe` |
| Artefacts après veille seulement | joindre logs DRM et observations aux essais de reprise Gate 3 |
| Rien de reproductible | `NOT_TESTED` ou `PENDING`, pas de correction forcée |

**Pas de contournement** : ne pas désactiver SELinux, forcer `i915`, utiliser `force_probe`, modifier globalement les gamma LUT ou installer des Mesa expérimentaux sur l'hôte Golden. Une remédiation doit être réversible et liée à une preuve.

La certification physique est régie par [PHYSICAL_QUALIFICATION_CHECKLIST.md](PHYSICAL_QUALIFICATION_CHECKLIST.md). Le travail prioritaire global est suivi dans [ROADMAP_FEDORA45_2026.md](ROADMAP_FEDORA45_2026.md).

**Sources :** [GNOME 51 — notes de version](https://release.gnome.org/51/) et [GNOME 50 — gestion des couleurs et VRR](https://release.gnome.org/50/).
