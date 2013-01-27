import sys

filename = sys.argv[1]
basename = filename.split(".")[0]

f = file(filename)
f.read(16)

def write_coe(name, bytes):
	fo = file(name, "w")
	fo.write("memory_initialization_radix=16;\nmemory_initialization_vector=\n")
	for i in range(0, bytes - 1):
		fo.write(hex(ord(f.read(1)))[2:] + ",\n")
	fo.write(hex(ord(f.read(1)))[2:] + ";\n")

def write_dat(name, bytes):
	fo = file(name, "w")
	for i in range(0, bytes):
		byte = f.read(1)
		fo.write('{0:08b}\n'.format(ord(byte)))
		

write_coe(basename + "_prg.coe", 32768)
#write_coe(basename + "_chr.coe", 8192)

write_dat(basename + "_chr.dat", 8192)
