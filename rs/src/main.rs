#[macro_use]
extern crate lazy_static;
extern crate futures;

use futures::future::try_join_all;
use ringbuf::{Consumer, HeapRb, SharedRb};
use std::fmt;
use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};
use std::sync::{Arc, Mutex};
use tokio::io::Interest;
use tokio::net::TcpStream;
use tokio::sync::Notify;
use tokio::task;
use tokio::time::{sleep, Duration};

use std::error::Error;
use std::io;
use std::str::from_utf8;

lazy_static! {
    static ref DONE: AtomicI32 = AtomicI32::new(0);
}

fn do_nothing() -> () {}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let stream = TcpStream::connect("192.168.4.1:1234").await?;
    loop {
        let ready = stream
            .ready(Interest::READABLE | Interest::WRITABLE)
            .await?;
        if ready.is_writable() {
            // Try to write data, this may still fail with `WouldBlock`
            // if the readiness event is a false positive.
            match stream.try_write(b"$getPos") {
                Ok(n) => {
                    println!("write {} bytes", n);
                }
                Err(ref e) if e.kind() == io::ErrorKind::WouldBlock => continue,
                Err(e) => {
                    return Err(e.into());
                }
            }
        }
        if ready.is_readable() {
            let mut data = vec![0; 1024];
            // Try to read data, this may still fail with `WouldBlock`
            // if the readiness event is a false positive.
            match stream.try_read(&mut data) {
                Ok(n) => {
                    println!("read {} bytes", n);
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
        sleep(Duration::from_millis(1000)).await;
    }
}

