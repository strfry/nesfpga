#!/usr/bin/env python

import sys

filename = sys.argv[1]
basename = filename.split(".")[0]

f = file(filename)
header = f.read(4)
assert(header == "NES\x1a")
prg_size = ord(f.read(1))
chr_size = ord(f.read(1))
f.read(10)

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
		

write_dat(basename + "_prg.dat", 16384 * prg_size)
#write_coe(basename + "_chr.coe", 8192 * chr_size)

write_dat(basename + "_chr.dat", 8192 * chr_size)
