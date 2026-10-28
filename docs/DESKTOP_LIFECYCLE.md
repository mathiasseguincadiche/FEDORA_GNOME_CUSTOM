# Desktop & Lifecycle — politique Golden Workstation

La version applicable est celle de [`../VERSION`](../VERSION).

## Capacités quotidiennes

La workstation certifie notamment :

- GNOME Keyring / Secret Service ;
- portals Wayland ;
- impression/scan driverless ;
- VPN NetworkManager ;
- TuneD PPD ;
- français/dictionnaires/polices ;
- Remmina ;
- support mobile ;
- Intel Arc compute.

## RPM Fedora

`/etc/dnf/automatic.conf` est convergé avec :

- téléchargement automatique : **oui** ;
- installation automatique : **non** ;
- reboot automatique : **jamais**.

`dnf5-automatic.timer`, `fstrim.timer` et, lorsqu'il existe, `fwupd-refresh.timer` sont activés.

Le timer fwupd rafraîchit les métadonnées ; il ne flashe aucun firmware de façon autonome.

## Flatpak

Politique :

```text
LIFECYCLE_FLATPAK_UPDATE_POLICY=manual
```

Les applications Flatpak sont mises à jour volontairement avec `flatpak update`, `./control.sh update flatpak` ou :

```bash
./control.sh update all
```

Le mode complet met aussi à jour Flatpak lorsque les RPM sont déjà à jour, sans demander de redémarrage dans ce cas. Une transaction RPM préparée reste appliquée et finalisée après le redémarrage prévu.

Le projet ne crée aucun timer/service d'installation Flatpak silencieuse.

## GNOME Logiciels

GNOME Logiciels reste disponible pour parcourir le catalogue et installer de nouvelles applications, mais ne propose plus de voie parallèle de mise à jour : le module lifecycle installe une base dconf système dédiée et verrouille `org.gnome.software` `download-updates=false` et `allow-updates=false`, en conservant les entrées du profil dconf existant. Les mises à jour RPM passent par la transaction sauvegardée du projet.

Après APPLY, se déconnecter, se reconnecter, puis lancer `./diagnostics/lifecycle-doctor`. Une valeur utilisateur ou un profil dconf personnalisé qui contourne la politique fait échouer ce contrôle. Ne pas supprimer PackageKit ou DNF5 pour autant.

GNOME Disques (`gnome-disk-utility`) fait partie de la couche d'intégration ; Flatseal est livré depuis Flathub (provenance upstream, sans badge « verified »).

## Sauvegarde quotidienne

Le timer Borg sauvegarde les données utilisateur uniquement lorsque le disque externe (ou le dépôt distant) est accessible.

Contrat :

- dépôt non chiffré par décision du propriétaire (ADR 0014) ;
- dossier `secrets` exclu des archives ;
- rétention automatique selon la politique configurée, séparée des archives pré-APPLY ;
- absence du disque externe = skip propre ;
- backup pré-APPLY indépendant et fail-closed.

## Veille / affichage

Chaque preuve suspend possède un `cycle_id` unique et un fingerprint runtime incluant la stack graphique critique.

Un changement de kernel, firmware GPU, Mesa, Mutter ou GNOME Shell impose de nouvelles preuves sensibles.

## KVM

Le host KVM fait partie de `final-certification` lorsque `ENABLE_KVM=true`.

La certification des invités reste une étape runtime distincte :

```bash
scripts/kvm/runtime_certification.sh
```

Le réseau KVM lui-même utilise un guard fail-closed : un changement de connectivité passe d'abord en mode d'urgence avant reconstruction des règles normales.

## Limite physique

La CI ne simule pas Arc B580/Wayland/240 Hz/suspend, les deux NVMe ni le LAN physique réel.

La certification finale reste bare-metal.
