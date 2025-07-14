// Code de test pour contrôler quatre servomoteurs simultanément avec balayage sur ESP32
// Deux HS-805BB+ pour le Pan (en sens opposé)
// Deux MG996R/G pour le Tilt (dans le même sens)
// Modification : Tous les servos démarrent à la position 0 au lieu de 90.

#include <ESP32Servo.h> // Inclure la bibliothèque ESP32Servo

// --- Attribution des Pins GPIO de l'ESP32 pour les Servos ---
const int servoPinPan1 = 13; // Servo Pan 1 (HS-805BB+ 1)
const int servoPinPan2 = 12; // Servo Pan 2 (HS-805BB+ 2)
const int servoPinTilt1 = 14; // Servo Tilt 1 (MG996R/G 1)
const int servoPinTilt2 = 27; // Servo Tilt 2 (MG996R/G 2)

// --- Objets Servo ---
Servo servoPan1;
Servo servoPan2;
Servo servoTilt1;
Servo servoTilt2;

// --- Configuration du Balayage (Sweeping) ---
// Les servos sont positionnels (0-180 degrés typiques). Le balayage est simulé
// en envoyant de nouvelles positions progressivement dans le temps.

// Pan Sweep Configuration (HS-805BB+ - Plus lents ou sur une plus grande plage)
int panAngle; // Angle actuel pour le balayage Pan (pour Pan 1) - Initialisé dans setup()
int panStep = 1; // Taille du pas en degrés
int panDirection = 1; // Direction du balayage (1 pour incrémenter, -1 pour décrémenter)
unsigned long lastPanSweepTime = 0; // Dernier moment où l'angle Pan a été mis à jour
const int panSweepInterval = 20; // Intervalle en ms entre chaque pas du balayage Pan (plus grand = plus lent)
const int panMinAngle = 0; // Angle minimum pour le balayage Pan
const int panMaxAngle = 180; // Angle maximum pour le balayage Pan

// Tilt Sweep Configuration (MG996R/G - Plus rapides ou sur une plage limitée)
int tiltAngle; // Angle actuel pour le balayage Tilt - Initialisé dans setup()
int tiltStep = 2; // Taille du pas en degrés (peut être plus grand pour un mouvement plus rapide)
int tiltDirection = 1; // Direction du balayage (1 pour incrémenter, -1 pour décrémenter)
unsigned long lastTiltSweepTime = 0; // Dernier moment où l'angle Tilt a été mis à jour
const int tiltSweepInterval = 10; // Intervalle en ms entre chaque pas du balayage Tilt (plus petit = plus rapide)
const int tiltMinAngle = 30; // Angle minimum pour le balayage Tilt (éviter les butées si la plage est limitée)
const int tiltMaxAngle = 150; // Angle maximum pour le balayage Tilt (éviter les butées)


// --- Setup ---
void setup() {
  // Initialisation de la communication série pour afficher des messages (debug)
  Serial.begin(115200);
  Serial.println("------------------------------------");
  Serial.println("ESP32 Test - Four Servos Simultaneous");
  Serial.println("------------------------------------");

  // --- MISE EN GARDE CRUCIALE POUR L'ALIMENTATION DES SERVOS ---
  // Ces servos (surtout les HS-805BB+) sont puissants et tirent beaucoup de courant.
  // N'alimentez JAMAIS les servos directement par les pins de l'ESP32 ou son port USB.
  //
  // Instructions de câblage OBLIGATOIRES pour CHAQUE servo:
  // 1. Connectez le fil ROUGE (+) de CHAQUE servo à votre ALIMENTATION EXTERNE (5V à 7.2V Max pour le MG996R, 5V à 6V/7.2V Max pour le HS-805BB+ - vérifiez les specs).
  // 2. Connectez le fil MARRON ou NOIR (-) de CHAQUE servo à la MASSE (-) de votre ALIMENTATION EXTERNE.
  // 3. Connectez la MASSE (-) de votre ALIMENTATION EXTERNE à la MASSE (-) de l'ESP32.
  // 4. Connectez le fil JAUNE ou ORANGE (signal) de CHAQUE servo à la pin GPIO spécifiée (servoPinPan1, servoPinPan2, etc.).
  //
  // Ajoutez un grand condensateur (1000uF ou plus, idéalement 2200uF ou 4700uF pour 4 servos puissants) sur les bornes d'alimentation EXTERNE des servos (+ et -),
  // idéalement le plus près possible des servos, pour lisser les pics de courant.
  Serial.println("!!! ATTENTION !!! Assurez-vous que TOUS les servos sont alimentés par une source externe.");
  Serial.println("!!!              Connectez impérativement les masses.");
  Serial.println("!!!              Un gros condensateur sur l'alimentation des servos est FORTEMENT recommandé.");


  // --- Initialisation et Attachement des Servos ---
  // La bibliothèque ESP32Servo utilise les timers LEDC de l'ESP32.
  // Elle alloue automatiquement les timers nécessaires lors de l'attachement.
  // La plage d'impulsion standard 500-2400 us correspond à 0-180 deg pour beaucoup de servos Hitec.
  // Ajustez 500 et 2400 si nécessaire si les servos font du bruit ou forcent aux butées,
  // ou si vous voulez limiter la plage de mouvement mécanique.

  Serial.println("Attaching Servos...");
  // Attacher les servos Pan (HS-805BB+). Ajustez la plage d'impulsion si nécessaire.
  servoPan1.setPeriodHertz(50);
  servoPan1.attach(servoPinPan1, 500, 2400); // Pan 1

  servoPan2.setPeriodHertz(50);
  servoPan2.attach(servoPinPan2, 500, 2400); // Pan 2

  // Attacher les servos Tilt (MG996R/G). Ajustez la plage d'impulsion si nécessaire.
  servoTilt1.setPeriodHertz(50);
  servoTilt1.attach(servoPinTilt1, 500, 2400); // Tilt 1

  servoTilt2.setPeriodHertz(50);
  servoTilt2.attach(servoPinTilt2, 500, 2400); // Tilt 2

  Serial.println("Servos attached.");

  // --- Position initiale au démarrage : 0 degrés ---
  Serial.println("Moving all servos to initial position (0 degrees)...");
  // Définir l'angle initial pour le balayage Pan à la limite minimale
  panAngle = panMinAngle;
  // Définir l'angle initial pour le balayage Tilt à la limite minimale
  tiltAngle = tiltMinAngle;

  // Appliquer les positions initiales
  servoPan1.write(panAngle); // Pan 1 à son angle min
  // Pan 2 commence en sens opposé. Si Pan 1 commence à min (0), Pan 2 commence à max (180).
  servoPan2.write(panMaxAngle); // Pan 2 à son angle max pour commencer en opposition

  servoTilt1.write(tiltAngle); // Tilt 1 à son angle min
  servoTilt2.write(tiltAngle); // Tilt 2 à son angle min

  delay(2000); // Attendre que les servos atteignent la position initiale
  Serial.println("Starting sweep...");

  // Initialiser les temps pour le balayage non bloquant
  lastPanSweepTime = millis();
  lastTiltSweepTime = millis();
}

// --- Loop ---
void loop() {
  unsigned long currentTime = millis(); // Obtenir le temps actuel

  // --- Gérer le Balayage Pan (HS-805BB+ en sens opposé) ---
  if (currentTime - lastPanSweepTime >= panSweepInterval) {
    lastPanSweepTime = currentTime; // Mettre à jour le temps du dernier balayage Pan

    // Calculer le prochain angle pour Pan 1
    panAngle += panStep * panDirection;

    // Vérifier si les limites de balayage sont atteintes pour Pan 1
    if (panDirection == 1 && panAngle > panMaxAngle) {
      panAngle = panMaxAngle; // Ne pas dépasser la limite
      panDirection = -1; // Inverser la direction du balayage
    } else if (panDirection == -1 && panAngle < panMinAngle) {
      panAngle = panMinAngle; // Ne pas dépasser la limite
      panDirection = 1; // Inverser la direction
    }

    // Appliquer la nouvelle position aux servos Pan
    servoPan1.write(panAngle); // Pan 1 suit panAngle
    // Pan 2 va dans la direction opposée. Sa position est panMinAngle + (panMaxAngle - panAngle)
    // Ex: si panMin=0, panMax=180, si panAngle=30, Pan 2 va à 0 + (180-30) = 150.
    servoPan2.write(panMinAngle + (panMaxAngle - panAngle)); // Pan 2 suit le mouvement opposé

    // Optionnel: afficher l'angle pour debug
    // Serial.print("Pan Angles: "); Serial.print(panAngle); Serial.print(" / "); Serial.println(panMinAngle + (panMaxAngle - panAngle));
  }

  // --- Gérer le Balayage Tilt (MG996R/G dans le même sens) ---
  if (currentTime - lastTiltSweepTime >= tiltSweepInterval) {
    lastTiltSweepTime = currentTime; // Mettre à jour le temps du dernier balayage Tilt

    // Calculer le prochain angle pour Tilt
    tiltAngle += tiltStep * tiltDirection;

    // Vérifier si les limites de balayage sont atteintes pour Tilt
    if (tiltDirection == 1 && tiltAngle > tiltMaxAngle) {
      tiltAngle = tiltMaxAngle; // Ne pas dépasser la limite
      tiltDirection = -1; // Inverser la direction
    } else if (tiltDirection == -1 && tiltAngle < tiltMinAngle) {
      tiltAngle = tiltMinAngle; // Ne pas dépasser la limite
      tiltDirection = 1; // Inverser la direction
    }

    // Appliquer la nouvelle position aux servos Tilt
    servoTilt1.write(tiltAngle); // Tilt 1 suit tiltAngle
    servoTilt2.write(tiltAngle); // Tilt 2 suit le même angle

    // Optionnel: afficher l'angle pour debug
    // Serial.print("Tilt Angle: "); Serial.println(tiltAngle);
  }

  // La boucle loop() s'exécute très rapidement. Les waits sont gérés par les checks millis().
  // Vous pouvez ajouter d'autres logiques ici (comme la gestion du serveur web)
  // sans bloquer les mouvements des servos.
}