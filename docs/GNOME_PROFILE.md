# Profil GNOME de référence

La cible est **Fedora 45 Workstation + GNOME 51 + Wayland**, avec Adwaita/libadwaita et Ptyxis. La configuration sélectionne exactement **six extensions fonctionnelles** décrites dans [GNOME_EXTENSIONS.md](GNOME_EXTENSIONS.md) : Dash to Dock, AppIndicator, Gtk4 Desktop Icons NG (DING), Show Desktop Button, Vitals et Tiling Assistant.

Le profil reste `pending` tant que le média final signé et les composants stables n’ont pas été promus. Le détail des conditions est dans [FEDORA45_PRIMARY.md](FEDORA45_PRIMARY.md).

## Contrat visible

- Dock à gauche, icônes 48 px, masquage intelligent pour l’OLED ; favoris déclarés dans la configuration.
- Dossier XDG Desktop `~/Bureau`, contenu réel visible par DING, Corbeille affichée, Home et volumes masqués.
- Show Desktop Button à l’extrémité gauche du panneau, raccourci `Super+D`.
- Vitals en haut à droite : CPU, RAM et réseau, rafraîchissement 2 s ; températures épinglées selon les capteurs du poste.
- Tiling Assistant pour le tuilage ; boutons réduire, agrandir et fermer à droite ; applications GTK3 harmonisées avec Adwaita.
- Blur My Shell désactivé ; Just Perfection, Dash to Panel et thèmes Yaru exclus de la baseline.

La charge B580 dans la barre Vitals n’est pas garantie. Les lectures matérielles `xe` et hwmon sont contrôlées séparément sur le PC physique.

## Sources et contrôles

`config/gnome-extensions.lock` et `profiles/fedora45/gnome-extensions.lock` doivent rester identiques. Ils épinglent DING 145/review 75162, Show Desktop Button 59/review 75965, Vitals 85/review 74743 et Tiling Assistant v56. Les RPM Dash to Dock et AppIndicator sont verrouillés dans `profiles/fedora45/gnome-rpms.json`.

`diagnostics/gnome-doctor` vérifie les extensions du socle et appelle `diagnostics/resource-monitor-doctor`. `diagnostics/polish-doctor` vérifie Tiling Assistant et la finition. Le diagnostic global inclut les deux couches.

La CI teste métadonnées GNOME 51, empreintes, schémas, réglages et activation des six extensions dans QEMU. La matrice GNOME du [système installé](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md) impose une preuve visuelle après APPLY et redémarrage. La Gate 3 reste l’autorité pour les températures Ryzen, la B580, l’écran et la veille.

Une nouvelle extension exige un besoin identifié, une source et une identité revues, une compatibilité GNOME 51 vérifiée et une nouvelle qualification. Les anciens composants Show Desktop Plus et Resource Monitor appartiennent au [profil Fedora 44 historique](HISTORICAL_FEDORA44.md).
