#!/bin/bash
#
# Workaround to launch xst manually
#

XILINX_HOME=/opt/cad/xilinx/xilinx-13.1-64b/ISE_DS/ISE

# echo run -ifn watchvhd.vhd -ifmt VHDL -ofn watchvhd.ngc -ofmt NGC -p xcv50-bg256-6 -opt_mode Speed 

# Workaround for random runtime linker errors.
# Debugging stuff like this is not exactly fun.
# Seriously Xilinx, fuck you guys!.

FUBAR=$FUBAR:$XILINX_HOME/lib/lin64/libboost_serialization-gcc41-mt-p-1_38.so.1.38.0
FUBAR=$FUBAR:$XILINX_HOME/lib/lin64/libAntlr.so
FUBAR=$FUBAR:$XILINX_HOME/lib/lin64/libXst2_CoreData.so

# Oh, and XST reads on stdin for more what should be command line parameters
XST_PARAMS="$@ "$(grep -E ^[^\#] $XST_CONFIG)

echo $XST_PARAMS

export LD_PRELOAD=$FUBAR
echo $XST_PARAMS | xst
