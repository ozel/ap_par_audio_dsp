// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

///////////////////////////////////////////////////////////////////////////////
//
// Multichannel IIS master receiver-transmitter
//
// Version 1.0
// 9 Dec 2009
//
// iis.xc
//
// Works with tools version: 9.9.1
// Tested with compiler optimisations O2
//
// Copyright (C) 2009, XMOS Ltd
// All rights reserved.
//

#include <xs1.h>
#include <xclib.h>
#include "iis.h"
#include "stdio.h"
#include "defines.h"
#include "signal_overrides.h"

#ifdef USE_XSCOPE
#include "xscope.h"
#endif

// soft divide BCK off MCK
static inline void bck_32_ticks(out buffered port:32 bck)
{
#if MCK_BCK_RATIO == 2
	bck <: 0x55555555;
	bck <: 0x55555555;
#elif MCK_BCK_RATIO == 4
	bck <: 0x33333333;
	bck <: 0x33333333;
	bck <: 0x33333333;
	bck <: 0x33333333;
#elif MCK_BCK_RATIO == 8
	bck <: 0x0F0F0F0F;
	bck <: 0x0F0F0F0F;
	bck <: 0x0F0F0F0F;
	bck <: 0x0F0F0F0F;
	bck <: 0x0F0F0F0F;
	bck <: 0x0F0F0F0F;
	bck <: 0x0F0F0F0F;
	bck <: 0x0F0F0F0F;
#elif MCK_BCK_RATIO == 12
	bck <: 0x3F03F03F;
	bck <: 0xF03F03F0;
	bck <: 0x03F03F03;
	bck <: 0x3F03F03F;
	bck <: 0xF03F03F0;
	bck <: 0x03F03F03;
	bck <: 0x3F03F03F;
	bck <: 0xF03F03F0;
	bck <: 0x03F03F03;
	bck <: 0x3F03F03F;
	bck <: 0xF03F03F0;
	bck <: 0x03F03F03;
#else
#error "MCK/BCK ratio must be 2, 4, 12 or 8"
#endif
}

static inline int termination(streaming chanend c_out, streaming chanend c_in)
{
	int ct;
	asm("testct %0, res[%1]" : "=r"(ct) : "r"(c_out));
	if (ct) {
		asm("inct %0, res[%1]" : "=r"(ct) : "r"(c_out));
		asm("outct res[%0], %1" :: "r"(c_in), "r"(ct));
		return 1;
	}
	else {
		return 0;
	}
}

#pragma unsafe arrays
void iis_loop(in buffered port:32 din[], out buffered port:32 dout[], streaming chanend c_in[], streaming chanend c_out[], out buffered port:32 wck, out buffered port:32 bck)
{
	int lr = 0;
	unsigned frame_counter = 0;

#ifdef INPUT_OVERRIDE
	signed input_override[NUM_INP_ACHANS];
	unsigned first_idx;
	unsigned j;
#endif

	// inputs and outputs are 32 bits at a time
	// assuming clock block is reset - initial time is 0
	// split SETPT from IN using asm - basically a split transaction with BCK generation in between
	// input is always "up to" given time, output is always "starting from" given time
	// outputs will be aligned to WCK + 1 (first output at time 32, WCK at time 31)
	// inputs will also be aligned to WCK + 1 (first input up to time 63, WCK up to time 62)
	for (int i = 0; i < NUM_OUT; i++) {
		dout[i] @ 32 <: 0;
	}
	for (int i = 0; i < NUM_IN; i++) {
		asm("setpt res[%0], %1" :: "r"(din[i]), "r"(63));
	}
	wck @ 31 <: 0;

	// clocks for previous outputs / inputs
	bck_32_ticks(bck);
	bck_32_ticks(bck);

	while(1) {
		// output audio data
		// expected to come from channel end as left-aligned
#pragma loop unroll
		for (int i = 0; i < NUM_OUT; i++) {
			signed x = 0;
			c_out[i] :> x;
			dout[i] <: bitrev(x);
		}

		// drive word clock
		wck <: lr;
		lr = ~lr;

		// input audio data
		// will be output to channel end as left-aligned
		// compiler would insert SETC FULL on DIN input, because it doesn't know about inline SETPT above
		// hence we need inline IN too
#pragma loop unroll
		for (int i = 0; i < NUM_IN; i++) {
			signed x;
			asm("in %0, res[%1]" : "=r"(x)  : "r"(din[i]));
#ifndef INPUT_OVERRIDE
			c_in[i] <: bitrev(x);
#else
			c_in[i] <: input_override[i];
#endif
		}

		// drive bit clock
		bck_32_ticks(bck);

#ifdef INPUT_OVERRIDE
		if(lr==0) {first_idx = 0;} else {first_idx=1;};
		j=0;
		// generate input signal override
		for(int i=first_idx; i<NUM_INP_ACHANS; i+=2) {
            input_override[j] = override_input(i);
            j++;
		}
#endif

		frame_counter++;
	};
}

void iis(struct iis &r_iis, streaming chanend c_in[], streaming chanend c_out[])
{

#ifndef XSIM
	// clock block 1 clocked off MCK
	set_clock_src(r_iis.cb1, r_iis.mck);
#else
    // generate internal clock
	// 100 MHz /  24.576MHz  = 4.0690104167
	configure_clock_rate(r_iis.cb1, 100, 4);
	configure_port_clock_output(r_iis.mck , r_iis.cb1);
#endif

	// clock block 2 clocked off BCK (which is generated on-chip)
	set_clock_src(r_iis.cb2, r_iis.bck);

	// BCK port clocked off clock block 1
	set_port_clock(r_iis.bck, r_iis.cb1);

	// WCK and all data ports clocked off clock block 2
	set_port_clock(r_iis.wck, r_iis.cb2);
	for (int i = 0; i < NUM_IN; i++) {
		set_port_clock(r_iis.din[i], r_iis.cb2);
	}
	for (int i = 0; i < NUM_OUT; i++) {
		set_port_clock(r_iis.dout[i], r_iis.cb2);
	}

	// drain all ports (usually required after termination)
	clearbuf(r_iis.bck);
	clearbuf(r_iis.wck);
	for (int i = 0; i < NUM_IN; i++) {
		clearbuf(r_iis.din[i]);
	}
	for (int i = 0; i < NUM_OUT; i++) {
		clearbuf(r_iis.dout[i]);
	}

	// start clock blocks after configuration
	start_clock(r_iis.cb1);
	start_clock(r_iis.cb2);

	// fast mode - instructions repeatedly issued instead of paused
	set_thread_fast_mode_on();


	iis_loop(r_iis.din, r_iis.dout, c_in, c_out, r_iis.wck, r_iis.bck);

	stop_clock(r_iis.cb1);
	stop_clock(r_iis.cb2);
	set_clock_ref(r_iis.cb1);
	set_clock_ref(r_iis.cb2);
	set_thread_fast_mode_off();
}
