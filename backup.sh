#!/bin/bash
#
#Auteur: Marquis Jérôme
#URL   : www.swissappy.ch
##############################
#       CONFIGURATION        #
##############################
#
#! duplicity et mutt sont utilisé dans le script !
#
# Du à un bug de duplicity j'efface le cache de duplicity à chaque backup (ligne 62)
# Pour un backup en local vous pouvez essayer de commenter cette ligne
#
#Le mot de passe utilisé pour encrypté la sauvegarde
export PASSPHRASE='EntrerVotreMotDePasse'
#Le mot de passe pour le compte FTP (Si le protocol FTP est choisis)
export FTP_PASSWORD=''
#Protocole disponible: scp (SSH), ftp
PROTOCOL='scp'
#Le nom d'utilisateur pour se connecter au serveur de sauvegarde
USER='nomUtilisateur'
#Le serveur de sauvegarde
SERVER='serveurDestination.com'
#Le répertoire où sont stocké les logs
#(Vérifier que le répertoire backup existe dans /var/log/ sur le serveur de destination)
LOG="/var/log/backup/backup_`date +'%y_%m_%d.log'`"
#La liste des répertoires à sauvegarder
FOLDERS_SOURCE=(/home/
                /var/www)
#Le répertoire racine (sur le serveur de destination) ou seront sauvegarder les fichiers
ROOT_DESTINATION='backup'
#Les sous répertoire ou sont sauvegarder chaque répertoire source 
FOLDERS_DESTINATION=(home
                     www)
#Vérification de l'intégriter du backup: yes, no
INTEGRITY_VERIFICATION=no
#Envoie un mail si la sauvegarde c'est terminé avec des erreurs
SEND_ERROR_MAIL=yes
#Envoie un mail si la sauvegarde c'est terminé correctement
SEND_SUCCESS_MAIL=yes
#Adresse e-mail où sont envoyer les rapports
EMAIL='email@email.com'

##############################
#           SCRIPT           #
##############################
#On vérifie que les répertoire existe sur le serveur de sauvegarde, sinon on les créer

#Variable du script
SUCCESS_MESSAGE=""
ERROR_MESSAGE=""

#On regarde si on doit restaurer ou faire un backup
if [ "$1" == "backup" ]
then
    #On commence le backup
    echo "########################################################" >> $LOG
    echo "#BACKUP DE: `hostname` VERS: $SERVER" >> $LOG
    echo "########################################################" >> $LOG
    lenght=${#FOLDERS_SOURCE[@]}
    for ((i=0;i<$lenght;i++))
    do
        echo "#####################################################################################" >> $LOG
        echo "[$i] - Début de la sauvegarde de ${FOLDERS_SOURCE[$i]} le" `date +"%d-%m-%y à %T"` >> $LOG
        echo "#####################################################################################" >> $LOG
        #On commence la sauvegarde
        duplicity ${FOLDERS_SOURCE[$i]} $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/${FOLDERS_DESTINATION[$i]} >> $LOG 2>&1
        rm -rf ~/.cache/duplicity/*
    
        #On vérifie si la sauvegarde c'est bien passé
        if [ $? -eq 0 ]
        then
            LOG_MESSAGE="[$i] - Fin de la sauvegarde de ${FOLDERS_SOURCE[$i]} le `date +'%d-%m-%y à %T'`"
            echo $LOG_MESSAGE >> $LOG 
            SUCCESS_MESSAGE+="$LOG_MESSAGE\n"
        else
            LOG_MESSAGE="[$i] - Erreur lors de la sauvegarde de ${FOLDERS_SOURCE[$i]} le `date +'%d-%m-%y à %T'`"
            echo $LOG_MESSAGE >> $LOG
            ERROR_MESSAGE+="$LOG_MESSAGE\n"
        fi
    done

    if [ "$INTEGRITY_VERIFICATION" == "yes" ]
    then
        #On vérifie l'intégrité du backup
        for ((i=0;i<$lenght;i++))
        do
            echo "#####################################################################################" >> $LOG
            echo "[$i] - Début de la vérification de l'intégrité de ${FOLDERS_SOURCE[$i]} le `date +'%d-%m-%y à %T'`" >> $LOG
            echo "#####################################################################################" >> $LOG
            duplicity verify $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/${FOLDERS_DESTINATION[$i]} ${FOLDERS_SOURCE[$i]} >> $LOG 2>&1
    
            #On vérifie si la vérification de l'intégrité c'est bien passé
            if [ $? -eq 0 ]
            then
                LOG_MESSAGE="[$i] - Fin de la vérification de l'intégrité de ${FOLDERS_SOURCE[$i]} le `date +'%d-%m-%y à %T'`"
                echo $LOG_MESSAGE >> $LOG
                SUCCESS_MESSAGE+="$LOG_MESSAGE\n"
            else
                LOG_MESSAGE="[$i] - Erreur lors de la vérification de l'intégrité de ${FOLDERS_SOURCE[$i]} le `date +'%d-%m-%y à %T'`"
                echo $LOG_MESSAGE >> $LOG
                ERROR_MESSAGE+="$LOG_MESSAGE\n"
            fi
        done
    fi


    echo "########################################################" >> $LOG
    echo "#                     FIN DU BACKUP                    #" >> $LOG
    echo "########################################################" >> $LOG

    #On regarde si il faut envoyer un mail
    if [ "$SEND_SUCCESS_MAIL" == "yes" ] && [ "$SEND_ERROR_MAIL" == "yes" ]
    then
        #On envoie un mail qu'il y est eu ou non une erreur
        echo -e $ERROR_MESSAGE "\n"$SUCCESS_MESSAGE | mutt -s "Sauvegarde de `hostname`" -a $LOG -- $EMAIL

    elif [ "$SEND_SUCCESS_MAIL" == "yes" ]
    then
        #On envoie seulement le mail si il n'y a pas eu d'erreur
        echo -e $SUCCESS_MESSAGE | mutt -s "Sauvegarde de `hostname`" -a $LOG -- $EMAIL 

    elif [ "$SEND_ERROR_MAIL" == "yes" ]
    then
        #On envoie seuelement le mail i il y a eu des erreur
        if [ "$ERROR_MESSAGE" != "" ]
        then
            $ERROR_MESSAGE += "\n\n\n"`cat $LOG`
        fi
        echo -e $ERROR_MESSAGE | mutt -s "Sauvegarde de `hostname`" -a $LOG -- $EMAIL 
    fi

elif [ "$1" == "restore" ]
then
    #On regarde si on doit tout restaurer
    if [ "$2" == "all" ]
    then
        if [ -z "$4" ]
        then
            echo "Restauration de l'enssemble du backup."
            lenght=${#FOLDERS_SOURCE[@]}
            for ((i=0;i<$lenght;i++))
            do
                duplicity $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/${FOLDERS_DESTINATION[$i]} $3/${FOLDERS_DESTINATION[$i]} 2>&1 
            done
        else
            echo "Restauration de l'enssemble du répertoire racine $3"
            duplicity $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/$3 $4 2>&1
        fi

    elif [ "$2" == "one" ]
    then
        echo "Restauration du répertoire/fichier $4"
        duplicity --file-to-restore $4 $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/$3 $5/$4 2>&1

    elif [ "$2" == "time" ]
    then
        duplicity -t $3 $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/$4 $5 
    elif [ -z "$2" ]
    then
        echo "Que voulez-vous restauré ?"
        echo "                                  Tout restaurer: $0 restore all Destination"
        echo "    Restaurer l'enssemble d'un répertoire racine: $0 restore all repertoireRacine Destination"
        echo "              Restaurer un répertoire ou fichier: $0 restore one repertoireRacine NomFichierOuDossier Destination" 
        echo ""
        echo "    Exemple:" 
        echo "    Restaurer l'ensemble d'un répertoire racine:"
        echo "        $0 restore all Site-Web /tmp/Site-Web_restore"
        echo "    Restaurer un fichier ou un répertoire à l'intérieur d'un répertoire racine:"
        echo "        $0 restore one Site-Web Projets/Mon1erSite/image image_restore"
    else
        echo "Restauration de $2"
        duplicity $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/$2 $3 2>&1

    fi
elif [ "$1" == "remove" ]
then
    if [ -z $2 ]
    then
        echo "Veuillez indiquer un temps."
        echo "Entrer un nombre suivi d'un des caractères suivant \"s, m, h, D, W, M, Y\"."
        echo "Secondes: s
               Minutes: m
                 Heure: h
                  Jour: D
               Semaine: W
                  Mois: M
                Années: Y"
         echo ""
         echo "Exemple:
               Pour supprimer toute les sauvegardes plus vielle d'une année lancer la commande suivante:
               $0 remove 1Y"
    else
           duplicity remove-older-than $2 --force $PROTOCOL://$USER@$SERVER/$ROOT_DESTINATION/$FOLDERS_DESTINATION 2>&1

    fi


elif [ "$1" == "--help" ] || [ "$1" == "-h" ]
then
    echo "Manuel d'utilisation du script $0"
    echo ""
    echo '/!\ Avant toute utilisation il faut paramétrer le script /!\'
    echo "Pour se faire il faut ouvrir le script et éditer les variables dans la partie #CONFIGURATION#"
    echo ""
    echo "Utilisation du script:"
    echo "    Sauvegarder:"
    echo "        $0 backup"
    echo ""
    echo "    Restaurer:"
    echo "                                  Tout restaurer: $0 restore all * Destination"
    echo "    Restaurer l'enssemble d'un répertoire racine: $0 restore all repertoireRacine Destination"
    echo "              Restaurer un répertoire ou fichier: $0 restore one repertoireRacine NomFichierOuDossier Destination" 
    echo ""
    echo "    Exemple:" 
    echo "    Restaurer l'ensemble d'un répertoire racine:"
    echo "        $0 restore all Site-Web /tmp/Site-Web_restore"
    echo "    Restaurer un fichier ou un répertoire à l'intérieur d'un répertoire racine:"
    echo "        $0 restore one Site-Web Projets/Mon1erSite/image image_restore"
    echo ""
    echo "    Supprimer:"
    echo "        Entrer un nombre suivi d'un des caractères suivant \"s, m, h, D, W, M, Y\"."
    echo "        Secondes: s
                   Minutes: m
                     Heure: h
                      Jour: D
                   Semaine: W
                      Mois: M
                    Années: Y"
     echo ""
     echo "        Exemple:
                   Pour supprimer toute les sauvegardes plus vielle d'une année lancer la commande suivante:
                   $0 remove 1Y"

else
    echo "Erreur de syntaxe."
    echo "Afficher l'aide avec la commande suivate: $0 --help ou $0 -h"
fi



#On détruit les variables
unset lenght
unset PASSPHRASE
unset USER
unset SERVER
unset LOG
unset FOLDERS_SOURCE
unset FOLDERS_DESTINATION
unset ROOT_DESTINATION
unset PROTOCOL
unset FTP_PASSWORD
unset SEND_SUCCESS_MAIL
unset SEND_ERROR_MAIL
unset SUCCESS_MESSAGE
unset ERROR_MESSAGE
unset LOG_MESSAGE
unset EMAIL
