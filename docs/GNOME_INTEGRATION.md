# GNOME / Nautilus — intégration

L'objectif n'est pas de copier un thème externe mais d'obtenir un bureau Fedora GNOME cohérent, moderne et maintenable.

Le socle GNOME gère Nautilus, GVfs pour SMB/MTP/caméra/FUSE, les portails GNOME, Flatpak et les composants nécessaires à l'intégration du bureau. Les applications utilisateur sont volontairement séparées dans le scope `APPLICATIONS`.

## Politique applicative

Les applications graphiques installées automatiquement par le projet doivent utiliser **GTK4** et **libadwaita** afin de conserver une interface GNOME cohérente. La liste versionnée est `manifests/packages-applications-gtk4.txt` et sa justification est documentée dans `GTK4_APPLICATIONS.md`.

**Ptyxis** est le terminal géré par le projet. L'intégration terminal de Nautilus repose sur le comportement Fedora/GNOME prévu pour Ptyxis, sans extension terminal additionnelle gérée par ce dépôt.

Les réglages de rendu de police, le scaling, VRR/HDR et les options expérimentales Mutter restent aux valeurs Fedora/GNOME par défaut tant qu'une correction n'est pas justifiée. Les extensions GNOME tierces sont désactivées par défaut afin de réduire les variables lors d'un crash Shell/Mutter.
