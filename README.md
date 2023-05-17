# Documentation carte NodeMCU pour `rotary`

## Montage

![Diag Montage](./docs/Diagramme%20montage.jpg)

## Prérequis pour le firmware

- Une carte basée sur l'`ESP8266`
- [Java JDK](https://www.microsoft.com/openjdk)
- L'IDE [ESPlorer](https://github.com/4refr0nt/ESPlorer)
- [`NodeMCU-PyFlasher`](https://github.com/marcelstoer/nodemcu-pyflasher)
- [git](https://git-scm.com/download/win)
- [gh](https://github.com/cli/cli)

## Génération du firmware

Rendez-vous sur le [site officiel](https://nodemcu-build.com/) de création des firmwares NodeMCU

Une fois un email valide entré, choisir les options suivantes dans les choix :

- `bit`
- `encoder`
- `file`
- `gpio`
- `net`
- `node`
- `softuart`
- `tmr`
- `uart`
- `wifi`

Appuyez sur `Start your build`

Vous recevrez un email avec deux liens. 

Le firmware à télécharger est le `float`

## Préparation de la carte

Ouvrez le gestionnaire de périphérique (accessible via la recherche Windows), dépliez la section `Ports (COM et LPT)`, et branchez votre carte.  
Une fois la carte branchée, utilisez le menu `Actions` puis `Rechercher des modifications sur le matériel`, une entrée devrait apparaître, gardez le numéro à côté de `COM` en tête

Faites clic-droit sur le port - `Propriétés` - `Paramètres du Port` et vérifiez que les champs sont comme dans ce tableau

| Champ              | Valeur |
| ------------------ | ------ |
| `Bits par seconde` | 115200 |
| `Bits de données`  | 8      |
| `Parité`           | Aucune |
| `Bits d'arrêt`     | 1      |
| `Contrôle de flux` | Aucun  |

## Flash du firmware

Ouvrez `NodeMCU-PyFlasher`

| Champ              | Valeur                           |
| ------------------ | -------------------------------- |
| `Serial Port`      | Le port relevé plus tôt (`COMn`) |
| `NodeMCU Firmware` | Le firmware téléchargé           |
| `Baud Rate`        | 115200                           |
| `Erase Flash`      | yes                              |

### Passage en mode bootloader 

Sur la carte se trouve des boutons `Boot` et `EN`

Pour passer en mode bootloader, avec la carte branchée au PC, gardez enfoncé le bouton `Boot`, appuyez sur `EN` et relâchez le tout

Vous êtes en mode bootloader et vous pouvez cliquer sur `Flash NodeMCU`

Patientez jusqu'à la fin de la procédure et ensuite, débranchez et rebranchez la carte

## Ajout du script

Ouvrez `ESPlorer.bat` dans le dossier d'ESPlorer

Dans le haut de la fenêtre, choisir le port COM, mettre `115200` dans la vitesse, et vérifiez que `CR` et `LF` est coché, décocher `RTS` et `DTR` est aussi nécessaire

Dans l'en-tête, appuyez sur `Open` et appuyez sur le bouton `Reset`, le terminal devrait afficher des messages

Une fois que ceci est fait, ouvrez une fenêtre de PowerShell (accessible via la recherche Windows)

Si ce n'est pas déjà fait, connectez-vous à l'utilitaire de GitHub `gh`

```ps1
gh auth login
```

Naviguez jusqu'au dossier où vous souhaitez les données et exécutez

```ps1
gh repo clone multipower-fr/rotary 
```

Une fois celui-ci ouvert, en bas de l'éditeur, utilisez le bouton `Upload`

Sélectionnez tous les fichiers dans le dossier [`rotary/lua`](./lua/) avec la touche `Maj` et attendez la fin du processus

Redémarrez votre carte avec le bouton `Reset` et connectez-vous au hotspot Wi-Fi avec les informations suivantes :

| SSID       | Mot de Passe | IP            | Port   |
| ---------- | ------------ | ------------- | ------ |
| `Rubisoft` | `Rubisoft`   | `192.168.4.1` | `1234` |

###### SSID et Mot de Passe modifiable dans le fichier [`credentials.lua`](./lua/credentials.lua), IP dans [`init.lua`](./lua/init.lua) et port dans [`control.lua`](./lua/control.lua)

## Arduino

Installez l'[Arduino IDE](https://www.arduino.cc/en/software) et branchez l'Arduino en USB

Ouvrez `arduino/moteur/moteur.ino`

Dans le menu de choix de carte, choisir la carte branchée et faites upload

## Schéma de commande

| Commande                    | Retour attendu                   |
| --------------------------- | -------------------------------- |
| `$0000setPos;<pos_degrees>` | `setPosACK`                      |
| `$0000setStep;<pos_step>`   | `setStepACK`                     |
| `$0000setSpeed;<speed>`     | `setSpeedACK`                    |
| `$0000setZero`              | `setZeroACK`                     |
| `$0000getPos`               | `getPosACK;<pos_deg>;<pos_step>` |


## Interface PC

La documentation de l'interface PC est générée par [`rustdoc`](https://doc.rust-lang.org/rustdoc/what-is-rustdoc.html).

Elle peut-être lue dans le code de l'exécutable ([`main.rs`](./rs/src/main.rs)), ou compilée pour consommation par `cargo doc` une fois Rust installé

### Prérequis

- [Visual Studio](https://visualstudio.microsoft.com/) en sélectionnant `Développement Desktop en C++` dans `Charges de Travail` et `Anglais` (en plus de `Français`) dans `Modules Linguistiques`
- [Rustup](https://rustup.rs/), l'installateur de Rust

Ouvrez une fenêtre PowerShell en tant qu'Administrateur et exécuter les commandes suivantes :

```ps1
# Si cela n'a pas été déjà fait : 
# Se connecter a votre compte GitHub
gh auth login
# Cloner la repo
gh repo clone multipower-fr/rotary

# Installez Rust Stable
rustup toolchain install stable
# Allez dans le dossier du code
cd rs
# Vous pouvez compiler la documentation dans un format HTML en utilisant
cargo doc --open
```