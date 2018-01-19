#include <Brain.h>
#include <SoftwareSerial.h>
#define BAUDRATE 9600

Brain headset(Serial);
SoftwareSerial tgam(10,11); // RX, TX on other device
int latestByte, lastByte;
signed int checkSumAccum;
int packetIndex = 0, packetLength;
boolean isNewPacket = false;
int tgamPacket[32];

int signalQuality, meditation, attention, eegPowerLength;
int eegPower[8];
int rawLength, rawLo, rawHi, raw;

int led = 13;

void setup() {
  // set stuff up
  Serial.begin(9600); 
  tgam.begin(9600);
  pinMode(led, OUTPUT);

  // send command to output raw wave value, then change baud
  delay(1000);
  tgam.write(2); // actual command
  Serial.println("stuff written");
  blinkLED();

  // close serial
  delay(100);
  tgam.end();
  Serial.end();

  // reopen serial @ 57.6k baud
  delay(100);
  tgam.begin(57600);
  Serial.begin(57600);
}


void loop() {
  // do something
  newPacket();
//printMyPacket();
  // print raw
//  Serial.println(getRaw(rawLo, rawHi));
}


// debug
void printMyPacket() {
  while(tgam.available() > 0) {
    latestByte = tgam.read();
    Serial.println(latestByte);
  }
}

void newPacket() {
  while((tgam.available()) > 0) {
    latestByte = tgam.read();

    if(isNewPacket) {

      if(packetIndex==0) {
        packetLength = latestByte;
      }
      else if(packetIndex <= packetLength) {
        tgamPacket[packetIndex - 1] = latestByte;

        checkSumAccum += latestByte;
      }
      else if(packetIndex > packetLength) {
        // we're at the end
        int checkSumVal = latestByte;
        checkSumAccum = checkSum(checkSumAccum);

        if(checkSumVal == checkSumAccum) {
          // parse it out
          parseMyPacket();
        }
        else {
          // Checksum mismatch, send an error.
          Serial.println("ERROR: Checksum");
        }

        isNewPacket = false;
      }
      packetIndex++;
    }

    if((latestByte==170) && (lastByte==170)) {  // sync bytes in place (0xAA)
      isNewPacket = true;
      packetIndex = 0;
      checkSumAccum = 0;
    }

    lastByte = latestByte;   
  }
}

int checkSum(int sum) {
  // mask the upper bits (>8), then take one's complement
  sum &= 0xFF;
  sum = 255 - sum; // ~sum???

  return sum;
}

int getRaw(int localRawLo, int localRawHi) {
  int tempVal;

  tempVal = (localRawLo<<8) | localRawHi;
  return tempVal;
}

// some stuff here ..oOo..oOo..oOo..oOo..oOo..oOo..oOo..oOo..oOo..oOo..oOo..oOo
void parseMyPacket() {
  for (byte i = 0; i < (packetLength-1); i++) {
    switch (tgamPacket[i]) {
    case 2:
      signalQuality = tgamPacket[++i];
      break;
    case 4:
      attention = tgamPacket[++i];
      break;
    case 5:
      meditation = tgamPacket[++i];
      break;
    case 131:
      // ASIC_EEG_POWER: eight big-endian 3-byte unsigned integer values representing delta, theta, low-alpha high-alpha, 
      // low-beta, high-beta, low-gamma, and mid-gamma EEG band power values.
      // The next byte sets the length, usually 24 (Eight 24-bit numbers... big endian?)
      eegPowerLength = tgamPacket[++i];

      // Extract the values. Possible memory savings here by creating three temp longs?
      for(int j = 0; j < 8; j++) {
        eegPower[j] = ((unsigned long)tgamPacket[++i] << 16) | ((unsigned long)tgamPacket[++i] << 8) | (unsigned long)tgamPacket[++i];
      }
      break;
    case 128:
      rawLength = tgamPacket[++i];
      rawLo = tgamPacket[++i];
      rawHi = tgamPacket[++i];
      raw = getRaw(rawLo, rawHi);
      Serial.println(raw);
    }
  }
}

void blinkLED() {
  for(byte i = 0; i < 10; i++) {
    digitalWrite(led, HIGH);
    delay(75);
    digitalWrite(led, LOW);
    delay(75);
  }
}

