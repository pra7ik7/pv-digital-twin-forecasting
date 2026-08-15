/* ─────────────────────────────────────────────────────────────
   PV Digital Twin — Sensor Node
   Reads:
     • LDR voltage  → converts to irradiance via calibration
     • DHT11        → ambient temperature
   Sends one comma-separated line per sample over Serial.
   Output format:    irradiance,temperature\n
   Example:          425.30,24.50
   ───────────────────────────────────────────────────────────── */

#include <DHT.h>

// ── Pins ─────────────────────────────────────────────────────
const int   LDR_PIN  = A0;     // LDR voltage divider midpoint
const int   DHT_PIN  = 2;      // DHT11 data pin (any digital pin works)
#define     DHT_TYPE   DHT11

// ── Constants ────────────────────────────────────────────────
const float V_REF   = 5.0;
const float ADC_MAX = 1023.0;

// ── LDR calibration coefficients  G = a · V^b  (from MATLAB fit)
const float a_cal = 77.23;
const float b_cal = 3.6631;

// ── DHT11 sampling control ───────────────────────────────────
// DHT11 spec: minimum 1 second between reads.
// We keep the LDR responsive (every 1 s) and refresh DHT11 every 2 s
// so the temperature value is always recent and never stale.
DHT dht(DHT_PIN, DHT_TYPE);

unsigned long last_temp_read_ms = 0;
const unsigned long TEMP_PERIOD_MS = 2000;
float last_temp_c = 25.0;       // sensible startup fallback

void setup() {
    Serial.begin(9600);
    dht.begin();
    delay(2000);                // DHT11 needs ~1-2 s to stabilise after power-up
}

void loop() {
    // ── LDR → irradiance ────────────────────────────────────
    int   raw_ldr = analogRead(LDR_PIN);
    float v_ldr   = (raw_ldr / ADC_MAX) * V_REF;
    float irradiance = a_cal * pow(v_ldr, b_cal);
    if (irradiance < 0) irradiance = 0;   // physical floor

    // ── DHT11 → temperature (refresh every 2 s only) ────────
    if (millis() - last_temp_read_ms >= TEMP_PERIOD_MS) {
        float t = dht.readTemperature();   // returns °C
        if (!isnan(t)) {                   // keep last good value if read fails
            last_temp_c = t;
        }
        last_temp_read_ms = millis();
    }

    // ── Send one CSV line: "irradiance,temperature\n" ───────
    Serial.print(irradiance, 2);
    Serial.print(",");
    Serial.println(last_temp_c, 2);

    delay(1000);                // 1 sample per second
}