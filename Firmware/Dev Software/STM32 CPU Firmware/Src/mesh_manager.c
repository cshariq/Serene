/*
 * mesh_manager.c
 *
 *  Created on: Jan 24, 2026
 *      Author: Shariq
 */

#ifndef INC_MESH_MANAGER_H_
#define INC_MESH_MANAGER_H_

#include "main.h"

#define TDM_SLOTS 16
#define ADXL_SLOT 15 // Last slot reserved for Vibration sensor

void Mesh_Init(void);
void Mesh_ProcessIncomingAudio(uint32_t sender_id, int32_t sample);
int32_t* Mesh_GetTransmitBuffer(void);

#endif
