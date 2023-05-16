import serial
from time import sleep
import random

import socket


class Moteur:
    def __init__(self) -> None:
        pass

    def test(self):
        with serial.Serial("COM7", 9600, timeout=30) as ser:
            for _ in range(50):
                x = random.randint(0, 359)
                ser.write(f"0,{x}.0,0,0\n".encode())
                print(f"Commande : {x}")
                if x < 0:
                    print(f"Commande absolue : {360 + x}")
                sleep(5)


class Comm:
    def __init__(self) -> None:
        self.ip = "192.168.4.1"
        self.port = 1234

    def client(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            # Connection au socket demandé
            sock.connect((self.ip, self.port))
            print(f"Connecte a {self.ip}:{self.port}")
            choice = int(input("CMD : "))
            match choice:
                case 0:
                    pos = float(input("POS : "))
                    message = f"$setPos;{pos}"
                case 1:
                    step = int(input("STEP : "))
                    message = f"$setStep;{step}"
                case 2:
                    message = f"$setZero"
                case 3:
                    speed = int(input("SPEED : "))
                    message = f"$setSpeed;{speed}"
                case 4:
                    message = f"$getPos"
                case 5:
                    message = f"$getMov"
                case _:
                    message = ""
            # Envoyer le message encodé en UTF-8
            if message != "":
                print(message)
                sock.sendall(bytes(message, "utf-8"))
            # Récupérer les données du serveur dans un buffer de 1024 bytes
            response = str(sock.recv(1024), "utf-8")
            print(f"Recu: {response}")
    def client2(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            # Connection au socket demandé
            sock.connect((self.ip, self.port))
            print(f"Connecte a {self.ip}:{self.port}")
            while True:
                try:
                    # Envoyer le message encodé en UTF-8
                    message = input("MESSAGE :")
                    if message != "":
                        print(message)
                        sock.sendall(bytes(message, "utf-8"))
                    # Récupérer les données du serveur dans un buffer de 1024 bytes
                    # response = str(sock.recv(1024), "utf-8")
                    # print(f"Recu: {response}")
                except KeyboardInterrupt:
                    break

def main():
    client = Comm()
    client.client2()


if __name__ == "__main__":
    main()
