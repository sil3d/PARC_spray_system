// ===================================================================================
//                  PARC Sprayer System - ESP32 Control Code
// ===================================================================================
//
// Description:
// This code turns an ESP32 into a dedicated controller for a robotic spray system.
// It creates a WiFi hotspot and a web server to receive commands from a mobile app.
// It controls 4 servos for Pan/Tilt movement, 3 relays for pumps, a buzzer
// for auditory feedback, and reads a DHT11 sensor for environmental data.
//
// Features:
// - WiFi Access Point for direct connection with the control app.
// - Web Server with RESTful API endpoints for control and telemetry.
// - Dual Mode Operation:
//   - MANUAL: Direct control of servos and pumps via the app.
//   - AUTO: Executes a predefined, continuous spray pattern.
// - Safety: Emergency stop, clear separation between modes.
// - Hardware Support: Servos, Relays, Buzzer, DHT11 Sensor.
//
// IMPORTANT WIRING & POWER NOTES:
// - Servos and Pumps MUST be powered by appropriate EXTERNAL power supplies.
// - Connect the GROUND of the ESP32 to the GROUND of ALL external power supplies.
// - Use a large capacitor (1000uF+) across the servo power lines to handle current spikes.
//

// --- 1. Inclusions des Bibliothèques ---
#include <WiFi.h>
#include <WebServer.h>
#include <ESP32Servo.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>

// --- 2. Configuration WiFi et Serveur ---
const char* ssid = "ESP32_Spray_Control";
const char* password = "password123";  // <<< CHANGEZ CE MOT DE PASSE !!!

WebServer server(80);

// --- 3. Attribution des Pins GPIO ---
// Servos
const int servoPinPan1 = 13;
const int servoPinPan2 = 12;
const int servoPinTilt1 = 14;
const int servoPinTilt2 = 27;

// Relais (Assumed Active HIGH: HIGH=ON, LOW=OFF)
const int relayPinMiniPump1 = 32;
const int relayPinMiniPump2 = 33;
const int relayPinMainPump = 25;
const int RELAY_ON = HIGH;
const int RELAY_OFF = LOW;

// Buzzer & Capteur
const int buzzerPin = 4;
const int dhtPin = 19;
const int dhtType = DHT11;
DHT dht(dhtPin, dhtType);

// --- 4. Objets et Variables Globales ---
// Objets Servo
Servo servoPan1;
Servo servoPan2;
Servo servoTilt1;
Servo servoTilt2;

// Variables d'État Système
bool isAutoMode = false;
bool isSystemRunning = false;
bool isMiniPump1On = false;
bool isMiniPump2On = false;
bool isMainPumpOn = false;
float temperature = NAN;
float humidity = NAN;

// Variables de Position Cible (pour la télémétrie)
int servoPan1TargetAngle = 90;
int servoPan2TargetAngle = 90;
int servoTilt1TargetAngle = 90;
int servoTilt2TargetAngle = 90;

// Configuration du Balayage en Mode Auto
int panAngle = 90;
int panStep = 1;
int panDirection = 1;
unsigned long lastPanSweepTime = 0;
const int panSweepInterval = 20;  // ms per step
int panMinAngle = 0;              // Peut être calibré via l'app
int panMaxAngle = 180;            // Peut être calibré via l'app

int tiltAngle = 90;
int tiltStep = 2;
int tiltDirection = 1;
unsigned long lastTiltSweepTime = 0;
const int tiltSweepInterval = 10;  // ms per step
int tiltMinAngle = 30;             // Peut être calibré via l'app
int tiltMaxAngle = 150;            // Peut être calibré via l'app

// Séquence de Démarrage Auto
unsigned long autoSequenceStartTime = 0;
bool inAutoStartSequence = false;
const int autoBuzzerToneFreq = 1000;  // Hz
const int autoBuzzerDuration = 5000;  // ms


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

// Démarre la séquence de démarrage automatique
void startAutoSequence() {
  if (!isSystemRunning) {
    isSystemRunning = true;
    isAutoMode = true;
    inAutoStartSequence = true;
    Serial.println("Starting Auto Sequence...");
    beepTone(autoBuzzerToneFreq, autoBuzzerDuration);
    autoSequenceStartTime = millis();

    // Positionne les servos à leur point de départ de balayage
    panAngle = panMinAngle;
    tiltAngle = tiltMinAngle;
    servoPan1TargetAngle = panAngle;
    servoPan2TargetAngle = panMaxAngle - panAngle;
    servoTilt1TargetAngle = tiltAngle;
    servoTilt2TargetAngle = tiltAngle;
    servoPan1.write(servoPan1TargetAngle);
    servoPan2.write(servoPan2TargetAngle);
    servoTilt1.write(servoTilt1TargetAngle);
    servoTilt2.write(servoTilt2TargetAngle);

    // Réinitialise les timers de balayage
    lastPanSweepTime = millis();
    lastTiltSweepTime = millis();

    server.send(200, "text/plain", "Auto sequence started.");
  } else {
    Serial.println("System is already running. Command ignored.");
    server.send(409, "text/plain", "System is already running.");  // 409 Conflict
  }
}

// Arrête complètement le système
void stopSystem() {
  Serial.println("EMERGENCY STOP received!");
  isSystemRunning = false;
  isAutoMode = false;
  inAutoStartSequence = false;
  setAllPumpsState(false);
  stopBeep();
  Serial.println("System stopped. Switched to MANUAL mode.");
  server.send(200, "text/plain", "System stopped successfully.");
}

// --- 6. Gestion des Requêtes HTTP (API Endpoints) ---

void handleSetServo() {
  if (isAutoMode) {
    server.send(403, "text/plain", "Manual control disabled in AUTO mode.");
    return;
  }
  String servoId = server.arg("id");
  int angle = server.arg("angle").toInt();
  angle = constrain(angle, 0, 180);

  if (servoId == "pan1") servoPan1TargetAngle = angle;
  else if (servoId == "pan2") servoPan2TargetAngle = angle;
  else if (servoId == "tilt1") servoTilt1TargetAngle = angle;
  else if (servoId == "tilt2") servoTilt2TargetAngle = angle;
  else {
    server.send(400, "text/plain", "Invalid servo ID.");
    return;
  }

  // Appliquer le mouvement
  servoPan1.write(servoPan1TargetAngle);
  servoPan2.write(servoPan2TargetAngle);
  servoTilt1.write(servoTilt1TargetAngle);
  servoTilt2.write(servoTilt2TargetAngle);
  server.send(200, "text/plain", String("Servo ") + servoId + " set to " + angle);
}

void handleSetPumps() {
  if (isAutoMode) {
    server.send(403, "text/plain", "Manual control disabled in AUTO mode.");
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

void handleSetMode() {
  String mode = server.arg("mode");
  if (mode == "auto" && !isAutoMode) {
    startAutoSequence();  // La réponse est déjà envoyée par startAutoSequence()
  } else if (mode == "manual" && isAutoMode) {
    stopSystem();  // Arrêter tout en passant en manuel est plus sûr
  } else {
    server.send(200, "text/plain", "Mode is already set.");
  }
}

void handleJoystick() {
  if (isAutoMode) {
    server.send(403, "text/plain", "Manual control disabled in AUTO mode.");
    return;
  }
  isSystemRunning = true;  // Activer le système si on utilise les joysticks

  float panX = server.arg("panX").toFloat();
  float tiltY = server.arg("tiltY").toFloat();

  int targetPanAngle = map(panX * 100, -100, 100, panMinAngle, panMaxAngle);
  int targetTiltAngle = map(tiltY * 100, -100, 100, tiltMinAngle, tiltMaxAngle);

  servoPan1TargetAngle = targetPanAngle;
  servoPan2TargetAngle = panMinAngle + (panMaxAngle - targetPanAngle);
  servoTilt1TargetAngle = targetTiltAngle;
  servoTilt2TargetAngle = targetTiltAngle;

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

void handleTelemetry() {
  String jsonResponse = "{";
  jsonResponse += "\"mode\":\"" + String(isAutoMode ? "auto" : "manual") + "\",";
  jsonResponse += "\"system_running\":" + String(isSystemRunning ? "true" : "false") + ",";
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

// --- 7. Setup ---
void setup() {
  Serial.begin(115200);

  // Initialisation Hardware
  pinMode(relayPinMiniPump1, OUTPUT);
  pinMode(relayPinMiniPump2, OUTPUT);
  pinMode(relayPinMainPump, OUTPUT);
  setAllPumpsState(false);
  stopBeep();
  dht.begin();

  // Attachement et positionnement initial des Servos
  servoPan1.setPeriodHertz(50);
  servoPan1.attach(servoPinPan1, 500, 2400);
  servoPan2.setPeriodHertz(50);
  servoPan2.attach(servoPinPan2, 500, 2400);
  servoTilt1.setPeriodHertz(50);
  servoTilt1.attach(servoPinTilt1, 500, 2400);
  servoTilt2.setPeriodHertz(50);
  servoTilt2.attach(servoPinTilt2, 500, 2400);

  // Position initiale "neutre"
  servoPan1.write(90);
  servoPan2.write(90);
  servoTilt1.write(90);
  servoTilt2.write(90);
  delay(1000);  // Donner le temps aux servos d'atteindre la position

  // Configuration WiFi et Serveur
  WiFi.softAP(ssid, password);
  Serial.print("AP IP address: ");
  Serial.println(WiFi.softAPIP());

  server.on("/setServo", handleSetServo);
  server.on("/setPumps", handleSetPumps);
  server.on("/setMode", handleSetMode);
  server.on("/stopSystem", stopSystem);
  server.on("/joystick", handleJoystick);
  server.on("/telemetry", handleTelemetry);
  server.on("/setServoLimits", handleSetServoLimits);
  server.onNotFound(handleNotFound);

  server.begin();
  Serial.println("HTTP server started. System is in MANUAL mode, waiting for commands.");
}

// --- 8. Loop (Logique Principale) ---
void loop() {
  unsigned long currentTime = millis();
  server.handleClient();  // Gérer les requêtes HTTP

  // --- LOGIQUE EN MODE AUTO ---
  if (isSystemRunning && isAutoMode) {
    if (inAutoStartSequence) {
      if (currentTime - autoSequenceStartTime >= autoBuzzerDuration) {
        // La séquence est terminée, activer les pompes et le balayage.
        setAllPumpsState(true);
        inAutoStartSequence = false;
        Serial.println("Auto Sequence finished. Pumps ON, Sweep starting.");
      }
      return;  // Ne pas exécuter le balayage pendant le son.
    }

    // Balayage Pan (aller-retour)
    if (currentTime - lastPanSweepTime >= panSweepInterval) {
      lastPanSweepTime = currentTime;
      panAngle += panStep * panDirection;
      if ((panDirection == 1 && panAngle >= panMaxAngle) || (panDirection == -1 && panAngle <= panMinAngle)) {
        panDirection *= -1;  // Inverser
      }
      panAngle = constrain(panAngle, panMinAngle, panMaxAngle);  // Sécurité
      servoPan1.write(panAngle);
      servoPan2.write(panMinAngle + (panMaxAngle - panAngle));
      servoPan1TargetAngle = panAngle;
      servoPan2TargetAngle = panMinAngle + (panMaxAngle - panAngle);
    }

    // Balayage Tilt (aller-retour)
    if (currentTime - lastTiltSweepTime >= tiltSweepInterval) {
      lastTiltSweepTime = currentTime;
      tiltAngle += tiltStep * tiltDirection;
      if ((tiltDirection == 1 && tiltAngle >= tiltMaxAngle) || (tiltDirection == -1 && tiltAngle <= tiltMinAngle)) {
        tiltDirection *= -1;  // Inverser
      }
      tiltAngle = constrain(tiltAngle, tiltMinAngle, tiltMaxAngle);  // Sécurité
      servoTilt1.write(tiltAngle);
      servoTilt2.write(tiltAngle);
      servoTilt1TargetAngle = tiltAngle;
      servoTilt2TargetAngle = tiltAngle;
    }
  }

  // Lecture périodique du capteur de température/humidité
  static unsigned long lastDhtReadTime = 0;
  if (currentTime - lastDhtReadTime >= 5000) {
    lastDhtReadTime = currentTime;
    temperature = dht.readTemperature();
    humidity = dht.readHumidity();
    if (isnan(temperature) || isnan(humidity)) {
      Serial.println("Failed to read from DHT sensor!");
    }
  }
}