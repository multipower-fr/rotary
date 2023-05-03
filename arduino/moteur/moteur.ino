#include <Stepper.h>

#define STEPS_PER_REV 2048
#define MAX_SPEED 15

enum MotorStates {
  STOPPED = 0,
  POS = 0,
  MOVING
};

const int IN1 = 8;
const int IN2 = 9;
const int IN3 = 10;
const int IN4 = 11;

const float STEPS_PER_DEG = STEPS_PER_REV / 360.0;

float ctrl_angle, pos_deg = 0.0;

int ctrl_commande, ctrl_vitesse, ctrl_steps, command_changed, sens, pos_steps = 0;

Stepper StepperMotor(STEPS_PER_REV, IN1, IN3, IN2, IN4);

void parse() {
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
      // getPos (3)
      ctrl_commande = constrain(ctrl_commande, 0, 3);
      // Contraindre l'angle
      ctrl_angle = constrain(ctrl_angle, -359.0, 359.0);
      if (ctrl_angle < 0.0) {
        // Ramener l'ctrl_angle en valeur absolue
        ctrl_angle = 360 + ctrl_angle;
      }
      // Empêcher sur-vitesse
      ctrl_vitesse = constrain(ctrl_angle, 0, MAX_SPEED);
      // Flag de commande
      command_changed = 1;
    }
  }
}

void setPos() {
  int shifted_steps_dest, ctrl_angle_steps, steps_to_move, oneeighty;
  int sens = 1;
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
        else if (ctrl_angle_steps > pos_steps) {
          shifted_steps_dest = ctrl_angle_steps - pos_steps;
        }
        else {
          shifted_steps_dest = ctrl_angle_steps - pos_steps;
        }
      }

      // shifted_steps_dest = ctrl_angle_steps - pos_steps;
    }
    Serial.println(shifted_steps_dest);
    Serial.println(pos_steps);
    /* Calculer le sens a prendre le plus efficace
    if (shifted_steps_dest < STEPS_PER_REV / 2) {
      sens = 1;
    } else {
      sens = -1;
    }
    */
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
  StepperMotor.step(shifted_steps_dest * sens);
}

void setStep() {
  int next_pos = pos_steps + ctrl_steps;
  if (next_pos > STEPS_PER_REV) {
    next_pos = next_pos - STEPS_PER_REV;
  }
  StepperMotor.step(ctrl_steps);
  pos_steps = next_pos;
}

void setup() {
  // 15RPM
  StepperMotor.setSpeed(15);
  Serial.begin(9600);
  Serial.flush();
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
      break;
    case 3:
      if (pos_steps >= 0) {
        pos_deg = pos_steps / STEPS_PER_DEG;
        // Garder la première décimale
        int tmp = pos_deg * 10;
        Serial.println(tmp / 10);
      }
      else {
        ;
      }
      break;
    }
    command_changed = 0;
  }
}
