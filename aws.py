#!/usr/bin/python
import subprocess
import re
from time import sleep
from shutil import move, copy2 as copy
from os import path, listdir, kill

def Alive(pid):        
    """ Check For the existence of a unix pid. """
    try:
        kill(pid, 0)
    except OSError:
        return False
    else:
        return True


def Run(command, path='.', verbose=False):
    if verbose:
        print "Running: '", command, "' From: '", path, "'"
    cmd = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, cwd=path)
    return [x.rstrip() for x in list(cmd.stdout)]

def SendMail(txt, subject, address):
    Run("echo \"{0}\" | mail -s \"{1}\" {2}".format(txt, subject,address))

#Run('touch minc')
#if path.isfile("minc"):
#    print "yeah"
#move("minc","../")
#SendMail("testing","subject",'atlas-l1calo-efex@cern.ch')

def VivadoStatus(Path, StatusFile,
                 begin_file = ".vivado.begin.rst",
                 end_file=".vivado.end.rst",
                 error_file = ".vivado.error.rst",
                 queue_file = ".Vivado_Synthesis.queue.rst",
                 log_file = "runme.log"):
    m = re.search(re.compile("(\w+).runs"),Path)
    if m:
        Project = m.group(0)
    else:
        Project = Path 
    if not path.isdir(Path):
        print "[VivadoStatus] Error! {0} does not exist".format(Path)
        return -1
    Status = {}
    Log = {}
    AllDone = False
    while not AllDone:
	    for d in listdir(Path):
	        d=Path+'/'+d
	        if path.isdir(d):
	                if path.isfile(d+'/'+end_file):
	                    Status[d] = "<font style=\"font-weight:bold;color:Green\";> done successfully </font>"
	                    tails=40
	                elif path.isfile(d+'/'+error_file):
	                    Status[d] = "<font style=\"font-weight:bold;color:Red\";> error </font>"
	                    tails=100
	                elif path.isfile(d+'/'+begin_file):
	                    with open(d+'/'+begin_file) as f:
	                        lines = f.read().splitlines()
	                    r = re.compile("Pid=\"(\d+)\"")
	                    l = " ".join(lines)
	                    m=re.search(r,l)
	                    if m:
	                        pid = m.group(0)
	                    else:
	                        print "[RunStatus] Couldnt parse pid out of {0}".format(d+'/'+begin_file)
	                        pid = 0
	                    Status[d] = pid;
	                    tails=100
	                elif path.isfile(d+'/'+queue_file):
	                    Status[d] = "queued"
	                    tails=20
	                                                    
	                if path.isfile(d+'/'+log_file):
	                    with open(d+'/'+log_file) as f:
	                        lines = f.read().splitlines()
	                    Log[d] = "\n".join(lines[-tails:-1])
	                else:
	                    Log[d] = 'No log file found';
	
	            # Writing on status file
	    AllDone = True
	    OUT = open (StatusFile,"w")
	    OUT.write("<h2> Project: {0} </h2>\n".format(Project))
	    for key, value in Status.iteritems():
	        OUT.write("<strong> Run {0} </strong>\n".format(key))
	        if value.isdigit():
	            OUT.write("<font style=\"font-weight:bold;color:Orange\";> is running with PID={0}</font>".format(value))
	            if Alive(int(value)):
	                OUT.write("<font style=\"font-weight:bold;color:Green\";> Process {0} is alive</font>".format(value))
	            else:
	                OUT.write("<font style=\"font-weight:bold;color:Red\";> Process {0} is dead</font>".format(value))
	        else:
	            OUT.write(value)
	                
	        if key in Log:
	            OUT.write("<label for=\"{0}\"> <font style=\"color:white;background-color:#36c\";> view </font> </label>\n".format(key))
	            OUT.write("<input type=\"checkbox\" id=\"{0}\" style=\"display:none;\">\n".format(key))
	            OUT.write("<div id=\"hidden\"><pre>\n")
	            OUT.write(Log[key])
	            OUT.write("</pre></div>\n")
	
	        OUT.write( "<br>\n")
	        
	        if value == "queued" or value.isdigit():
	            AllDone = False;
	
	    OUT.write("<hr>\n")
	    OUT.close()
	    sleep(5)
    OUT = open (StatusFile,"a")
    OUT.write("<p> All done for: {0} </p>\n".format(Project))
    OUT.close()


VivadoStatus("../eFEXFirmware/VivadoProject/process_fpga/process_fpga.runs/", "test")
