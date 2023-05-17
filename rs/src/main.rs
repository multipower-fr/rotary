//! Interface pour terminal pour un socket TCP
//! 
//! ## Communication
//! 
//! Communique par défaut avec un serveur TCP a l'addresse `192.168.4.1:1234`
//! 
//! ## Schéma de commande et NodeMCU
//! 
//! Voir [README.md](../../../../README.md)
//! 
//! ## Partie PC
//! 
//! ### Compilation :
//! 
//! #### Prérequis
//! - [git](https://git-scm.com/download/win) 
//! - [gh](https://github.com/cli/cli)
//! - [Visual Studio](https://visualstudio.microsoft.com/) en sélectionnant `Développement Desktop en C++` dans `Charges de Travail` et `Anglais` (en plus de `Français`) dans `Modules Linguistiques`
//! - [Rustup](https://rustup.rs/), l'installateur de Rust
//!
//! Ouvrez une fenêtre PowerShell en tant qu'Administrateur et exécuter les commandes suivantes :
//!
//! ```ps1
//! # Si cela n'a pas été déjà fait :
//! # Se connecter a votre compte GitHub
//! gh auth login
//! # Cloner la repo
//! gh repo clone multipower-fr/rotary
//!
//! # Installez Rust Stable
//! rustup toolchain install stable
//! # Allez dans le dossier de la crate (librairie)
//! cd rs
//! # Compiler la libarie (enlever le --release pour la version non-optimisée de développement)
//! cargo build --release
//! # Vous pouvez compiler la documentation dans un format HTML en utilisant
//! cargo doc --open
//! ```
//! Vous trouverez le `.exe` dans `target\release` (ou `target\debug` en cas de compilation en développement)
//! 

// Assurer une documentation
#![deny(rustdoc::broken_intra_doc_links)]
#![deny(missing_docs)]

#[macro_use]
extern crate lazy_static;

use ringbuf::{HeapRb, Producer, SharedRb};
use rustyline::error::ReadlineError;
use rustyline::DefaultEditor;

use tokio::io::Interest;
use tokio::net::TcpStream;

use std::io;
use std::mem::MaybeUninit;
use std::str::from_utf8;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;

lazy_static! {
    static ref STOP: AtomicBool = AtomicBool::new(false);
}

#[tokio::main]
/// Routine de communication
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // FIFO pour la transmission des inputs
    let input_queue = HeapRb::<String>::new(255);
    // Recuperer Producteur et Consommateur
    let (input_queue_tx, mut input_queue_rx) = input_queue.split();
    // Envoyer le producteur 
    thread::spawn(move || {
        user_input(input_queue_tx).unwrap();
    });
    // Initialiser le stream
    let stream = TcpStream::connect("192.168.4.1:1234").await?;
    loop {
        // Poll le serveur pour savoir si il est possible d'y écrire/lire
        let ready = stream
            .ready(Interest::READABLE | Interest::WRITABLE)
            .await?;
        // Ne rien faire si la queue FIFO est vide (i.e. aucune commande en attente)
        if !input_queue_rx.is_empty() {
            // Récupérer la valeur de l'entrée utilisateur
            let input = input_queue_rx.pop().unwrap();
            // Si on peut écrire
            if ready.is_writable() {
                // Essayer d'écrire
                match stream.try_write(input.as_bytes()) {
                    Ok(_) => (),
                    Err(ref e) if e.kind() == io::ErrorKind::WouldBlock => continue,
                    Err(e) => {
                        return Err(e.into());
                    }
                }
            }
        }
        // Si des données sont disponibles sur le socket
        if ready.is_readable() {
            // Buffer
            let mut data = vec![0; 1024];
            match stream.try_read(&mut data) {
                Ok(_) => {
                    println!("{}", from_utf8(&data).unwrap())
                }
                Err(ref e) if e.kind() == io::ErrorKind::WouldBlock => {
                    continue;
                }
                Err(e) => {
                    return Err(e.into());
                }
            }
        }
        if STOP.load(Ordering::SeqCst) {
            break;
        }
    }
    Ok(())
}

#[allow(clippy::type_complexity)]
/// 
fn user_input(
    mut input_queue_tx: Producer<String, Arc<SharedRb<String, Vec<MaybeUninit<String>>>>>,
) -> rustyline::Result<()> {
    // Initialise la gestion du terminal
    let mut rl = DefaultEditor::new()?;
    loop {
        // Affiche le prompt
        let readline = rl.readline(">> ");
        match readline {
            // Si la ligne est valide
            Ok(line) => {
                // Push dans la FIFO pour gestion par la fonction [`main()`]
                input_queue_tx.push(line).unwrap();
            }
            // CTRL + C
            Err(ReadlineError::Interrupted) => {
                // Signal pour faire quitter le client
                STOP.store(true, Ordering::SeqCst);
                break;
            }
            // CTRL + D
            Err(ReadlineError::Eof) => {
                STOP.store(true, Ordering::SeqCst);
                break;
            }
            // Erreur générique
            Err(err) => {
                println!("Error: {:?}", err);
                STOP.store(true, Ordering::SeqCst);
                break;
            }
        }
    }
    Ok(())
}
