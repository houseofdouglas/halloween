// Halloween eyes — ESP32-S3 Super Mini or Arduino Uno R4 WiFi, 2x 28BYJ-48 + ULN2003, one PWM "glow" channel.
//
// Lid position is in half-steps of the motor output shaft (4096 per rev).
// The scotch-yoke crank means: 0 = pin up = lid OPEN, 2048 = pin down = lid CLOSED.
// There is no home switch: on power-up the lid is ASSUMED CLOSED. Use the serial
// jog commands below to align the crank during assembly, then press 'z'.

#include <Arduino.h>
#include <math.h>

// ---- wiring ---------------------------------------------------------------
#if defined(ARDUINO_ARCH_ESP32)
const uint8_t EYE_PINS[2][4] = {{1, 2, 3, 4}, {5, 6, 7, 8}};  // ULN2003 IN1..IN4
const uint8_t GLOW_PIN       = 9;                             // LED / UV driver (PWM)
#else  // Uno R4 WiFi (test rig)
const uint8_t EYE_PINS[2][4] = {{8, 9, 10, 11}, {4, 5, 6, 7}};  // left eye, right eye
const uint8_t GLOW_PIN       = 3;                               // PWM
#endif
const int8_t  EYE_DIR[2]     = {1, -1};                       // flip if a lid runs backwards

// ---- tuning ---------------------------------------------------------------
const int32_t CLOSED_POS      = 2048;   // 180 degrees of crank
const int32_t OPEN_POS        = 0;
const uint32_t MIN_STEP_US    = 1300;   // ~770 half-steps/s, safe for 28BYJ-48 at 5 V
const float   GLOW_MAX        = 0.85;   // 0..1
const uint32_t PAUSE_MIN_MS   = 4000;
const uint32_t PAUSE_MAX_MS   = 12000;

// ---- state ----------------------------------------------------------------
const uint8_t SEQ[8] = {0b0001, 0b0011, 0b0010, 0b0110, 0b0100, 0b1100, 0b1000, 0b1001};
int32_t pos[2]   = {CLOSED_POS, CLOSED_POS};   // current lid position (steps)
int8_t  phase[2] = {0, 0};
float   glow     = 0;

void writeCoils(uint8_t eye, uint8_t bits) {
  for (uint8_t i = 0; i < 4; i++) digitalWrite(EYE_PINS[eye][i], (bits >> i) & 1);
}
void coilsOff() { writeCoils(0, 0); writeCoils(1, 0); }

void stepEye(uint8_t eye, int8_t dir) {
  dir *= EYE_DIR[eye];
  phase[eye] = (phase[eye] + dir + 8) & 7;
  writeCoils(eye, SEQ[phase[eye]]);
}

void setGlow(float g) {
  glow = constrain(g, 0.0f, 1.0f);
  uint32_t duty = (uint32_t)(powf(glow, 2.2f) * 1023.0f);  // gamma so fades look linear
#if defined(ARDUINO_ARCH_ESP32)
  ledcWrite(GLOW_PIN, duty);
#else
  analogWrite(GLOW_PIN, duty);
#endif
}

float smooth(float t) { return t * t * t * (t * (t * 6 - 15) + 10); }  // smootherstep

// Move both lids (with an optional lag on eye 1) and fade the glow, all in `ms`.
// Duration is stretched if the motor could not keep up.
void run(int32_t lidTo, float glowTo, uint32_t ms, uint32_t lagMs = 0) {
  int32_t from[2] = {pos[0], pos[1]};
  float glowFrom = glow;
  int32_t maxSteps = max(abs(lidTo - from[0]), abs(lidTo - from[1]));
  uint32_t minMs = (uint32_t)((uint64_t)maxSteps * MIN_STEP_US / 1000 * 1.6);  // easing peaks ~1.9x avg
  if (ms < minMs) ms = minMs;
  uint32_t total = ms + lagMs;
  uint32_t t0 = millis();
  uint32_t lastStep[2] = {0, 0};
  while (true) {
    uint32_t el = millis() - t0;
    if (el >= total) break;
    setGlow(glowFrom + (glowTo - glowFrom) * smooth((float)el / total));
    for (uint8_t e = 0; e < 2; e++) {
      uint32_t t = (e == 1 && el > lagMs) ? el - lagMs : (e == 1 ? 0 : el);
      float p = smooth(min(1.0f, (float)t / ms));
      int32_t want = from[e] + (int32_t)((lidTo - from[e]) * p);
      uint32_t now = micros();
      if (want != pos[e] && now - lastStep[e] >= MIN_STEP_US) {
        int8_t d = want > pos[e] ? 1 : -1;
        stepEye(e, d);
        pos[e] += d;
        lastStep[e] = now;
      }
    }
  }
  // land exactly on target
  while (pos[0] != lidTo || pos[1] != lidTo) {
    for (uint8_t e = 0; e < 2; e++)
      if (pos[e] != lidTo) { int8_t d = lidTo > pos[e] ? 1 : -1; stepEye(e, d); pos[e] += d; }
    delayMicroseconds(MIN_STEP_US);
  }
  setGlow(glowTo);
  coilsOff();  // no holding current: motors stay cool, crank sits at dead centre anyway
}

void blinkOnce() {
  run(CLOSED_POS, glow, 1800, 150);
  delay(120);
  run(OPEN_POS, glow, 1800, 150);
}

// One full performance: dark -> glow swells while eyes open -> blink(s) -> close and fade out.
void performance() {
  run(OPEN_POS, GLOW_MAX, 5000, 400);   // eyes open as glow rises
  delay(random(1500, 3500));
  uint8_t blinks = random(1, 3);
  for (uint8_t i = 0; i < blinks; i++) {
    blinkOnce();
    delay(random(1200, 2500));
  }
  delay(random(1000, 3000));
  run(CLOSED_POS, 0.0f, 5000, 400);     // lids close as glow fades
}

// ---- serial jog (assembly alignment) --------------------------------------
//  a/d  : nudge both lids -/+ 16 steps     z : declare current position = CLOSED
//  o/c  : go open / closed                  b : blink       p : full performance
void handleSerial() {
  while (Serial.available()) {
    char ch = Serial.read();
    switch (ch) {
      case 'a': for (int i = 0; i < 16; i++) { stepEye(0, -1); stepEye(1, -1); delayMicroseconds(MIN_STEP_US); } coilsOff(); break;
      case 'd': for (int i = 0; i < 16; i++) { stepEye(0, 1);  stepEye(1, 1);  delayMicroseconds(MIN_STEP_US); } coilsOff(); break;
      case 'z': pos[0] = pos[1] = CLOSED_POS; Serial.println("zeroed: current = CLOSED"); break;
      case 'o': run(OPEN_POS, glow, 3000); break;
      case 'c': run(CLOSED_POS, glow, 3000); break;
      case 'b': blinkOnce(); break;
      case 'p': performance(); break;
      case 'g': setGlow(glow > 0.5 ? 0 : GLOW_MAX); break;
    }
  }
}

void setup() {
  Serial.begin(115200);
  for (uint8_t e = 0; e < 2; e++)
    for (uint8_t i = 0; i < 4; i++) pinMode(EYE_PINS[e][i], OUTPUT);
  coilsOff();
#if defined(ARDUINO_ARCH_ESP32)
  ledcAttach(GLOW_PIN, 5000, 10);
  randomSeed(esp_random());
#else
  analogWriteResolution(10);
  randomSeed(analogRead(A0));
#endif
  setGlow(0);
  Serial.println("eyes ready. a/d jog, z zero(closed), o open, c close, b blink, p performance, g glow toggle");
  delay(2000);
}

void loop() {
  handleSerial();
  uint32_t until = millis() + random(PAUSE_MIN_MS, PAUSE_MAX_MS);
  while (millis() < until) { handleSerial(); delay(20); }
  performance();
}
