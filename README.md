# scriptBackup
#Auteur: Marquis Jérôme
#URL   : https://jerome-marquis.ch

Les paquets suivant sont utilisé dans le script:
    - mutt
    - duplicity


./backup.sh --help pour afficher l'aide

Vous devez pouvoir utiliser le script en modifiant uniquement les paramètres dans la partie Configuration du script

Du à un bug de duplicity je supprime le cache de duplicity à chaque backup (ligne 62)
Si votre backup est fait uniquement en local vous pouvez essayer de commenter cette ligne

Si vous laisser le répertoire de LOG par défaut, n'oubliez pas de créer le répertoire /var/log/backup


Problème que vous pouvez rencontrer:
    ROOT_DESTINATION='backup':
        Pour pouvoir faire la copie de mon serveur vers mon synology (à travers internet) j'ai du créer le répertoire /volume1/backup et j'ai ensuite du faire un lien symbolique à la racine avec les droit 777
        Je n'ai pas pu faire directement la copie vers /volume1/backup 
        
