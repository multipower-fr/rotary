void setup() {
    Serial.begin(9600);
    Serial1.begin(115200);
    while (!Serial) {;}
    while (!Serial1) {;}
}

void loop() {
    String recv;
    if (Serial.available() > 0) {
        recv = Serial.readString();
        recv.trim();
        Serial1.print(recv);
        Serial.print(recv + "0");
    }
    if (Serial1.available() > 0) {
        recv = Serial1.readString();
        recv.trim();
        Serial.print(recv + "1");
        Serial1.print(recv);
    }
}