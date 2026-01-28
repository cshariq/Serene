/*
 * adxl382.h
 *
 *  Created on: Jan 24, 2026
 *      Author: Shariq
 */

#include "adxl382.h"

void ADXL_Init(SPI_HandleTypeDef *hspi) {
    uint8_t data[2];
    // Set ADXL to measurement mode
    data[0] = ADXL_REG_POWER_CTL;
    data[1] = 0x02; // Measurement Mode
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_RESET); // CS Low
    HAL_SPI_Transmit(hspi, data, 2, 100);
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_SET); // CS High
}
