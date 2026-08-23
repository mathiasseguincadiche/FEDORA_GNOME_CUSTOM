# Backup / Restore

Restic est le mécanisme de backup. Les secrets et mots de passe ne sont jamais stockés dans Git.

`prepare-preapply-backup.sh` capture `/etc`, `/boot`, la configuration utilisateur GNOME et, si présent, le profil GNOME Shell. Il exécute ensuite un `restic check` partiel et écrit `state/preapply-backup.ok` uniquement si un snapshot vérifié existe.

Le dépôt n'invente pas le chemin du SSD externe : configurez explicitement `BACKUP_REPOSITORY` et un fichier mot de passe protégé.
