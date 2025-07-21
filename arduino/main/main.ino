// ===================================================================================
//                  PARC Sprayer System - ESP32 Control Code (Version 2.2)
// ===================================================================================
//
// Description:
// Version finale du contrôleur, avec logique de mouvement symétrique corrigée.
//
// NOUVEAUTÉS DANS CETTE VERSION:
// - Logique de mouvement servo corrigée :
//   - PAN (HS-805BB+): Tournent en opposition.
//   - TILT (MG996R/G): Tournent en opposition pour un mouvement symétrique.
// - Position de démarrage unifiée à 90 degrés pour tous les servos.
//

// --- 1. Inclusions des Bibliothèques ---
#include <WiFi.h>
#include <WebServer.h>
#include <ESP32Servo.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>

// --- 2. Configuration WiFi et Serveur ---
const char* ssid = "ESP32_Spray_Control";
const char* password = "password123";

WebServer server(80);

// --- 3. Attribution des Pins GPIO ---
const int servoPinPan1 = 13;
const int servoPinPan2 = 12;
const int servoPinTilt1 = 14;
const int servoPinTilt2 = 27;

const int relayPinMiniPump1 = 32;
const int relayPinMiniPump2 = 33;
const int relayPinMainPump = 25;
const int RELAY_ON = HIGH;
const int RELAY_OFF = LOW;

const int buzzerPin = 4;
const int dhtPin = 19;
const int dhtType = DHT11;
DHT dht(dhtPin, dhtType);

// --- 4. Objets et Variables Globales ---
Servo servoPan1, servoPan2, servoTilt1, servoTilt2;

bool isAutoMode = false, isSystemRunning = false, isManualSweepActive = false;
bool isTemperatureAlert = false;
bool isMiniPump1On = false, isMiniPump2On = false, isMainPumpOn = false;
float temperature = NAN, humidity = NAN;
int servoPan1TargetAngle = 90, servoPan2TargetAngle = 90, servoTilt1TargetAngle = 90, servoTilt2TargetAngle = 90;

// Configuration du Balayage (pour Auto ET Manuel)
int panAngle = 90, panStep = 1, panDirection = 1;
unsigned long lastPanSweepTime = 0;
const int panSweepInterval = 20;
int panMinAngle = 0, panMaxAngle = 180;

int tiltAngle = 90, tiltStep = 2, tiltDirection = 1;
unsigned long lastTiltSweepTime = 0;
const int tiltSweepInterval = 10;
int tiltMinAngle = 30, tiltMaxAngle = 150;

// Séquence de Démarrage Auto
unsigned long autoSequenceStartTime = 0;
bool inAutoStartSequence = false;
const int autoBuzzerToneFreq = 1000, autoBuzzerDuration = 5000;

// --- 5. Fonctions Utilitaires ---
void setPumpState(int pumpPin, bool state) {
  digitalWrite(pumpPin, state ? RELAY_ON : RELAY_OFF);
  if (pumpPin == relayPinMiniPump1) isMiniPump1On = state;
  else if (pumpPin == relayPinMiniPump2) isMiniPump2On = state;
  else if (pumpPin == relayPinMainPump) isMainPumpOn = state;
}
void setAllPumpsState(bool state) {
  setPumpState(relayPinMiniPump1, state);
  setPumpState(relayPinMiniPump2, state);
  setPumpState(relayPinMainPump, state);
}
void beepTone(int frequency, int duration_ms) {
  tone(buzzerPin, frequency, duration_ms);
}
void stopBeep() {
  noTone(buzzerPin);
}

// --- 6. Fonctions de Contrôle Système ---
void startAutoSequence() {
  if (!isSystemRunning) {
    isSystemRunning = true;
    isAutoMode = true;
    isManualSweepActive = false;
    inAutoStartSequence = true;
    Serial.println("Starting Auto Sequence...");
    beepTone(autoBuzzerToneFreq, autoBuzzerDuration);
    autoSequenceStartTime = millis();
    panAngle = panMinAngle;
    tiltAngle = tiltMinAngle;
    lastPanSweepTime = millis();
    lastTiltSweepTime = millis();
    server.send(200, "text/plain", "Auto sequence started.");
  } else {
    server.send(409, "text/plain", "System is already running.");
  }
}

void stopSystem() {
  Serial.println("EMERGENCY STOP received!");
  isSystemRunning = false;
  isAutoMode = false;
  isManualSweepActive = false;
  inAutoStartSequence = false;
  setAllPumpsState(false);
  stopBeep();
  Serial.println("System stopped. Switched to MANUAL mode.");
  server.send(200, "text/plain", "System stopped successfully.");
}

// --- 7. Gestion des Requêtes HTTP (API Endpoints) ---
void handleSetMode() {
  String mode = server.arg("mode");
  if (mode == "auto" && !isAutoMode) {
    startAutoSequence();
  } else if (mode == "manual" && isAutoMode) {
    stopSystem();
  } else {
    server.send(200, "text/plain", "Mode is already set.");
  }
}

void handleManualSweep() {
  if (isAutoMode) {
    server.send(403, "text/plain", "Cannot start manual sweep in AUTO mode.");
    return;
  }
  String state = server.arg("state");
  isManualSweepActive = (state == "on");
  if (isManualSweepActive) {
    isSystemRunning = true;
    panAngle = panMinAngle;
    tiltAngle = tiltMinAngle;
    panDirection = 1;
    tiltDirection = 1;
  }
  server.send(200, "text/plain", String("Manual sweep set to ") + (isManualSweepActive ? "ON" : "OFF"));
}

void handleJoystick() {
  if (isAutoMode || isManualSweepActive) {
    server.send(403, "text/plain", "Joystick is disabled during sweep modes.");
    return;
  }
  isSystemRunning = true;
  float panX = server.arg("panX").toFloat();
  float tiltY = server.arg("tiltY").toFloat();

  // --- LOGIQUE CORRIGÉE POUR LE JOYSTICK ---
  // L'angle principal (pour le servo 1 de chaque paire) est calculé
  int targetPan1Angle = map(panX * 100, -100, 100, panMinAngle, panMaxAngle);
  int targetTilt1Angle = map(tiltY * 100, -100, 100, tiltMinAngle, tiltMaxAngle);

  // Stocke la position principale
  servoPan1TargetAngle = targetPan1Angle;
  servoTilt1TargetAngle = targetTilt1Angle;

  // Calcule et stocke la position opposée pour le servo 2 de chaque paire
  servoPan2TargetAngle = panMinAngle + (panMaxAngle - targetPan1Angle);
  servoTilt2TargetAngle = tiltMinAngle + (tiltMaxAngle - targetTilt1Angle);

  // Applique les mouvements
  servoPan1.write(servoPan1TargetAngle);
  servoPan2.write(servoPan2TargetAngle);
  servoTilt1.write(servoTilt1TargetAngle);
  servoTilt2.write(servoTilt2TargetAngle);

  server.send(200, "text/plain", "Joystick command received.");
}

void handleSetServoLimits() {
  if (server.hasArg("panMin")) panMinAngle = server.arg("panMin").toInt();
  if (server.hasArg("panMax")) panMaxAngle = server.arg("panMax").toInt();
  if (server.hasArg("tiltMin")) tiltMinAngle = server.arg("tiltMin").toInt();
  if (server.hasArg("tiltMax")) tiltMaxAngle = server.arg("tiltMax").toInt();
  Serial.printf("New limits received: Pan(%d-%d), Tilt(%d-%d)\n", panMinAngle, panMaxAngle, tiltMinAngle, tiltMaxAngle);
  server.send(200, "text/plain", "Servo limits updated.");
}

void handleSetPumps() {
  if (isAutoMode || isManualSweepActive) {
    server.send(403, "text/plain", "Manual pump control disabled during sweep modes.");
    return;
  }
  String pumpId = server.arg("pump");
  bool state = server.arg("state") == "on";
  if (pumpId == "main") setPumpState(relayPinMainPump, state);
  else if (pumpId == "mini1") setPumpState(relayPinMiniPump1, state);
  else if (pumpId == "mini2") setPumpState(relayPinMiniPump2, state);
  else if (pumpId == "all") setAllPumpsState(state);
  else {
    server.send(400, "text/plain", "Invalid pump ID.");
    return;
  }
  server.send(200, "text/plain", String("Pump ") + pumpId + " set to " + (state ? "ON" : "OFF"));
}

void handleTelemetry() {
  String jsonResponse = "{";
  jsonResponse += "\"mode\":\"" + String(isAutoMode ? "auto" : "manual") + "\",";
  jsonResponse += "\"system_running\":" + String(isSystemRunning ? "true" : "false") + ",";
  jsonResponse += "\"manual_sweep_active\":" + String(isManualSweepActive ? "true" : "false") + ",";
  jsonResponse += "\"temperature_alert\":" + String(isTemperatureAlert ? "true" : "false") + ",";
  jsonResponse += "\"mini_pump1_on\":" + String(isMiniPump1On ? "true" : "false") + ",";
  jsonResponse += "\"mini_pump2_on\":" + String(isMiniPump2On ? "true" : "false") + ",";
  jsonResponse += "\"main_pump_on\":" + String(isMainPumpOn ? "true" : "false") + ",";
  jsonResponse += "\"servo_pan1_angle\":" + String(servoPan1TargetAngle) + ",";
  jsonResponse += "\"servo_pan2_angle\":" + String(servoPan2TargetAngle) + ",";
  jsonResponse += "\"servo_tilt1_angle\":" + String(servoTilt1TargetAngle) + ",";
  jsonResponse += "\"servo_tilt2_angle\":" + String(servoTilt2TargetAngle) + ",";
  if (isnan(temperature)) jsonResponse += "\"temperature\":null,";
  else jsonResponse += "\"temperature\":" + String(temperature, 1) + ",";
  if (isnan(humidity)) jsonResponse += "\"humidity\":null";
  else jsonResponse += "\"humidity\":" + String(humidity, 1);
  jsonResponse += "}";
  server.send(200, "application/json", jsonResponse);
}

void handleNotFound() {
  server.send(404, "text/plain", "Not Found.");
}

// --- 8. Setup ---
void setup() {
  Serial.begin(115200);

  pinMode(relayPinMiniPump1, OUTPUT);
  pinMode(relayPinMiniPump2, OUTPUT);
  pinMode(relayPinMainPump, OUTPUT);
  setAllPumpsState(false);
  stopBeep();
  dht.begin();

  servoPan1.attach(servoPinPan1, 500, 2400);
  servoPan2.attach(servoPinPan2, 500, 2400);
  servoTilt1.attach(servoPinTilt1, 500, 2400);
  servoTilt2.attach(servoPinTilt2, 500, 2400);

  // --- LOGIQUE CORRIGÉE POUR LE DÉMARRAGE ---
  // Tous les servos démarrent à la même position neutre (90 degrés)
  Serial.println("Moving all servos to initial neutral position (90 degrees)...");
  servoPan1.write(90);
  servoPan2.write(90);
  servoTilt1.write(90);
  servoTilt2.write(90);
  // Mettre à jour les variables de position cible
  servoPan1TargetAngle = 90;
  servoPan2TargetAngle = 90;
  servoTilt1TargetAngle = 90;
  servoTilt2TargetAngle = 90;
  delay(1000);

  WiFi.softAP(ssid, password);
  Serial.print("AP IP address: ");
  Serial.println(WiFi.softAPIP());

  server.on("/setMode", handleSetMode);
  server.on("/stopSystem", stopSystem);
  server.on("/joystick", handleJoystick);
  server.on("/setManualSweep", handleManualSweep);
  server.on("/telemetry", handleTelemetry);
  server.on("/setServoLimits", handleSetServoLimits);
  server.on("/setPumps", handleSetPumps);
  server.onNotFound(handleNotFound);

  server.begin();
  Serial.println("HTTP server started. System is in MANUAL mode.");
}

// --- 9. Loop (Logique Principale) ---
void loop() {
  unsigned long currentTime = millis();
  server.handleClient();

  bool shouldSweep = (isAutoMode && !inAutoStartSequence) || isManualSweepActive;

  if (isSystemRunning && shouldSweep) {
    // Balayage Pan (en opposition)
    if (currentTime - lastPanSweepTime >= panSweepInterval) {
      lastPanSweepTime = currentTime;
      panAngle += panStep * panDirection;
      if ((panDirection == 1 && panAngle >= panMaxAngle) || (panDirection == -1 && panAngle <= panMinAngle)) {
        panDirection *= -1;
      }
      panAngle = constrain(panAngle, panMinAngle, panMaxAngle);

      servoPan1TargetAngle = panAngle;
      servoPan2TargetAngle = panMinAngle + (panMaxAngle - panAngle);
      servoPan1.write(servoPan1TargetAngle);
      servoPan2.write(servoPan2TargetAngle);
    }

    // --- LOGIQUE CORRIGÉE POUR LE BALAYAGE TILT ---
    // Balayage Tilt (en opposition pour un mouvement symétrique)
    if (currentTime - lastTiltSweepTime >= tiltSweepInterval) {
      lastTiltSweepTime = currentTime;
      tiltAngle += tiltStep * tiltDirection;
      if ((tiltDirection == 1 && tiltAngle >= tiltMaxAngle) || (tiltDirection == -1 && tiltAngle <= tiltMinAngle)) {
        tiltDirection *= -1;
      }
      tiltAngle = constrain(tiltAngle, tiltMinAngle, tiltMaxAngle);

      servoTilt1TargetAngle = tiltAngle;
      servoTilt2TargetAngle = tiltMinAngle + (tiltMaxAngle - tiltAngle);
      servoTilt1.write(servoTilt1TargetAngle);
      servoTilt2.write(servoTilt2TargetAngle);
    }
  }

  // Gestion de la séquence de démarrage auto
  if (inAutoStartSequence && (currentTime - autoSequenceStartTime >= autoBuzzerDuration)) {
    setAllPumpsState(true);
    inAutoStartSequence = false;
    Serial.println("Auto Sequence finished. Pumps ON, Sweep starting.");
  }

  // Gestion des capteurs et alertes
  static unsigned long lastSensorReadTime = 0;
  if (currentTime - lastSensorReadTime >= 2000) {
    lastSensorReadTime = currentTime;
    temperature = dht.readTemperature();
    humidity = dht.readHumidity();

    if (!isnan(temperature) && temperature >= 40.0) {
      if (!isTemperatureAlert) {
        Serial.println("!!! HIGH TEMPERATURE ALERT !!!");
        isTemperatureAlert = true;
      }
      static unsigned long lastAlertBeepTime = 0;
      if (currentTime - lastAlertBeepTime > 1000) {
        lastAlertBeepTime = currentTime;
        beepTone(2500, 200);
      }
    } else {
      if (isTemperatureAlert) { Serial.println("Temperature is back to normal."); }
      isTemperatureAlert = false;
    }
  }
}