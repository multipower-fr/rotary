#include <SoftwareSerial.h>

SoftwareSerial mega(8,9);

void setup() {
    Serial.begin(9600);
    mega.begin(9600);
    if (!mega) { ; }
    mega.write("4,0.0,0,0\n");
}

void loop() {
    if (mega.available()) {
        Serial.write(mega.read());
    }
}