/*
 * power_manager.h
 *
 *  Created on: Jan 24, 2026
 *      Author: Shariq
 */

#ifndef INC_POWER_MANAGER_H_
#define INC_POWER_MANAGER_H_

#include "main.h"

#define BQ_I2C_ADDR (0x6B << 1)
#define BQ_REG_BATSNS_ADC 0x2E // Battery Voltage ADC
#define BQ_REG_ADC_CONTROL 0x26

typedef struct {
    float battery_voltage;
    uint8_t charge_percent;
    uint8_t is_charging;
} PowerStatus;

void Power_Init(I2C_HandleTypeDef *hi2c);
PowerStatus Power_GetStatus(I2C_HandleTypeDef *hi2c);

#endif
