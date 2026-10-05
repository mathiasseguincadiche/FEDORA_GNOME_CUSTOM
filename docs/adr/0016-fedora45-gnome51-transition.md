# ADR 0016 — Profils de transition Fedora 45 / GNOME 51

Statut : accepté pour la préparation ; promotion Fedora 45 encore pending. Précise ADR 0001.

Chaque release associe OS, major GNOME, média signé, archives d'extensions et preuves CI. Fedora 44/GNOME 50 reste actif jusqu'à la promotion d'un profil Fedora 45 final vérifié. Un conteneur Beta ou un candidat d'extension ne devient pas une certification de production.

Les guards utilisent la release sélectionnée, le major GNOME attendu et le verrou propre au profil. Les profils et médias sont inclus dans l'empreinte des preuves. Le parcours majeur est séparé des mises à jour courantes : plan, sauvegarde Borg complète avec VM arrêtées, préparation DNF5, reboot explicite, finalisation du boot réel et requalification.

La récupération du noyau N-1 n'est pas un downgrade de l'OS. La reconstruction et la reprise des VM doivent être testées isolément avant qualification physique. Voir [UPGRADE_FEDORA_45.md](../UPGRADE_FEDORA_45.md).
