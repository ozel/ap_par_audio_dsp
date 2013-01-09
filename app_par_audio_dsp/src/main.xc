// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#include <xs1.h>
#include <xclib.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <xscope.h>
#include "fft.h"
#include "xai2_ports.h"
#include "iis.h"

#include "defines.h"
#include "eq_client.h"


// XMOS Parallel DSP example
// See README.rst for details
//	XS1_CLKBLK_3,
//    XS1_CLKBLK_4,
//    PORT_MCLK,             // Master Clock
//    PORT_SCLK,            // Bit Clock
//    PORT_LRCLK,           // LR Clock
//    {PORT_SDATA_IN0, PORT_SDATA_IN1},
//    {PORT_SDATA_OUT0, PORT_SDATA_OUT1},

struct iis r_iis = {
		on stdcore[0] : XS1_CLKBLK_3,
		on stdcore[0] : XS1_CLKBLK_4,
		PORT_MCLK, PORT_SCLK, PORT_LRCLK,
		{ PORT_SDATA_IN0},
		{ PORT_SDATA_OUT0}
};

on stdcore[1]: out port scl = PORT_I2C_SCL;
on stdcore[1]: port sda = PORT_I2C_SDA;

on stdcore[0]: out port sync_out = PORT_SYNC_OUT;
//out port rst = SEL_MOD_RST;

on stdcore[1]: port p_mute_led_remote = XS1_PORT_4E; // mute, led remote;

void init_pll(unsigned mult, out port scl, port sda);
void reset_codec(out port rst);
void init_codec(out port scl, port sda, int codec_is_master, int mic_input, int instr_input);

void clkgen(int freq, out port p, chanend stop);

extern void dsp_bypass(unsigned achan_idx);
extern void sine_out(unsigned achan_idx);
extern void init_states();
extern int sine(int x);

extern int delay_proc(unsigned achan_idx, signed in_sample, unsigned delay_buf_idx, unsigned delay);

void mswait(int ms)
{
	timer tmr;
	unsigned t;
	tmr :> t;
	for (int i = 0; i < ms; i++) {
		t += 100000;
		tmr when timerafter(t) :> void;
	}
}


void loopback(unsigned idx, streaming chanend c_in[], streaming chanend c_out[]) {
	signed in_sample[NUM_OUT]; //more out than in

	while(1) {
		for(int i=0; i<NUM_OUT; i++) {
			c_out[i] <: in_sample[i];
		}
		for(int i=0; i<NUM_OUT; i++) {
			c_in[i] :> in_sample[i];
		}

		//printf("samples looped back\n");
	}
}

void delays(unsigned idx, streaming chanend c_in, streaming chanend c_out) {
	signed sample=0; //more out than in
	unsigned sample_count=0;
	while(1) {
		c_out <: sample;

		c_in :> sample;
		if(sample_count & 1) {
            // right sample
			sample = delay_proc(1, sample, 1, 5000); // delay by 5000 samples
		} else {
			sample = delay_proc(1, sample, 0, 0);
		}
		sample_count++;
		//printf("delays: sample processed\n");
	}
}


void busy_thread() {
	set_thread_fast_mode_on();
	while (1);
}

void eq_wrapper(unsigned idx, chanend cCtrl, streaming chanend cDSPActivityOutput, streaming chanend c_in, streaming chanend c_out);

on stdcore[0]: port p_uart_tx = PORT_UART_TX;

void xscope_user_init(void)
{
    xscope_register(0);
    //xscope_config_uart(p_uart_tx);

    // Enable XScope printing
    xscope_config_io(XSCOPE_IO_BASIC);
    //xscope_register(2,
    	//	XSCOPE_CONTINUOUS, "left", XSCOPE_INT, "bit",
    	//	XSCOPE_CONTINUOUS, "right", XSCOPE_INT, "bit");
}

int main()
{

	streaming chan c_in[NUM_IN], c_out[NUM_OUT];
	streaming chan c_DSP_activity[NUM_EQ_THREADS];
	chan c_ctrl[NUM_EQ_THREADS];

	par {

		on stdcore[1] : {
			// 1kHz -> 24.576MHz
			{
			set_port_drive_low(p_mute_led_remote);
			p_mute_led_remote <: 0x000;
			}
			init_pll(MCLK_MHZ / 1000, scl, sda);

		}

#ifdef AUDIO_LOOPBACK
		on stdcore[0] : loopback(0, c_in, c_out);
#else
		on stdcore[0] : eq_wrapper(0, c_ctrl[0], c_DSP_activity[0], c_in[0], c_out[0]);

#ifndef XSIM  // reduce the "noise" in the simulator trace
		// good practise to keep other threads busy
//		on stdcore[0] : busy_thread();
//		on stdcore[0] : busy_thread();
//		on stdcore[0] : busy_thread();
//		on stdcore[0] : busy_thread();
//		on stdcore[0] : busy_thread();
//		on stdcore[0] : busy_thread();
#endif

		// on core1 because there's a limit of 4 streaming channels across cores.
		on stdcore[1] : {
			//crossover(1, c_in[1], c_out[1], c_out[0]);
		}

		//on stdcore[1] : delays(1, c_in[1], c_out[1]);
		on stdcore[0] : eq_client(c_ctrl, c_DSP_activity);
#endif

		// Init PLL, start I2S tread
		on stdcore[0] : {
			chan stop;
#ifndef XSIM
			printf("Startup\n");
#else
			printf("Running on Simulator\n");
#endif

			par {
				clkgen(1000, sync_out, stop);
				{
#ifndef XSIM // don't wait 300ms when simulating

					mswait(300);
#endif
					iis(r_iis, c_in, c_out);
				}
			}
		}
	}
	return 0;
}
