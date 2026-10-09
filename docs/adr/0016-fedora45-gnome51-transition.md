# ADR 0016 — Profils de transition Fedora 45 / GNOME 51

Statut : accepté pour la préparation ; promotion Fedora 45 encore pending. Précise ADR 0001.

Chaque release associe OS, major GNOME, média signé, archives d'extensions et preuves CI. Fedora 44/GNOME 50 reste actif jusqu'à la promotion d'un profil Fedora 45 final vérifié. Un conteneur Beta ou un candidat d'extension ne devient pas une certification de production.

Les guards utilisent la release sélectionnée, le major GNOME attendu et le verrou propre au profil. Les profils et médias sont inclus dans l'empreinte des preuves. Le parcours majeur est séparé des mises à jour courantes : plan, sauvegarde Borg complète avec VM arrêtées, préparation DNF5, reboot explicite, finalisation du boot réel et requalification.

La récupération du noyau N-1 n'est pas un downgrade de l'OS. La reconstruction et la reprise des VM doivent être testées isolément avant qualification physique. Voir [UPGRADE_FEDORA_45.md](../UPGRADE_FEDORA_45.md).

Addendum 0.22.1 : trois extensions n'ayant pas de build GNOME 51, le verrou Fedora 45 les remplace par des extensions revues (Gtk4 DING, Show Desktop Button, Vitals). Les préfixes du verrou restent des noms de rôle ; le validateur n'autorise que l'identité d'origine ou son remplaçant, avec UUID et schéma cohérents. Cela ne promeut pas le profil : le média final et la qualification sur session GNOME 51 réelle restent requis.
