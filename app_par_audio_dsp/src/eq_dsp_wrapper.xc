// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#include <xs1.h>
#include <xclib.h>
#include "coeffs.h"
#include "biquadCascade.h"
#include "commands.h"
#include "defines.h"
#include <xscope.h>
#include <stdio.h>

typedef struct
{
	char namestring[20];
	int value;
} eqStruct;

// Equalizer options.
int numEqs = 2;
eqStruct eqNames[2] = {
		{"Off", 0},
		{"On",  1},
};

// Date received on the audio channels is always "streaming"
#ifdef USE_STREAMING_CHANNELS
#define AUDIO_STREAMING_INPUT(c,v) c :> v
#define AUDIO_STREAMING_OUTPUT(c,v) c <: v
#else
#define AUDIO_STREAMING_INPUT(c,v) inuint_byref(c, v)
#define AUDIO_STREAMING_OUTPUT(c,v) outuint(c, v)
#endif

#define iOS_REFRESH_DELAY 1000000

void eq_block_proc(int power[], biquadState &eq_stat, unsigned achan_idx);
void dsp_bypass(unsigned achan_idx);

void update_eq_gain(int bank, int gain, biquadState &state)
{
	state.desiredDb[bank] = gain;
}


#pragma unsafe arrays
void eq_wrapper(unsigned idx, chanend cCtrl, streaming chanend cDSPActivityOutput, streaming chanend c_in, streaming chanend c_out)
{
	char command;
	//char controlState = 0;
	char controlState = 1;

	signed sample;
	unsigned sample_count = 0;
	unsigned col=0, sub=0, subc=0;

    biquadState bsl, bsr;


	unsigned int leftPower[BANKS], rightPower[BANKS];

#ifdef USE_XSCOPE
	int si, so; // just for xscope
	xscope_register (2,
			XSCOPE_CONTINUOUS , " Equaliser input (left)", XSCOPE_INT , "int",
			XSCOPE_CONTINUOUS , " Equaliser output (left) ", XSCOPE_INT , "int"
	);
#endif

#ifdef ENFORCE_FAST_MODE
	set_thread_fast_mode_on();
#endif

	// Do any required DSP initialisation here
    initBiquads(bsl, 0);
    initBiquads(bsr, 0);

	for(int i =0; i < BANKS; i++)
	{
		leftPower[i] = 0;
		rightPower[i] = 0;
	}

	c_out <: 0; // output happens first in iis thread

	while (1)
	{
		select
		{
			case c_in :> sample :
			{

				if(!(sample_count & 1)) {
					//RIGHT
			#ifdef USE_XSCOPE
					si = sample; // signed not accepted by XScope ?
					xscope_probe_data_pred(0, sample);
			#endif
			#ifdef DEBUG
					printf("EQ input: 0x%x\n",sample);
			#endif
					//sample = 0;
					//sample = biquadCascade(bsr, sample, rightPower);
			#ifdef USE_XSCOPE
					so = sample; // signed not accepted by XScope ?
					xscope_probe_data_pred(1, sample);
			#endif
			#ifdef DEBUG
					printf("EQ output: 0x%x\n",sample);
			#endif
					c_out <: sample;
				} else {
					//LEFT
					biquadCascade(bsl, sample, leftPower);
					#if 1
					col++;
					sub=(col%(BANKS*210));
					if (sub){
						//printf("%i\n",sub%(BANKS*10) );
						if(sub < (BANKS*5) || sub%(BANKS*5)){
							c_out <: 0;
						}else{
							if (subc < BANKS){
								//c_out <: 0x01234500;
								c_out <: leftPower[subc];
								subc++;
							}else{
								c_out <: 0x0;
							}
						}
					} else {
						c_out <:0x12345000;
						subc=0;
					}
					#else
					c_out <: sample ;
					#endif
				}
				sample_count++;
			}
			break;
			case cCtrl :> command:
				switch (command)
				{
				case DSP_COMMAND_CONTROL_STATE:
					cCtrl :> controlState;
					// Control information, as defined by eqNames
					break;
				case DSP_COMMAND_XMOS_SIMPLEGFXEQ_MESSAGE:
				{
					char message, band, boost;
					cCtrl :> message;
					if (message == COMMAND_XMOS_SIMPLEGFXEQ_SetBandBoost)
					{
						cCtrl :> band;
						cCtrl :> boost;
						update_eq_gain(band, boost, bsl);
						update_eq_gain(band, boost, bsr);
					}
				}
				break;
				default:
					break;
				}
			break;

			case cDSPActivityOutput :> int _:
				cDSPActivityOutput <: BANKS; // * 2;
				for (int i = 0; i < BANKS; i++)
				{
					//cDSPActivityOutput <: (int)((char)(32 - clz(leftPower[i]))); //32 - clz(x) = log_2(x)
					cDSPActivityOutput <: leftPower[i];
					//cDSPActivityOutput <: (char)(32 - clz(rightPower[i]));
				}
				break;

		}

	}
}

