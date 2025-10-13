#include "Adafruit_INA3221.h"
#include <Wire.h>
#include <driver/dac.h>

Adafruit_INA3221 ina3221;

void setup() {
  Serial.begin(115200);
  while (!Serial)
    delay(10);

  // Initialize INA3221
  while (!ina3221.begin(0x40, &Wire)) {
    Serial.println("Failed to find INA3221 chip");
    delay(1000);
  }
  Serial.println("INA3221 Found!");

  ina3221.setAveragingMode(INA3221_AVG_16_SAMPLES);

  for (uint8_t i = 0; i < 3; i++) {
    ina3221.setShuntResistance(i, 0.05);
  }
}

void loop() {
  float current = ina3221.getCurrentAmps(0);
  Serial.write((byte*)&current, sizeof(current));
  delay(5);
}
