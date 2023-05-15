#include <Stepper.h>

// Constraints
#define STEPS_PER_REV 2048
#define MAX_SPEED 15
#define MAXLEN 64

// Defaults
#define SOFT_UART_BAUD 300
#define USB_BAUD 9600
#define DEFAULT_SPEED MAX_SPEED

// Uncomment and comment RELEASE to use the USB Port
// #define DEBUG
#define RELEASE

// #define FLOAT_SPF

const int IN1 = 8;
const int IN2 = 9;
const int IN3 = 10;
const int IN4 = 11;

const float STEPS_PER_DEG = STEPS_PER_REV / 360.0;

float ctrl_angle, pos_deg = 0.0;

int ctrl_commande, ctrl_vitesse, ctrl_steps, command_changed, sens, pos_steps, moving = 0;

Stepper StepperMotor(STEPS_PER_REV, IN1, IN3, IN2, IN4);

void parse() {
#ifdef DEBUG
    while (Serial.available() > 0) {
        // Format :
        // ctrl_commande,ctrl_angle,ctrl_vitesse,ctrl_steps\n
        // Parse le CSV
        ctrl_commande = Serial.parseInt();
        ctrl_angle = Serial.parseFloat();
        ctrl_vitesse = Serial.parseInt();
        ctrl_steps = Serial.parseInt();
        if (Serial.read() == '\n') {
            // 4 commandes seulement :
            // setPos (0)
            // setStep (1)
            // setZero (2)
            // setSpeed (3)
            // getPos (4)
            // getMov (5)
            ctrl_commande = constrain(ctrl_commande, 0, 5);
            // Contraindre l'angle
            ctrl_angle = constrain(ctrl_angle, -359.0, 359.0);
            if (ctrl_angle < 0.0) {
                // Ramener l'ctrl_angle en valeur absolue
                ctrl_angle = 360 + ctrl_angle;
            }
            // Empêcher sur-vitesse
            ctrl_vitesse = constrain(ctrl_angle, 1, MAX_SPEED);
            // Flag de commande
            command_changed = 1;
        }
}
#else
    while (Serial1.available() > 0) {
        // Format :
        // ctrl_commande,ctrl_angle,ctrl_vitesse,ctrl_steps\n
        // Parse le CSV
        ctrl_commande = Serial1.parseInt();
        ctrl_angle = Serial1.parseFloat();
        ctrl_vitesse = Serial1.parseInt();
        ctrl_steps = Serial1.parseInt();

        if (Serial1.read() == '\n') {
            // 4 commandes seulement :
            // setPos (0)
            // setStep (1)
            // setZero (2)
            // setSpeed (3)
            // getPos (4)
            // getMov (5)
            ctrl_commande = constrain(ctrl_commande, 0, 5);
            // Contraindre l'angle
            ctrl_angle = constrain(ctrl_angle, -359.0, 359.0);
            if (ctrl_angle < 0.0) {
                // Ramener l'ctrl_angle en valeur absolue
                ctrl_angle = 360 + ctrl_angle;
            }
            // Empêcher sur-vitesse
            ctrl_vitesse = constrain(ctrl_angle, 1, MAX_SPEED);
            // Flag de commande
            command_changed = 1;
#ifndef RELEASE
            Serial.println(ctrl_angle);
            Serial.println(ctrl_commande);
#endif
        }
    }
#endif
}

void setPos() {
    int shifted_steps_dest, ctrl_angle_steps, steps_to_move, oneeighty;
    if (ctrl_angle != 0) {
        // Conversion en steps
        ctrl_angle_steps = round(ctrl_angle * STEPS_PER_DEG);
        // Si la position = 0;
        if (pos_steps == 0) {
            if (ctrl_angle > 180) {
                shifted_steps_dest = -(STEPS_PER_REV - ctrl_angle_steps);
            }
            else {
                shifted_steps_dest = ctrl_angle_steps;
            }
            // Sinon
        }
        else {
            oneeighty = (pos_steps < STEPS_PER_REV / 2) ? pos_steps + STEPS_PER_REV / 2 : pos_steps - STEPS_PER_REV / 2;
            // 180 supérieur a la position
            // Trouve le cadran de la position
            if (oneeighty > pos_steps) {
                if (ctrl_angle_steps > oneeighty) {
                    shifted_steps_dest = -((2048 - ctrl_angle_steps) + pos_steps);
                }
                else {
                    shifted_steps_dest = ctrl_angle_steps - pos_steps;
                }
            }
            else {
                // Cadran opposé
                if (ctrl_angle_steps < oneeighty) {
                    shifted_steps_dest = (2048 - pos_steps) + ctrl_angle_steps;
                }
                /*else if (ctrl_angle_steps > pos_steps) {
                    shifted_steps_dest = ctrl_angle_steps - pos_steps;
                }*/
                else {
                    shifted_steps_dest = ctrl_angle_steps - pos_steps;
                }
            }
        }
        pos_steps = ctrl_angle_steps;
    }
    else {
        // Retour à 0
        if (abs(pos_steps) < abs(STEPS_PER_REV - pos_steps)) {
            shifted_steps_dest = -pos_steps;
        }
        else {
            shifted_steps_dest = abs(STEPS_PER_REV - pos_steps);
        }

        pos_steps = 0;
    }
    variable_plus_step(shifted_steps_dest);
}

void setStep() {
    int next_pos = pos_steps + ctrl_steps;
    if (next_pos >= STEPS_PER_REV) {
        next_pos = next_pos - STEPS_PER_REV;
    }
    variable_plus_step(ctrl_steps);
    pos_steps = next_pos;
}

void setSpeed() {
    StepperMotor.setSpeed(ctrl_vitesse);
}

void getPos() {
    char sentBuf[MAXLEN];
    byte writeBuf[14];
    char floatBuf[MAXLEN];
    String printString;
    if (pos_steps > 0) {
        pos_deg = pos_steps / STEPS_PER_DEG;
        // Printf Arduino ne supporte pas les floats
#ifdef FLOAT_SPF
        snprintf(sentBuf, sizeof(sentBuf), "%d,%03.1f,%04d\n", ctrl_commande, pos_deg, pos_steps);
#else
        dtostrf(pos_deg, 5, 1, floatBuf);
        snprintf(sentBuf, sizeof(sentBuf), "%d,%s,%04d;", ctrl_commande, floatBuf, pos_steps);
#endif
        printString = String(sentBuf);
        printString.getBytes(writeBuf, printString.length() + 1);
    }
    else {
        pos_deg = 0.0;
#ifdef FLOAT_SPF
        snprintf(sentBuf, sizeof(sentBuf), "%d,%03.1f,%04d\n", ctrl_commande, pos_deg, pos_steps);
#else
        dtostrf(pos_deg, 5, 1, floatBuf);
        snprintf(sentBuf, sizeof(sentBuf), "%d,%s,%04d;", ctrl_commande, floatBuf, pos_steps);
#endif
        printString = String(sentBuf);
        printString.getBytes(writeBuf, printString.length() + 1);
    }
#ifndef RELEASE
    Serial.println(printString);
#else
    // Serial.write(writeBuf, sizeof(writeBuf));
    // Serial1.write(writeBuf, sizeof(writeBuf));
    Serial.print(printString);
    Serial1.print(printString);
#endif
}

void getMov() {
    char sentBuf[MAXLEN];
    String printString;
    sprintf(sentBuf, "5,%07d", moving);
    printString = String(sentBuf);
    Serial1.println(printString);
}

// Modifie la variable moving et step
void variable_plus_step(int steps) {
    moving = 1;
    StepperMotor.step(steps);
    moving = 0;
}

void setup() {
    // 15RPM
    StepperMotor.setSpeed(DEFAULT_SPEED);
    // Connection PC
    Serial.begin(USB_BAUD);
    Serial.flush();
    // Connection ESP
    Serial1.begin(SOFT_UART_BAUD);
    Serial1.flush();
    // Initialise la position 0
    pos_steps = 0;
}

void loop() {
    parse();
    if (command_changed == 1) {
        switch (ctrl_commande) {
            // Commande setPos
        case 0:
            setPos();
            break;
        case 1:
            setStep();
            break;
        case 2:
            pos_steps = 0;
            pos_deg = 0.0;
            break;
        case 3:
            setSpeed();
            break;
        case 4:
            getPos();
            break;
        case 5:
            getMov();
            break;
        }
        command_changed = 0;
    }
}
