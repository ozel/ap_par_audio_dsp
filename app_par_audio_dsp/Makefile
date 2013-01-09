# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling.

TARGET = XR-AVB-LC-BRD

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name

APP_NAME = app_par_audio_dsp

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
#
#    XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
#
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.

#XCC_FLAGS = -O2 -Xmapper --map -Xmapper MAPFILE -fxscope -g
#XCC_FLAGS = -O2 -fxscope -g
XCC_FLAGS = -fxscope -g

# The USED_MODULES variable lists other module used by the application.

USED_MODULES = module_fft_simple module_cascading_biquad

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.


XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

coefficients:
	#make -f ../../sc_dsp_filters/build_biquad_coefficients/Makefile FILTER='-fs 48000 -min 0 -max 0 -step 1 -bits 24 -band 440 0.01 -band 880 0.01' 		INCLUDEFILE=src/coeffs.h 		XCFILE=src/coeffs.xc 		CSVFILE=bin/response.csv
	#make -f ../../sc_dsp_filters/build_biquad_coefficients/Makefile FILTER='-fs 8000 -min 0 -max 0 -step 1 -bits 24 -band 440 0.01 -band 587.330 0.01 -band 659.255 0.01 -band 698.456 0.01 -band 783.991 0.01 -band 880 0.01' 		INCLUDEFILE=src/coeffs.h 		XCFILE=src/coeffs.xc 		CSVFILE=bin/response.csv
# -band 466.164 0.03 -band 493.883 0.3 -band 523.251 0.3 -band 587.330 0.3
	make -f ../../sc_dsp_filters/build_biquad_coefficients/Makefile FILTER='-fs 8000 -min 0 -max 0 -step 1 -bits 24 \
	-band  415.30 0.01 -band  440.00 0.01 -band  466.16 0.01 -band  493.88 0.01 \
	-band  523.25 0.01 -band  554.37 0.01 -band  587.33 0.01 -band  622.25 0.01 \
	-band  659.26 0.01 -band  698.46 0.01 -band  739.99 0.01 -band  783.99 0.01 \
	-band  830.61 0.01 -band  880.00 0.01 -band  932.33 0.01 -band  987.77 0.01 \
    -band 1046.50 0.01 -band 1108.73 0.01 -band 1174.66 0.01 -band 1244.51 0.01 \
	-band 1318.51 0.01 -band 1396.91 0.01 -band 1479.98 0.01 -band 1567.98 0.01 \
    -band 1661.22 0.01 -band 1760.00 0.01 -band 1864.66 0.01 -band 1975.53 0.01 \
    -band 2093.00 0.01 -band 2217.46 0.01 -band 2349.32 0.01 -band 2489.02 0.01 \
    -band 2637.00 0.01 -band 2793.83 0.01 -band 2959.96 0.01 -band 3135.96 0.01 \
    ' INCLUDEFILE=src/coeffs.h 		XCFILE=src/coeffs.xc 		CSVFILE=bin/response.csv
#-band 3322.44 0.01 -band 3520.00 0.01 -band 3729.31 0.01 -band 3951.07 0.01 \	

all: coefficients $(BIN_DIR)/$(APP_NAME).xe
	@echo Build Complete

clean: clean_common
	rm MakeCoeffs.class MakeCoeffs?F.class


