# Multimédia et codecs — Fedora 44

## Objectif

Fournir une pile multimédia GNOME complète et explicite, sans groupes de paquets opaques ni remplacement aveugle de composants graphiques.

## Fondation Fedora

Le manifeste `manifests/packages-multimedia-fedora.txt` installe :

- `gstreamer1-plugins-base` ;
- `gstreamer1-plugins-good` ;
- `gstreamer1-plugins-bad-free` ;
- `gstreamer1-plugin-openh264`.

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

## Intel Arc B580 et VA-API

Le pilote média Fedora `libva-intel-media-driver` reste le choix initial. La politique `INTEL_MEDIA_DRIVER_POLICY=auto` interdit tout remplacement arbitraire.

Sur la machine Arc B580, le projet exécute `vainfo` via le nœud DRM de rendu et vérifie la présence des familles H.264, HEVC, AV1 et VP9 :

- si les profils requis sont présents, le pilote Fedora est conservé ;
- si le probe fonctionne mais révèle un manque H.264/HEVC/AV1/VP9, le projet effectue un swap contrôlé vers `intel-media-driver` fourni par RPM Fusion ;
- si le probe VA-API est impossible, aucun swap n'est effectué sur simple supposition et un avertissement demande un diagnostic.

Le mode `rpmfusion-full` force explicitement le fournisseur RPM Fusion. Le mode `fedora-free` interdit le swap.

## Diagnostic

`diagnostics/media-doctor` est read-only et vérifie :

- présence des paquets multimédias attendus ;
- absence de `ffmpeg-free` lorsque le profil RPM Fusion est actif ;
- disponibilité des décodeurs FFmpeg H.264, HEVC, AV1, VP9, AAC, MP3, Opus et FLAC ;
- profils VA-API H.264, HEVC, AV1 et VP9 sur l'Arc B580 ;
- identification du pilote Intel iHD lorsque le probe le permet.

La pile multimédia n'active pas `libdvdcss`, le déchiffrement Blu-ray protégé ou d'autres composants à usage spécifique par défaut.
