# Multimédia et codecs — Fedora 45

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — paquets et diagnostic relus contre `manifests/packages-multimedia-fedora.txt` et `manifests/packages-rpmfusion.txt`, politique contre `config/gnome.conf` — matériel : non vérifié

## Objectif

Fournir une pile multimédia GNOME complète et explicite, sans groupes de paquets opaques ni remplacement aveugle de composants graphiques.

## Fondation Fedora

Le manifeste `manifests/packages-multimedia-fedora.txt` installe :

- `gstreamer1-plugins-base` ;
- `gstreamer1-plugins-good` ;
- `gstreamer1-plugins-bad-free` ;
- `gstreamer1-plugin-openh264` ;
- `libvpl` ;
- `intel-vpl-gpu-rt`.

`libvpl` et `intel-vpl-gpu-rt` fournissent la couche oneVPL nécessaire aux applications qui utilisent l'accélération vidéo Intel Xe/Arc, notamment les chemins QSV quand l'application les prend en charge.

## Complément RPM Fusion

Le manifeste `manifests/packages-rpmfusion.txt` installe :

- `ffmpegthumbnailer` ;
- `gstreamer1-plugins-bad-freeworld` ;
- `gstreamer1-plugins-ugly` ;
- `gstreamer1-plugin-libav`.

Le fournisseur FFmpeg est géré séparément. Si Fedora possède `ffmpeg-free`, le projet exécute un swap contrôlé vers le `ffmpeg` complet de RPM Fusion avec `--allowerasing`. Si `ffmpeg-free` n'est pas présent, `ffmpeg` est installé directement.

## Formats visés

La validation couvre au minimum les familles suivantes lorsqu'elles sont exposées par les bibliothèques installées :

- vidéo : H.264/AVC, H.265/HEVC, AV1, VP8/VP9, MPEG et Theora ;
- audio : AAC, MP3, Opus, Vorbis, FLAC et PCM ;
- conteneurs usuels : MP4, Matroska/MKV, WebM, MOV, AVI, MPEG et Ogg.

## Intel Arc B580 : VA-API et oneVPL/QSV

Le pilote média Fedora `libva-intel-media-driver` reste le choix initial. La politique `INTEL_MEDIA_DRIVER_POLICY=auto` interdit tout remplacement arbitraire.

Sur la machine Arc B580, le projet exécute `vainfo` via le nœud DRM de rendu et vérifie la présence des familles H.264, HEVC, AV1 et VP9 :

- si les profils requis sont présents, le pilote Fedora est conservé ;
- si le probe fonctionne mais révèle un manque H.264/HEVC/AV1/VP9, le projet effectue un swap contrôlé vers `intel-media-driver` fourni par RPM Fusion ;
- si le probe VA-API est impossible, aucun swap n'est effectué sur simple supposition et un avertissement demande un diagnostic.

Le mode `rpmfusion-full` force explicitement le fournisseur RPM Fusion. Le mode `fedora-free` interdit le swap.

En parallèle, oneVPL reste fourni par Fedora via `libvpl` + `intel-vpl-gpu-rt`. Cette couche n'est pas un remplacement du pilote VA-API : elle complète la pile pour les logiciels utilisant l'API Intel VPL/QSV.

## Vérification et dépannage après l'APPLY

**Pourquoi :** des codecs présents dans les manifestes ne garantissent pas leur disponibilité réelle ; la liste des décodeurs ne prouve pas non plus que la B580 décode et encode correctement.

**Préparer :** depuis la racine du dépôt, sur Fedora installé avec l'APPLY terminé, lancer le diagnostic. Sur un PC doté de la B580, le nœud de rendu DRM doit être accessible pour les tests VA-API ; une VM sans cette carte ne peut pas produire la même preuve.

```bash
./diagnostics/media-doctor
```

`media-doctor` contrôle :

- les RPM multimédias attendus et la cohérence du fournisseur FFmpeg avec `ENABLE_RPMFUSION` ;
- les décodeurs FFmpeg H.264, HEVC, AV1, VP9, AAC, MP3, Opus et FLAC ;
- les encodeurs VA-API H.264, HEVC et AV1 exposés par FFmpeg ;
- si la B580 est détectée : son nœud DRM, les profils VA-API H.264/HEVC/AV1/VP9 et l'identification du pilote iHD.

Sur **matériel physique** avec B580, il lance également un essai fonctionnel de décodage et d'encodage. Il ne modifie pas les paquets ni les réglages, mais **écrit le rapport de cet essai** dans `reports/` ; ce n'est donc pas une commande sans aucune écriture.

**Interprétation :** zéro `KO` signifie que les contrôles bloquants du script ont réussi. Les `WARN` restent à examiner : un essai GPU différé dans une VM ou un pilote non identifié ne vaut pas certification physique. Un `KO` fait échouer le doctor et interdit de conclure « codecs validés ».

| Échec ou avertissement | Premier diagnostic | Suite |
|---|---|---|
| RPM absent ou `ffmpeg-free still installed` | `rpm -q ffmpeg ffmpeg-free` et relire la politique `ENABLE_RPMFUSION` | Corriger la transaction par le parcours de maintenance prévu ; pas de swap manuel aveugle. |
| `ffmpeg:... decoder not matched` | Vérifier les capacités visibles via `ffmpeg -hide_banner -decoders` | Vérifier les dépôts, paquets et options de compilation avant de conclure à un codec absent. |
| `required B580 hardware encoder missing` | `ffmpeg -hide_banner -encoders` | Confirmer la disponibilité du chemin VA-API voulu avant de chercher une cause côté GPU. |
| `no matching /dev/dri/renderD* node` ou profil VA-API manquant | `./diagnostics/graphics-doctor` et journaux du pilote `xe` | Examiner la carte, les permissions et le pilote ; ne pas forcer `renderD128` ni remplacer les pilotes sur supposition. |
| `VA-API functional` en `KO` | Lire le rapport `reports/<RUN_ID>-vaapi-smoke.txt` indiqué par le doctor | Analyser le codec précis en échec, corriger et relancer le diagnostic sur le PC. |

Le diagnostic logiciel doit être complété par une lecture vidéo et les essais matériels requis en [Gate 3](QUALIFICATION.md). La pile n'active pas `libdvdcss`, le déchiffrement Blu-ray protégé ou d'autres composants à usage spécifique par défaut.
