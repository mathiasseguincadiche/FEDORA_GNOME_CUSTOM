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

Les applications Flatpak sont mises à jour volontairement via GNOME Software ou :

```bash
flatpak update
```

Le projet ne crée aucun timer/service d'installation Flatpak silencieuse.

## Sauvegarde quotidienne

Le timer Restic sauvegarde les données utilisateur uniquement lorsque le repository et la passphrase sécurisée sont accessibles.

Contrat :

- chiffrement obligatoire ;
- passphrase exclue du backup ;
- pas de prune automatique ;
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
