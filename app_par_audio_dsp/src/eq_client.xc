// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#include <xs1.h>
#include "eq_client.h"
#include "coeffs.h"
#include "defines.h"
#include "commands.h"
#include <stdio.h>

#define ON 0 //enables analysis of power data

#define NUM_PRESETS 3
char equaliser_presets[NUM_PRESETS][BANKS] = {
		{0, 0, 0, 0, 0}, // all 0 dB
		{20, 20, 20, 20, 20}, // ramp: -20dB, -15dB, -10dB, -dB, 0dB
		{40, 40, 40, 40, 40}, // reduce mid ranges: -0dB, -5, -15dB, -5dB, 0dB
};
unsigned preset = 0;

void eq_client(chanend c_ctrl[], streaming chanend c_DSP_activity[]) {
	timer tmr1, tmr2;
	unsigned etime,ltime;
	unsigned update_cnt;
	int count, values[BANKS*2];


	tmr1 :> etime;
	tmr2 :> ltime;

	while(1) {
		select {
			case tmr1 when timerafter(etime) :> int _1:
			etime += EQ_UPDATE_PERIOD;

			// Example: Periodically change DB settings for frequency bands
			// of equaliser connected to c_ctrl[0]
			for(int i=0; i<BANKS; i++) {
				//changing preset and i, both at the same time will cause ET_ILLEGAL_RESOURCE error
				//eq_client_set_band_db(c_ctrl[0], i, equaliser_presets[preset][i]);
				eq_client_set_band_db(c_ctrl[0], i, equaliser_presets[0][i]);
				update_cnt++;
				if(update_cnt % 2000 == 0) {
					preset++; // cycle through the presets
					if(preset==NUM_PRESETS) {
						preset=0;
					}
				}
			}
			break;

			case ON => tmr2 when timerafter(ltime) :> int _2:
			ltime += LEVEL_UPDATE_PERIOD;
			// Use c_DSP_activity for level metering
			c_DSP_activity[0] <: 1;
			c_DSP_activity[0] :> count;
			for(int i=0; i < count; i++){
				c_DSP_activity[0] :> values[i];
				//if (values[i] > 100)
					printf("%i ",values[i]);
			}
			//printf("%x %x %x %x %x\n",values[0], values[1], values[2], values[3], values[4]);
			//printf("\n");
			break;

		}
	}
}

void eq_client_set_band_db(chanend c_ctrl, char band, char db_idx) {
	c_ctrl <: (char) DSP_COMMAND_XMOS_SIMPLEGFXEQ_MESSAGE;
	c_ctrl <: (char) COMMAND_XMOS_SIMPLEGFXEQ_SetBandBoost;
	c_ctrl <: (char) band;
	c_ctrl <: (char) db_idx;
}
