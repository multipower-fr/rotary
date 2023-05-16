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
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // FIFO queue
    let input_queue = HeapRb::<String>::new(255);
    // Recuperer Producteur et Consommateur
    let (input_queue_tx, mut input_queue_rx) = input_queue.split();
    thread::spawn(move || {
        user_input(input_queue_tx).unwrap();
    });
    let stream = TcpStream::connect("192.168.4.1:1234").await?;
    loop {
        let ready = stream
            .ready(Interest::READABLE | Interest::WRITABLE)
            .await?;
        if !input_queue_rx.is_empty() {
            let input = input_queue_rx.pop().unwrap();
            if ready.is_writable() {
                // Try to write data, this may still fail with `WouldBlock`
                // if the readiness event is a false positive.
                match stream.try_write(input.as_bytes()) {
                    Ok(_) => (),
                    Err(ref e) if e.kind() == io::ErrorKind::WouldBlock => continue,
                    Err(e) => {
                        return Err(e.into());
                    }
                }
            }
        }
        if ready.is_readable() {
            let mut data = vec![0; 1024];
            // Try to read data, this may still fail with `WouldBlock`
            // if the readiness event is a false positive.
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
fn user_input(
    mut input_queue_tx: Producer<String, Arc<SharedRb<String, Vec<MaybeUninit<String>>>>>,
) -> rustyline::Result<()> {
    // `()` can be used when no completer is required
    let mut rl = DefaultEditor::new()?;
    loop {
        let readline = rl.readline(">> ");
        match readline {
            Ok(line) => {
                input_queue_tx.push(line).unwrap();
            }
            Err(ReadlineError::Interrupted) => {
                STOP.store(true, Ordering::SeqCst);
                break;
            }
            Err(ReadlineError::Eof) => {
                STOP.store(true, Ordering::SeqCst);
                break;
            }
            Err(err) => {
                println!("Error: {:?}", err);
                break;
            }
        }
    }
    Ok(())
}
