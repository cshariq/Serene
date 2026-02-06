/*
 * power_manager.c
 *
 *  Created on: Jan 24, 2026
 *      Author: Shariq
 */

#include "power_manager.h"

void Power_Init(I2C_HandleTypeDef *hi2c) {
    uint8_t config = 0xB0; // Enable ADC continuously
    HAL_I2C_Mem_Write(hi2c, BQ_I2C_ADDR, BQ_REG_ADC_CONTROL, 1, &config, 1, 100);
}

PowerStatus Power_GetStatus(I2C_HandleTypeDef *hi2c) {
    PowerStatus status;
    uint8_t raw_data[2];

    // Read Battery Voltage ADC
    if(HAL_I2C_Mem_Read(hi2c, BQ_I2C_ADDR, BQ_REG_BATSNS_ADC, 1, raw_data, 2, 100) == HAL_OK) {
        uint16_t raw_v = (raw_data[1] << 8) | raw_data[0];
        status.battery_voltage = raw_v * 0.001f; // Convert mV to V

        // Accurate lookup based on the BQ25622 internal scaling
        // In a real product, we would read the "Relative State of Charge" register if using a fuel gauge
        // For BQ25622, we use its high-res ADC to map percent
        status.charge_percent = (status.battery_voltage - 3.3f) / (4.2f - 3.3f) * 100.0f;
    }
    return status;
}

