# Set up Xilinx environment variable

XILINX_SETTINGS_PATH = "/opt/Xilinx/14.5/ISE_DS/settings64.sh"

def shell_source(script):
    """Sometime you want to emulate the action of "source" in bash,
    settings some environment variables. Here is a way to do it."""
    import subprocess, os
    pipe = subprocess.Popen(". %s; env" % script, stdout=subprocess.PIPE, shell=True)
    output = pipe.communicate()[0]
    print output
    env = zip((line.split("=", 1) for line in output.splitlines()))
    os.environ.update(env)

#shell_source(XILINX_SETTINGS_PATH)

from xilinx import Fpga, Xilinx

# Specify UCF-like pin mappings

fpga = Fpga()
fpga.setPin('CLK', 'P90')
fpga.setDevice('virtex5', 'xc5vlx50t', 'ff1136', '-2')
print fpga

# Specify build files

_ = '../'

imp = Xilinx('build', 'Genesys_NES')
imp.setFpga(fpga)
imp.addHdl(_ + 'myhdl/APU_Main.v')
imp.createTcl(target = 'Generate Programming File')

# Run
imp.run()
