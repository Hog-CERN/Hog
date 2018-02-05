#!/usr/bin/python
import subprocess, re, glob, requests
from time import sleep
from distutils.dir_util import copy_tree
from distutils.file_util import copy_file
from shutil import move
from os import path, listdir, kill, remove, makedirs, system

def Alive(pid):        
    """ Check For the existence of a unix pid. """
    try:
        kill(pid, 0)
    except OSError:
        return False
    else:
        return True

def MakeDir(directory, verbose=True):
    if verbose:
        print "[MakeDir] Creating directory {0} ...".format(directory)
    if not path.isdir(directory):
        makedirs(directory)
    else:
        print "[MakeDir] WARNING: Directory {0} exists".format(directory)

def SendMail(txt, subject, address):
    a=Runner()
    a.Run("echo \"{0}\" | mail -s \"{1}\" {2}".format(txt, subject, address))

def SendNote(msg, merge_request_number):
    head ={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'}
    print "[SendNote] Sending note: {0}".format(msg)
    note = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/notes".format(merge_request_number), data={'body':msg}, headers=head).status_code
    return note

def MakeRelease(msg, tag):
    head ={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'}
    print "[SendNote] Sending note: {0}".format(msg)
    release = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/repository/tags/{0}/release".format(tag), data={'tag':tag,'description':msg}, headers=head).status_code
    return release

def VivadoStatus(Path, StatusFile,
                 begin_file = ".vivado.begin.rst",
                 end_file=".vivado.end.rst",
                 error_file = ".vivado.error.rst",
                 queue_file = ".Vivado_Synthesis.queue.rst",
                 log_file = "runme.log"):

    print "[VivadoStatus] Monitoring Vivado workflow status in {0} and writing status to {1}...".format(Path,StatusFile)

    m = re.search(re.compile("(\w+).runs"),Path)
    if m:
        Project = m.group(0)
    else:
        Project = Path 
    if not path.isdir(Path):
        print "[VivadoStatus] Error! {0} does not exist".format(Path)
        return -1
    Status = {}
    Report = {}
    Phase = {}
    Names = {}
    Log = {}
    AllDone = 3
    while AllDone>0:
	    for d in listdir(Path):
                name=d
	        d=Path+'/'+d
	        if path.isdir(d):
                    Names[d]= name
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
	                        pid = m.group(1)
	                    else:
	                        print "[RunStatus] WARNING: Couldnt parse pid out of {0}".format(d+'/'+begin_file)
	                        pid = 0
	                    Status[d] = pid;
                            r = re.compile("(\w+\_\w+)\.(begin|end|error)\.rst")
                            for f in listdir(d):
                                m=re.search(r,f)
                                if m:
                                    if not d in Phase:
                                        Phase[d]= {}
                                    Phase[d][m.group(1)] = m.group(2)
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
	    OUT = open (StatusFile,"w")
	    OUT.write("<h2> Project: {0} </h2>\n".format(Project))
            AllQueued= True
            AllSuccess = True
            NoErrors = True
	    for key, value in Status.iteritems():
                Running = False
	        OUT.write("<strong> Run {0} </strong>\n".format(key))
	        if value.isdigit():
	            OUT.write("<font style=\"font-weight:bold;color:Orange\";> is running with PID={0}</font>".format(value))
	            if Alive(int(value)):
	                OUT.write("<font style=\"font-weight:bold;color:Green\";> Process {0} is alive</font>".format(value))
                        Running = True
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
	
	        if key in Phase:
                    OUT.write("&nbsp &nbsp ( &nbsp &nbsp \n")                  
                    for ph, st in Phase[key].iteritems():
                        OUT.write("<font style=\"color:Seagreen\">{0}: {1} &nbsp &nbsp  </font>\n".format(ph,st))
                    OUT.write(")\n")                  

	        OUT.write( "<br>\n")
	        
                if (value.isdigit() and Running):
                    AllDone = 3

                if (not "queued" in value):
                    AllQueued = False;

                if (not "done successfully" in value):
                    AllSuccess = False;

                if (value.isdigit() and not Running or "error" in value):
                    NoErrors = False;

	    OUT.write("<hr>\n")
	    OUT.close()
            if AllQueued or not NoErrors:
                AllDone = AllDone-1
            if AllSuccess:
                AllDone = -10
	    sleep(30)
    if NoErrors and not AllQueued:
        msg = "All done successfully for: {0}".format(Project)
        ret_val=0
    elif AllQueued:
        msg = "All process are queued for a while for: {0}".format(Project)
        re_val =-1
    else:
        msg = "All process are queued, dead, or in error for: {0}".format(Project)
        re_val =-2

    OUT = open (StatusFile,"a")
    OUT.write("<p> " + msg +"</p>\n")
    OUT.close()
    print "[RunStatus] "+ msg
    return ret_val
##########################################################

class Runner():
    def __init__(self, path='.'):
        self.SetPath(path)
        self.Verbose = False

    def SetPath(self, directory):
        if path.isdir(directory):
            self.Path=directory
        else:
            print "[Runner] ERROR: path {0} does not exist".format(directory)
            self.Path= ""

    def SetVerbose(self, v=True):
        self.Verbose = v


    def RealTime (self, command):
        #cmd = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, cwd=self.Path)
        #while cmd.poll() is None:
        #    print cmd.stdout.readline()
        #self.ReturnCode = cmd.returncode
        cmd = system("cd {0}; ".format(self.Path)+command)
        self.ReturnCode = cmd >> 8


    def Run(self, command):
        if self.Verbose:
            print "Running: '", command, "' From: '", self.Path, "'"
        cmd = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, cwd=self.Path)
        result = [x.rstrip() for x in list(cmd.stdout)]
        cmd.wait()
        if self.Verbose:
            print 'Result:'
            print result
            print '-------'
        self.ReturnCode = cmd.returncode
        return result

##########################################################

class VivadoProjects():
    def __init__(self, repo_path, s_branch="", t_branch="", merge_n=0, revision_path="", web_path=""):
        self.Names = []
        self.StartRunEnabled = False
        self.Paths = {}
        self.Statuses = {}
        self.ToDo = {}
        self.RepoPath = repo_path
        self.MergeRequestNumber = merge_n
        self.TopPath = self.RepoPath+'/Top'
        self.Commit = ""
        self.LockFile = ""
        self.SourceBranch = s_branch
        self.TargetBranch = t_branch
        self.NJobs  = 0
        self.RevisionPath = revision_path
        self.WebPath = web_path
        self.runner = Runner()
        self.runner.SetPath(self.RepoPath)
        self.State = {}
        self.Report = {}
        self.VivadoCommandLine = "vivado -mode batch -notrace -journal {JournalFile} -log {LogFile} -source ./Tcl/launch_runs.tcl -tclargs {Project} {RunsDir} {NJobs}"

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
                    self.State[name] = 'new'
                else:
                    print "[Vivado Projects] WARNING: list direcotry not found in project {0}, skipping...".format(name)

    def VivadoCommand(self, proj):
        return self.VivadoCommandLine.format(JournalFile=self.JournalFile(proj), LogFile=self.LogFile(proj), Project=proj, RunsDir=self.RunsDir(proj), NJobs=self.NJobs)

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

    def OutDir(self, proj):
        return "{0}/{1}/{2}".format(self.RevisionPath,self.Commit,proj)

    def RunsDir(self, proj):
        if self.isToDo(proj):
            return self.RepoPath+"/VivadoProject/{0}/{0}.runs".format(proj)
        else:
            return ""

    def ArchiveDir(self, proj):
        return "{0}/firmware/{1}/{2}".format(self.WebPath,self.Commit,proj)


    def JournalFile(self, proj):
        if self.isToDo(proj):
            return self.OutDir(proj)+"/viv.jou"
        else:
            return ""

    def LogFile(self, proj):
        if self.isToDo(proj):
            return self.OutDir(proj)+"/viv.log"
        else:
            return ""
            
    def isToDo(self, proj):
        if self.Exists(proj) and proj in self.ToDo:
            return True
        else:
            return False

    def StatusFile(self, proj):
        return self.WebPath+'/status-'+self.Commit+'-'+proj    

    def WriteStatus(self, proj):
        msg="Preparing run for project: {0} ({1}) from branch {2} to {3}, with {4} jobs.".format(proj,self.Commit,self.SourceBranch,self.TargetBranch,self.NJobs)
        f_status=open(self.StatusFile(proj),'w')
        f_status.write(msg)
        f_status.close


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

    def EvaluateNJobs(self):
        # add some control here...
        self.NJobs = int(self.runner.Run('/usr/bin/nproc')[0])
        print "[VivadoProjects] Found {0} CPUs".format(self.NJobs)

    def EnableStartRun(self, enable=True):
        self.StartRunEnabled = enable

    def RemoveLockFile(self):
        print "[VivadoProjects] Removing lockfile {0} if exists".format(self.LockFile)
        if path.isfile(self.LockFile):
            remove(self.LockFile)
        else:
            print "[VivadoProjects] Lockfile {0} not found".format(self.LockFile)

    def StoreRun(self, proj):
        # copy the whole runs dir for debug
        print "[StoreRun] Copying {0} to {1}".format(self.RunsDir(proj), self.OutDir(proj))
        copy_tree(self.RunsDir(proj), self.OutDir(proj), verbose=1)

    def StoreBitFile(self, proj):
        # Look for bitfile
        print "[StoreBitFile] Creating archive directory..."
        MakeDir(self.ArchiveDir(proj))
        print "[StoreBitFile] Looking for bitfiles..."
        Found = False
        for bit_file in glob.iglob(self.RunsDir(proj)+"/**/*{0}.bit".format(proj)):
            Found = True
            dst=self.ArchiveDir(proj)+"/{0}-{1}.bit".format(proj, self.Commit)
            print "[StoreBitFile] Found bitfile: {0}, moving it to {1}".format(bit_file, dst)
            move(bit_file, dst)
        print "[StoreBitFile] Looking for binfiles..."
        for bin_file in glob.iglob(self.RunsDir(proj)+"/**/*{0}.bin".format(proj)):
            dst=self.ArchiveDir(proj)+"/{0}-{1}.bin".format(proj, self.Commit)
            print "[StoreBitFile] Found binfile: {0}, moving it to {1}".format(bin_file, dst)
            move(bin_file, dst)
        return Found

    def StoreFiles(self, proj):
        xml_dir=self.ArchiveDir(proj)+'/xml'
        MakeDir(xml_dir)
        copy_tree(self.OutDir(proj)+'/xml', xml_dir)
        rpt_dir = self.ArchiveDir(proj)+"/reports"
        MakeDir(rpt_dir)
        for report in glob.iglob(self.RunsDir(proj)+'/**/*.rpt'):
            copy_file(report, rpt_dir)
            if 'timing' in report and proj in report:
                with open(report) as f:
                    lines = f.read().splitlines()
                    try:
                        start=lines.index([x for x in lines if "Design Timing Summary" in x][0])
                        titles= re.split('\s\s+', lines[start+4].strip())
                        values= re.split('\s\s+', lines[start+6].strip())
                        timing= ["{0} = {1}".format(t,v) for t,v in zip(titles,values)]
                        timing.append(lines[start+9])
                        ret= "  \n".join(timing)
                        self.Report[proj] = ret
                    except ValueError:
                        ret = '[StoreFiles] ERROR: could not parse timing report'
                        print ret
                    break
        if not proj in self.Report:
            ret = '[StoreFiles] ERROR: could not find timing report'
            print ret
        return ret



    def PrepareRun(self, RepoReset=True, Force=False):
		RetVal = 0
		name='[PrepareRun] '
		r=Runner()
		for p in [self.RepoPath, self.RevisionPath, self.WebPath]:
		    r.Run('kinit -kt /home/efex/efex.keytab efex')
		    r.Run('/usr/bin/eosfusebind krb5')
		
		    if not path.isdir(p):
		        print name + "ERROR: {0} does not exist".format(p)
		        return -1
		
		self.LockFile=self.RevisionPath+"/lock"
                if not Force:
                    while path.isfile(self.LockFile):
                        print name+"Waiting for lockfile {0} to disappear...".format(self.LockFile)
                        sleep(30)
		lf=open(self.LockFile, 'w')
		#maybe write something to it?
		lf.close()
		
		#check if git,awk,nproc exist
		#chek git version maybe...
		
		r.SetPath(self.RepoPath)
                r.Run('git fetch')
                r.Run("git rev-parse --verify {0}".format(self.SourceBranch))
                if not r.ReturnCode == 0:
                    print name+"ERROR: source branch {0} does not exist".format(self.SourceBranch)
                    self.RemoveLockFile()
                    return 4
                r.Run("git rev-parse --verify {0}".format(self.TargetBranch))
                if not r.ReturnCode == 0:
                    print name+"ERROR: target branch {0} does not exist".format(self.TargetBranch)
                    self.RemoveLockFile()
                    return 5

                r.Run('git submodule init')
		r.Run('git submodule update')
                if RepoReset:
                    print name+"Cleaning and resetting repository..."
                    r.Run('git clean -xdf')
                    r.Run('git reset --hard HEAD')
		print name+"Checking out target branch {0} ...".format(self.TargetBranch)
		r.Run("git checkout {0}".format(self.TargetBranch))
		print name+"Pulling from repository ..."
		r.Run('git pull')
		OldProj = VivadoProjects(self.RepoPath)
		OldProj.Scan()
		print name+"Checking out source branch {0} ...".format(self.SourceBranch)
		r.Run("git checkout {0}".format(self.SourceBranch))
		print name+"Pulling from repository ..."
		r.Run('git pull')
		message="Merging {0} into {1} before automatic workflow...".format(self.TargetBranch,self.SourceBranch)
		print name+message
		r.Run("git merge -m \" {0} \" {1}".format(message,self.TargetBranch))
		if not r.ReturnCode == 0:
		    print name+"ERROR: Problems during merging {0} into {1}, aborting...".format(self.TargetBranch,self.SourceBranch)
                    self.RemoveLockFile()
                    return 3
		else:
		    print name+"Merge was successful"
		    self.Scan()
		    self.Commit=r.Run('git describe --always --match v*')[0]
		    print name+"Project is now at {0} on {1}".format(self.Commit,self.SourceBranch)
		    self.Compare(OldProj)
		    self.EnableStartRun()
		    print name+"StartRun enabled"
                    return 0		

    def StartRun(self):
        if self.StartRunEnabled:
            if len(self.ToDo.keys()) > 0:
                self.EvaluateNJobs()
                print "[StartRun] Looping over projects..."
                for Project in self.ToDo.keys():
                    print "[VivadoProjects] Preparing run for: {0}, path: {1}".format(Project, self.Path(Project))
                    MakeDir(self.OutDir(Project))
                    self.WriteStatus(Project)
                    print "[StartRun] Command: " + self.VivadoCommand(Project) 
                    print "[StartRun] ***** STARTING VIVADO for {0} *****".format(Project)
                    self.runner.RealTime(self.VivadoCommand(Project))
                    print "[StartRun] ***** VIVADO END for {0} *****".format(Project)
                    if self.runner.ReturnCode == 0:
                        ret = VivadoStatus(self.RunsDir(Project), self.StatusFile(Project))                    
                        if ret == 0:
                            print "[StartRun] Vivado run was successful for {0} *****".format(Project)
                            self.StoreRun(Project)
                            if self.StoreBitFile(Project):
                                self.State[Project] = 'success'                                                        
                                time_rep = self.StoreFiles(Project)
                                # clean repo?? let's try not to
                                SendNote("# Project: {}\n\nWork-flow was successfull\n\n# Timing report\n\n{}".format(Project, time_rep), self.MergeRequestNumber)
                            else:
                                self.State[Project] = "error bitfile"                                                        
                        else:
                            print "[StartRun] WARNING something went wrong with Vivado run for {0} *****".format(Project)
                            self.State[Project] = "error vivado flow"                            
                    else:
                        print "[StartRun] ERROR: Vivado returned an error status"
                        self.State[Project] = "error vivado launch"
            else:
                print "[StartRun] No projects to run"
                self.State[Project] = "error vivado"
        else:
                print "[StartRun] Start Run not enabled, run PrepareRun first"

    def Finalise(self):
        if self.CheckRuns():
            print "[CheckRuns] All runs were successful"
            self.PushBranch()
            # Tag Repo
            # Launch Doxygen
        else:
            print "[CheckRuns] WARNING: Not all runs were successful"
        print "[VivadoProjects] Removing lock file, if any"
        self.RemoveLockFile()

    def CheckRuns(self):
        AllGood = True
        for proj, state in self.State.iteritems():
            if not state == 'success':
                print "[CheckRuns] WARNING: State for project {} is {}".format(proj, state)
                AllGood = False
            else:
                print "[CheckRuns] State for project {} is {}".format(proj, state)
        return AllGood
        

    def PushBranch(self):
        print "[PushBranch] Pushing source branch: {} after successful workflow...".format(self.SourceBranch)
        r.Run("git push origin {0}".format(self.SourceBranch))


    def TagRepo(self):
        #TAGS=`git tag -l aws$TAG_NUMBER*| wc -l`
        #TAG_NAME=aws$TAG_NUMBER.$TAGS
        #echo [AutoLaunchRun] Tagging $TAG_NAME and pushing...
        #git tag $TAG_NAME -m "Automatic tag ($TAG_NAME) after successful automatic work flow" -m "$GIT_MESSAGE"
        #git push origin $TAG_NAME
        pass

    def LaunchDoxygen(self):
        #echo "" >> doxygen/doxygen.conf
        #echo -e "\nPROJECT_NUMBER = $COMMIT" >> doxygen/doxygen.conf
        #rm -rf ../Doc
        #mkdir -p ../Doc/html
        #echo [AutoLaunchRun] Launching doxygen...
        #/usr/bin/doxygen doxygen/doxygen.conf 2>&1 > ../Doc/html/doxygen-$COMMIT.log
        #rm -r $WEB_DIR/../doc/*
        #cp -r ../Doc/html/* $WEB_DIR/../doc/
        pass

###################################################
