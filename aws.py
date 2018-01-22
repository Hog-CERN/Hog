#!/usr/bin/python
import subprocess
import re
from time import sleep
from shutil import move, copy2 as copy
from os import path, listdir, kill, remove, makedirs

def Alive(pid):        
    """ Check For the existence of a unix pid. """
    try:
        kill(pid, 0)
    except OSError:
        return False
    else:
        return True


class Runner():
    def __init__(self, path='.'):
        self.SetPath(path)
        self.Verbose = False

    def SetPath(self, directory):
        if path.isdir(directory):
            self.Path=directory
        else:
            print "[Runner] Error, path {0} does not exist".format(path)
            self.Path= ""

    def SetVerbose(self, v=True):
        self.Verbose = v

    def Run(self, command):
        if self.Verbose:
            print "Running: '", command, "' From: '", self.Path, "'"
        cmd = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, cwd=self.Path)
        result = [x.rstrip() for x in list(cmd.stdout)]
        if self.Verbose:
            print 'Result:'
            print result
            print '-------'
        cmd.wait()
        self.ReturnCode = cmd.returncode
        return result


class VivadoProjects():
    def __init__(self, repo_path, s_branch="", t_branch="", merge_n=0, revision_path="", web_path=""):
        self.Names = []
        self.Paths = {}
        self.Statuses = {}
        self.ToDo = {}
        self.RepoPath = repo_path
        self.TopPath = self.RepoPath+'/Top'
        self.Commit = ""
        self.SourceBranch = s_branch
        self.TargetBranch = t_branch
        self.NJobs  = 0
        self.RevisionPath = revision_path
        self.WebPath = web_path
        self.runner = Runner()
        self.runner.SetPath(self.RepoPath)
        self.VivadoCommand = "vivado -mode batch -notrace -journal {JournalFile} -log {LogFile} -source ./Tcl/launch_runs.tcl -tclargs {Project} {RunsDir} {NJobs}"


    def Scan(self):
        s = Runner()
        for name in listdir(self.TopPath):
            d=self.TopPath+"/"+name
            if path.isdir(d):
                s.SetPath(d)
                ListDir = "{0}/list".format(d)
                if path.isdir(ListDir):
                    Status = s.Run("git log --format=%h -1 -- $(awk '!/^ *#/ && NF {{print $1}}' {0}/list/*) .".format(d))[0]
                    print "[VivadoProjects] Status of project {0} is {1}".format(name,Status)
                    self.Names.append(name)
                    self.Statuses[name]=Status
                    self.Paths[name]= d
                else:
                    print "[Vivado Projects] WARNING: list direcotry not found in project {0}, skipping...".format(name)


    def Exists(self, proj):
        if proj in self.Names:
            return True
        else:
            return False
        
    def Status(self, proj):
        if self.Exists(proj):
            return self.Statuses[proj]
        else:
            return 0

    def Path(self, proj):
        if self.Exists(proj):
            return self.Paths[proj]
        else:
            return 0

    def SetToDo(self, proj):
        if self.Exists(proj):
            self.ToDo[proj] = True

    def isToDo(self, proj):
        if self.Exists(proj) and proj in self.ToDo:
            return True
        else:
            return False

    def Compare(self, OldProjects):
        for np in self.Names:
            if OldProjects.Exists(np):
                if OldProjects.Status(np) == self.Status(np):
                    print "[VivadoProjects] Project {0} will not be influenced by this merge, design-flow will be skipped...".format(np)
                else:
                    print "[VivadoProjects] Project {0} was at {1} and is now at {2}".format(np, OldProjects.Status(np), self.Status(np))
                    self.SetToDo(np)
            else:
                print "[VivadoProjects] New project found: {0}".format(np)
                self.SetToDo(np)


    def TimePath(self):
        return self.RevisionPath+'/'+self.Commit+'/'+'timing'

    def UtilPath(self):
        return self.RevisionPath+'/'+self.Commit+'/'+'util'

    def EvaluateNJobs(self):
        # add some control here...
        self.NJobs = int(self.runner.Run('/usr/bin/nproc')[0])
        print "[VivadoProjects] Found {0} CPUs".format(self.NJobs)

    def Start(self):
        if len(self.ToDo.keys()) > 0:
            print "[VivadoProjects] Creating global directories"
            MakeDir(self.TimePath())
            MakeDir(self.UtilPath())
            print "[VivadoProjects] Looping over projects..."
            for Project in self.ToDo.keys():
                print "[VivadoProjects] Preparing run for: {0}, path: {1}".format(Project, self.Path(Project))
                RunsDir="./VivadoProject/{0}/{0}.runs".format(Project)
                OutDir="{0}/{1}/{2}".format(self.RevisionPath,self.Commit,Project)
                print "[VivadoProjects] Creating directory {0} for project {1}...".format(OutDir, Project)
                MakeDir(OutDir)
                LogFile=OutDir+"/viv.log"
                JournalFile=OutDir+"/viv.jou"
                self.EvaluateNJobs()
                print "[VivadoProjects] Preparing run for project: {0} ({1}) from branch {2} to {3}, with {4} jobs...".format(Project,self.Commit, self.SourceBranch, self.TargetBranch, self.NJobs)
                # write this to $WEB_DIR/status-$COMMIT-$PROJECT
                #r.Run
                print "[VivadoProjects] Command: " + self.VivadoCommand.format(JournalFile=JournalFile, LogFile=LogFile, Project=Project, RunsDir=RunsDir, NJobs=self.NJobs)
        else:
            print "[VivadoProjects] No projects to run"


    def LaunchVivadoRun(self):
		RetVal = 0
		name='[LaunchVivadoRun] '
		r=Runner()
		for p in [self.RepoPath, self.RevisionPath, self.WebPath]:
		    r.Run('kinit -kt /home/efex/efex.keytab efex')
		    r.Run('/usr/bin/eosfusebind krb5')
		
		    if not path.isdir(p):
		        print name + "Error! {0} does not exist".format(p)
		        return -1
		
		LockFile=self.RevisionPath+"/lock2"
		while path.isfile(LockFile):
		    print name+"Waiting for lockfile {0} to disappear...".format(LockFile)
		    sleep(10)
		lf=open(LockFile, 'w')
		#maybe write something to it?
		lf.close()
		
		#check if git,awk,nproc exist
		#chek git version maybe...
		
		r.SetPath(self.RepoPath)
		r.SetVerbose()
		r.Run('git submodule init')
		r.Run('git submodule update')
		r.Run('git clean -xdf')
		r.Run('git reset --hard HEAD')
		print name+"Checking out target branch {0} ...".format(self.TargetBranch)
		r.Run("git checkout {0}".format(self.TargetBranch))
		print name+"Pulling from repository ..."
		r.Run('git pull')
		AllGood=True
		AtLeastOne=False
		s=Runner()
		OldProj = VivadoProjects(self.RepoPath)
		OldProj.Scan()
		print name+"Checking out source branch {0} ...".format(self.SourceBranch)
		r.Run("git checkout {0}".format(self.SourceBranch))
		print name+"Pulling from repository ..."
		r.Run('git pull')
		message="Merginging {0} into {1} before automatic workflow...".format(self.TargetBranch,self.SourceBranch)
		print name+message
		r.Run("git merge -m \" {0} \" {1}".format(message,self.TargetBranch))
		if not r.ReturnCode == 0:
		    print name+"ERROR: Problems during merging {0} into {1}, aborting...".format(self.TargetBranch,self.SourceBranch)
		    RetVal= 3
		else:
		    print name+"Merge was successful"
		    self.Scan()
		    self.Commit=r.Run('git describe --always --match v*')[0]
		    print name+"Project is now at {0} on {1}".format(self.Commit,self.SourceBranch)
		    self.EvaluateNJobs()
		    print name+"Found {0} CPUs".format(self.NJobs)
		    self.Compare(OldProj)
		    self.EvaluateNJobs()
		    self.Start()
		
		print name+"Removing lock file"
		remove(LockFile)
		return RetVal
###################################################





def MakeDir(directory, verbose=True):
    if verbose:
        print "[MakeDir] Creating directory {0} ...".format(directory)
    if not path.isdir(directory):
        makedirs(directory)
    else:
        print "[MakeDir] WARNING: Directory {0} exists".format(directory)

def SendMail(txt, subject, address):
    a=Runner()
    a.Run("echo \"{0}\" | mail -s \"{1}\" {2}".format(txt, subject,address))

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



#VivadoStatus("../eFEXFirmware/VivadoProject/process_fpga/process_fpga.runs/", "test")
