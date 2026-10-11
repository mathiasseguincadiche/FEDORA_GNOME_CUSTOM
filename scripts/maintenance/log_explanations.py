#!/usr/bin/env python3
"""Produce a French operator summary without altering original technical evidence."""
import re

RULES = (
    (r"permission denied|access denied|selinux.*denied|avc:.*denied",
     "Accès refusé", "Un contrôle d'autorisation empêche l'opération.",
     "Vérifier les permissions et les refus SELinux, sans désactiver SELinux."),
    (r"no space left on device|disk full",
     "Espace disque insuffisant", "Le stockage ne dispose plus de l'espace requis.",
     "Vérifier l'espace libre et les volumes concernés avant de nettoyer."),
    (r"connection refused|connection timed out|network is unreachable",
     "Connexion réseau impossible", "La destination n'est pas joignable ou refuse la connexion.",
     "Vérifier le réseau, le service distant et les règles de pare-feu."),
    (r"unit .*failed|failed to start|service .*failed",
     "Service en échec", "Un service n'a pas démarré ou s'est arrêté en erreur.",
     "Consulter systemctl status et journalctl -u pour le service concerné."),
    (r"checksum mismatch|sha256.*mismatch|signature verification failed",
     "Contrôle d'intégrité échoué", "Un fichier ou une signature ne correspond pas à la valeur attendue.",
     "Ne pas installer le fichier ; vérifier la provenance et le téléchargement."),
    (r"backup.*failed|borg.*error|repository.*not found",
     "Sauvegarde en échec", "La sauvegarde ou l'accès au dépôt de sauvegarde a échoué.",
     "Vérifier le dépôt Borg et relancer un contrôle sans supprimer les anciennes sauvegardes."),
    (r"wake.on.lan|magic.packet|wake-on: d",
     "Réveil réseau à vérifier", "La configuration du réveil réseau semble incorrecte.",
     "Contrôler le BIOS, ethtool et le profil NetworkManager."),
    (r"va.api.*fail|sunshine.*fail|encoder.*fail",
     "Diffusion vidéo à vérifier", "Le serveur graphique ou l'encodeur vidéo rencontre un problème.",
     "Consulter le journal Sunshine et vérifier la session Wayland et VA-API."),
)

def explain(text):
    for pattern, title, cause, action in RULES:
        if re.search(pattern, text, re.IGNORECASE):
            return {"title":title,"explanation":cause,"action":action,
                    "certainty":"hypothèse : vérifier les journaux techniques"}
    return {"title":"Erreur technique non classée",
            "explanation":"Une erreur est signalée, mais sa cause ne peut pas être déterminée automatiquement.",
            "action":"Lire les lignes ERROR et le contexte dans main.log et modules.log.",
            "certainty":"cause non déterminée"}
