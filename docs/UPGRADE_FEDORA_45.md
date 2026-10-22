# Migration facultative d’un ancien Fedora 44 vers Fedora 45

Ce document concerne uniquement un poste qui exécute déjà Fedora 44. **Pour ton installation neuve directe Fedora 45 / GNOME 51, suivre [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md). Aucune migration n’est requise.**

La configuration principale cible déjà Fedora 45. Un ancien poste doit conserver explicitement `HOST_RELEASE="44"` dans son override local jusqu’à la finalisation de sa migration. Le profil Fedora 45 doit être promu avec le média final authentifié, les paquets stables revus et la CI du commit exact avant une mutation. Le statut `pending` n’est jamais contourné.

La promotion et les limites des laboratoires sont décrites dans [FEDORA45_PRIMARY.md](FEDORA45_PRIMARY.md).

## Mise à niveau Fedora 44 vers Fedora 45

Mettre Fedora 44 complètement à jour et démarrer/finaliser ce résultat avant la migration :

```bash
./control.sh update all
./control.sh update reboot
./control.sh update finalize
./control.sh upgrade plan
./control.sh upgrade prepare
./control.sh upgrade status
```

`prepare` exige le profil final, le HOST physique, Secure Boot désactivé, un Git propre, le système source à jour et aucune mise à jour projet déjà en attente. Il résout la dernière stable Linux amont pour Fedora 45, puis effectue une sauvegarde Borg du **HOST et des fichiers utilisateur uniquement**, sans arrêter, copier ni exporter de VM. Les disques, XML, NVRAM et états TPM des VM restent exclusivement sous la gestion des exports manuels du propriétaire. L'espace de staging, le support externe et les preuves d'intégrité/restitution du HOST sont contrôlés. Il télécharge ensuite la transaction DNF5 system-upgrade, sans `--allowerasing`, sans saut de paquets et sans redémarrage automatique.

Relire les suppressions/conflits éventuels de la transaction. Le redémarrage est une action séparée :

```bash
./control.sh upgrade reboot
# après retour en session Fedora 45 :
./control.sh upgrade finalize
```

`finalize` exige le même commit et la même configuration, un boot différent, Fedora 45, GNOME 51, le journal DNF, une base de paquets cohérente et le noyau amont prévu réellement démarré. Il active ensuite le profil 45 dans l’override local sans supprimer les autres réglages et installe les quatre archives GNOME 51 du profil promu, avec vérification des hashes, UUID, major et schémas. Exécuter la finalisation depuis le compte GNOME, sans sudo. La phase `extensions-installed` demande une déconnexion normale puis une nouvelle connexion ; le code de retour 20 signifie qu’une action reste à effectuer. Relancer alors `./control.sh upgrade finalize` : le diagnostic doit confirmer le bureau et les extensions effectivement actifs avant le statut completed. Toute divergence bloque la finalisation ; elle n'est jamais annoncée comme réussie.

Le profil, les médias et les verrous entrent dans l'empreinte de configuration : les anciennes preuves Golden deviennent obsolètes. Refaire WSL2 → VirtualBox avec validation visuelle → matériel physique, restauration isolée et reprise VM.

## Qualification de la session GNOME 51 après migration

La validation finale appelle maintenant `python3 scripts/validation/gnome51-extension-audit.py --live` **depuis la session GNOME de l'utilisateur**. Cette vérification fail-closed exige six rôles actifs, les métadonnées GNOME 51 et la provenance des quatre extensions épinglées. Elle ne peut pas réussir sur un profil `pending` et ne contourne pas le système de signatures du média.

En cas d'erreur, la phase reste `extensions-installed` ; corriger le paquet RPM incompatible ou l'extension concernée, se déconnecter/reconnecter normalement, puis relancer `./control.sh upgrade finalize`. Ne pas désactiver le vérificateur pour annoncer `completed`.

## Récupération et qualification physique — Gate 3

Le retour au noyau N-1 ne revient **pas** de Fedora 45 à Fedora 44. Une récupération de l'OS repose sur la sauvegarde, le média connu et la reconstruction isolée décrite dans [BACKUP_RESTORE.md](BACKUP_RESTORE.md).

Mesurer sur la machine réelle : GNOME/Wayland, Arc B580 et `xe`, Vulkan/Steam/Proton, écran 1440p/~240 Hz, veille/reprise, réseau, audio et périphériques. Conserver le cas à qualifier du redémarrage direct avec session GNOME ouverte, déjà observé dans le laboratoire QEMU : aucun timeout système ni contrôle de coredump n'est neutralisé.

Références : [DNF5 system-upgrade](https://dnf5.readthedocs.io/en/latest/commands/system-upgrade.8.html), [clés Fedora](https://fedoraproject.org/security/), [calendrier GNOME](https://release.gnome.org/calendar/).
