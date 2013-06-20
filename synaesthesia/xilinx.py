#!/usr/bin/env python

import popen2
import sys, os
from time import gmtime, strftime


#######################################################################
#
#
class Xilinx(object):
  '''Python classe to run implementation tools

  TODO: make it modular to allow other implementation tools
  '''
  def __init__(self, path=None, top_name=None):
    self.path = '.'
    if path is not None:
      # TODO: add some code to have path separator all the same
      # either windows or linux, depending on what system it runs
      self.path = path
    self.fpga = None
    self.tcl_name = None
    self.top_name = None
    if top_name:
      if isinstance(top_name, str):
        self.top_name = top_name
        self.tcl_name = top_name + '.tcl'
      else:
        raise TypeError('top_name needs to be string')
    self.hdl_fileL = []

    # start with the text string for the TCL script
    self.tcl_script = '#\n#\n# ISE implementation script\n'
    date_time = strftime("%a, %d %b %Y %H:%M:%S +0000", gmtime())
    self.tcl_script += '# create: %s\n'%date_time
    self.tcl_script += '# by: %s\n'%os.path.basename(sys.argv[0])
    self.tcl_script += '#\n#\n'

  def addHdl(self, files):
    '''Add HDL files to the project
    files : string or list of strings
    '''
    if isinstance(files, str):
      self.hdl_fileL.append(files)

    elif isinstance(files, (list, tuple)):
      
      for f in files:
        if not isinstance(f, str):
          raise TypeError('List or Tuple entry needs to be a string')
        self.hdl_fileL.append(f)

    else:
      raise TypeError('files not string or list of strings')

  def createTcl(self, target, filename=None):
    '''Creat the TCL script
    '''
    if filename:
      fn = os.path.join(self.path, filename)
    else:
      fn = os.path.join(self.path, self.tcl_name)

    self.tcl_script += '# set compile directory:\n'
    self.tcl_script += 'set compile_directory %s\n'%self.path
    if self.top_name:
      self.tcl_script += 'set top_name %s\n'%self.top_name
    if self.hdl_fileL:
      self.tcl_script += '# input source files:\n'
      self.tcl_script += 'set hdl_files [ list \\\n'
      for f in self.hdl_fileL:
        self.tcl_script += ' '*17
        self.tcl_script += '%s \\\n'%f
    self.tcl_script += ']\n'

    if self.fpga:
      if not self.fpga.ucf_file:
        if not self.top_name:
          raise ValueError('No Top Name set')
        self.fpga.createUcf(self.top_name + '.ucf')

      self.tcl_script += '# set ucf file:\n'
      self.tcl_script += 'set constraints_file %s\n'% self.fpga.ucf_file
      
    self.tcl_script += '# set Project:\n'
    self.tcl_script += 'set proj %s\n'% self.top_name
    
    self.tcl_script += '# change to the directory:\n'
    self.tcl_script += 'cd %s\n'% self.path
     
    # test whether ise project file exits
    f = os.path.join(self.path, self.top_name + '.ise')
    pj_fn = self.top_name + '.ise'
    if os.path.exists(f):
      os.remove(f)
    self.tcl_script += '# set variables:\n'
    self.tcl_script += 'project new %s\n'%pj_fn
    if self.fpga.family:
      self.tcl_script += 'project set family %s\n'%self.fpga.family
    self.tcl_script += 'project set device %s\n'%self.fpga.device
    self.tcl_script += 'project set package %s\n'%self.fpga.package
    self.tcl_script += 'project set speed %s\n'%self.fpga.speed

    # add the hdl files
    self.tcl_script += '# add hdl files:\n'
    for hdl_file in self.hdl_fileL:
      self.tcl_script += 'xfile add %s\n'%hdl_file

    self.tcl_script += '# test if set_source_directory is set:\n'
    self.tcl_script += 'if { ! [catch {set source_directory'
    self.tcl_script += ' $source_directory}]} {\n'
    self.tcl_script += '  project set "Macro Search Path"\n'
    self.tcl_script += ' $source_directory -process Translate\n'
    self.tcl_script += '}\n'

    
    # run the implementation
    self.tcl_script += '# run the implementation:\n'
    self.tcl_script += 'process run "' + target + '"\n'
    # close the project
    self.tcl_script += '# close the project:\n'
    self.tcl_script += 'project close\n'

    
    fid = open(fn, 'w')
    fid.write(self.tcl_script)
    fid.close()





  def run(self, filename=None):
    '''Run the created TCL script
    '''

    # Workaround: Delete .xise file
    try:
      os.unlink(self.path + '/' + self.top_name + '.xise')
    except:
      pass
    

    if filename:
      tcl_name = filename
    else:
      tcl_name = os.path.join(self.path, self.tcl_name)

    if not os.path.exists(self.path):
      os.mkdir(self.path)

#    self.fpga.createUcf()
    cmd = 'xtclsh ' + tcl_name
    print 'running command: ', cmd

    import subprocess
    subprocess.call(cmd, shell=True)

#    r, w, e = popen2.popen3(cmd)
#    print 'errors: ', e.readlines()
#    print 'reply: ', r.readlines()
#    r.close()
#    e.close()
#    w.close()

  def setFpga(self, fpga):
    self.fpga = fpga

#######################################################################
#
#
class Fpga(object):
  def __init__(self, path=None):
    self.path= '.'
    if path is not None:
      self.path = path
    self.ucfD = {}
    self.ucf_file = None
    self.family = None
    self.device = None
    self.package = None
    self.speed = None

  def setPin(self, net, pin, iostandard=None, slew=None, drive=None):
    if iostandard is None and slew is None and drive is None:
      self.ucfD[pin] = [net, None]
    else:
      self.ucfD[pin] = [net, [iostandard, slew, drive]]


  def setDevice(self, family, device, package, speed):
    
    if not isinstance(family, str):
      raise TypeError('"Family" needs to be a string')
    if not isinstance(device, str):
      raise TypeError('"Device" needs to be a string')
    if not isinstance(speed, str):
      raise TypeError('"Speed" needs to be a string')
    if not isinstance(package, str):
      raise TypeError('"Package" needs to be a string')
    
    self.family = family
    self.device = device
    self.package = package
    self.speed = speed



  def createUcf(self, filename='my.ucf'):
    self.ucf_file = os.path.join(self.path, filename)

    str = '# UCF file automatically create by "%s"\n'%os.path.basename(sys.argv[0])
    str += '#\n'
    for key, value in self.ucfD.items():
      str += 'NET "%s"  LOC = "%s"'%(value[0], key)
      if value[1] is not None:
        if value[1][0] is not None:
          str += ' | IOSTANDARD = %s'%value[1][0]
        if value[1][1] is not None:
          str += ' | SLEW = %s'%value[1][1]
        if value[1][2] is not None:
          str += ' | DRIVE = %s'%value[1][2]

      str += ' ;\n'
    
    str += '#\n'

    fid = open(self.ucf_file, 'w')
    fid.write(str)
    fid.close()

  def __repr__(self):
    s = 'FPGA:\n'
    if self.family:
      s += 'Family: %s\n'% self.family
    s += 'Device: %s\n'% self.device
    s += 'Package: %s\n'% self.package
    s += 'Speed: %s\n'% self.speed
    return s
