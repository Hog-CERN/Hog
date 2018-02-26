#!/usr/bin/python
import subprocess, re, glob, requests
from time import sleep
from distutils.dir_util import copy_tree
from distutils.file_util import copy_file
from shutil import move,rmtree
from os import path, listdir, kill, remove, makedirs, system, environ

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

def GetPrivateToken():
    return environ['PRIVATE_TOKEN']

def SendNote(msg, merge_request_number,verbose=True):
    head ={'PRIVATE-TOKEN': GetPrivateToken()}
    if verbose:
        print "[SendNote] Sending note: {0}".format(msg)
    note = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/notes".format(merge_request_number), data={'body':msg}, headers=head).status_code
    return note

def NewTag(tag, ref, msg, release_description=None):
    head ={'PRIVATE-TOKEN': GetPrivateToken()}
    print "[NewTag] Making new tag: {0} from {1}".format(tag, ref)
    data={'tag_name':tag,'message':msg,'ref':ref, 'message':msg}
    if release_description is not None:
        data['release_description'] = release_description
    release = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/repository/tags", data=data, headers=head).status_code
    return release

def UploadFile(filename):
    head ={'PRIVATE-TOKEN': GetPrivateToken()}
    files = {'file': open(filename, 'rb')}
    r = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/uploads", headers=head, files=files)
    if r.status_code == 200 or r.status_code == 201:
        print('[UploadFile] Uploading the file {0}....'.format(filename))
    else:
        print('[UploadFile] File {0} was not uploaded'.format(filename))

    markdown = r.json()['markdown']
    return markdown

def Compare(f,g):
    F = []
    G = [] 
    for line in open(f):
        li=line.strip()
        if not li.startswith("--"):
            F.append(line.rstrip())
    for line in open(g):
        li=line.strip()
        if not li.startswith("--"):
            G.append(line.rstrip())
    if F==G:
        return True
    else:
        return False


def VivadoStatus(Path, StatusFile,
                 wait_time = 30,
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
	    sleep(wait_time)
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
        self.Silent = False

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
        if self.Silent:
            std_err=subprocess.STDOUT
        else:
            std_err = None
        cmd = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, cwd=self.Path, stderr=std_err)
        result = [x.rstrip() for x in list(cmd.stdout)]
        cmd.wait()
        if self.Verbose:
            print 'Result:'
            print result
            print '-------'
        self.ReturnCode = cmd.returncode
        return result

##########################################################

class Version():
    def __init__(self, x,y,z, n=0):
        self.x = [x,y,z,n]
        self.mr = None

    def FromCommit (self, commit):
        regex = re.compile("^(?:b(\d+))?v(\d+)\.(\d+)\.(\d+)(?:-(\d+))?(?:-\d+-g[abcdef0123456789]{7})?$")
        m=re.search(regex,commit)
        if m:
            self.x[0:3] = [int(j) for j in list(m.groups()[1:4])]
            if m.groups()[0] is not None:
                self.mr = int(m.groups()[0]) 
            else:
                self.mr = None

            if m.groups()[4] is not None:
                self.x[3] = int(m.groups()[4])
            else:
                self.x[3] = 0
        else:
            print "[Version] ERROR: Something wrong with parsing git describe"
            
    def Increase(self, what=0):
        what = 3-what 
        self.x[what] += 1
        self.x[what+1:len(self.x)] = [0 for y in self.x[what+1:len(self.x)]]
        return self
        
    def isBeta(self):
        if self.mr is not None:
            return True
        else:
            return False

    def SetBeta(self, mr):
        self.mr = mr
        self.x[3] = 0

    def Tag(self, alpha=False):
        if self.isBeta() and not alpha:
            Type = 'b'+ str(self.mr)
            end = '-' + str(self.x[3])
        else:
            Type = ''
            end = ''
            
        return Type+'v'+str(self.x[0])+'.'+str(self.x[1])+'.'+str(self.x[2])+end

    def __repr__(self):
        return self.Tag()

    def to_number(self):
        res = 0
        for i in range(0,len(self.x)):
            res += 100**(3-i)*self.x[i]
        return res

    def __eq__(self, other):
        return self.to_number() == other.to_number()

    def __gt__(self, other):
        return self.to_number() > other.to_number()

    def __lt__(self, other):
        return self.to_number() < other.to_number()

    def __ge__(self, other):
        return self.to_number() >= other.to_number()

    def __le__(self, other):
        return self.to_number() <= other.to_number()


##########################################################

class VivadoProjects():
    def __init__(self, repo_path, s_branch="", t_branch="", merge_n=0, revision_path="", web_path="", version_level=0, no_time=0):
        if not version_level in [0,1,2]:
            print "ERROR: VersionLevel must be 0,1,2, I'll set it to 0"
            self.VersionLevel=0
        else:
            self.VersionLevel=version_level

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
        self.Recap = ""
        self.Ver = Version(0,0,0,0)
        self.NoTime=no_time
        self.VivadoCommandLine = "vivado -mode batch -notrace -journal {JournalFile} -log {LogFile} -source ./Tcl/launch_runs.tcl -tclargs {Project} {RunsDir} {NJobs} {no_time}"

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
        return self.VivadoCommandLine.format(JournalFile=self.JournalFile(proj), LogFile=self.LogFile(proj), Project=proj, RunsDir=self.RunsDir(proj), NJobs=self.NJobs, no_time=self.NoTime)

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

    def RunsDir(self, proj):
        if self.isToDo(proj):
            return self.RepoPath+"/VivadoProject/{0}/{0}.runs".format(proj)
        else:
            return ""

    def OutDir(self, proj):
        return "{0}/{1}/{2}".format(self.RevisionPath,self.Commit,proj)

    def DoxygenDir(self):
        return "{0}/{1}/doxygen".format(self.RevisionPath,self.Commit)

    def ArchiveDir(self, proj):
        return "{0}/firmware/{1}/{2}".format(self.WebPath,self.Commit,proj)


    def OfficialDir(self, proj):
        return "{0}/official/{1}/{2}".format(self.WebPath,self.Ver.Tag(True),proj)

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
        AtLeastOne=False
        for np in self.Names:
            if OldProjects.Exists(np):
                if OldProjects.Status(np) == self.Status(np):
                    print "[VivadoProjects] Project {0} will not be influenced by this merge, design-flow will be skipped...".format(np)
                    self.State[np] = 'not to do'                                                        
                else:
                    print "[VivadoProjects] Project {0} was at {1} and is now at {2}".format(np, OldProjects.Status(np), self.Status(np))
                    self.SetToDo(np)
                    AtLeastOne=True
            else:
                print "[VivadoProjects] New project found: {0}".format(np)
                self.SetToDo(np)
                AtLeastOne=True
        return AtLeastOne

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

    def StoreBitFile(self, proj, Official=False):
        # Look for bitfile
        if Official:
            DestinationDir = self.OfficialDir(proj)
            bitfiles_dir = self.ArchiveDir(proj)+"/{0}*.bi".format(proj)            
        else:
            DestinationDir = self.ArchiveDir(proj)
            bitfiles_dir = self.OutDir(proj)+"/**/*{0}.bi".format(proj)

        print "[StoreBitFile] Creating archive directory..."
        MakeDir(DestinationDir)
        print "[StoreBitFile] Looking for bitfiles in {}...".format(bitfiles_dir)
        Found = False
        
        for bit_file in glob.iglob(bitfiles_dir+'t'):
            Found = True
            dst=DestinationDir+"/{0}-{1}.bit".format(proj, self.Ver.Tag())
            print "[StoreBitFile] Found bitfile: {0}, moving it to {1}".format(bit_file, dst)
            move(bit_file, dst)
        print "[StoreBitFile] Looking for binfiles..."
        for bin_file in glob.iglob(bitfiles_dir+'n'):
            dst=DestinationDir+"/{0}-{1}.bin".format(proj, self.Ver.Tag())
            print "[StoreBitFile] Found binfile: {0}, moving it to {1}".format(bin_file, dst)
            move(bin_file, dst)
        return Found

    def StoreFiles(self,proj,Official=False):
        if Official:
            DestinationDir = self.OfficialDir(proj)
        else:
            DestinationDir = self.ArchiveDir(proj)

        xml_dir=DestinationDir+'/xml'
        MakeDir(xml_dir)
        copy_tree(self.OutDir(proj)+'/xml', xml_dir)
        rpt_dir = DestinationDir+"/reports"
        MakeDir(rpt_dir)
        for report in glob.iglob(self.OutDir(proj)+'/**/*.rpt'):
            copy_file(report, rpt_dir)
            if 'timing' in report and proj in report:
                with open(report) as f:
                    lines = f.read().splitlines()
                    try:
                        start=lines.index([x for x in lines if "Design Timing Summary" in x][0])
                        titles= re.split('\s\s+', lines[start+4].strip())
                        values= re.split('\s\s+', lines[start+6].strip())
                        timing= ["{0} | {1}".format(t,v) for t,v in zip(titles,values)]
                        timing.insert(0,"- | -")
                        timing.insert(0,"Parameter | Value")
                        timing.append("\n")
                        timing.append(lines[start+9])
                        ret= "\n".join(timing)
                        self.Report[proj] = ret
                    except ValueError:
                        ret = '[StoreFiles] ERROR: could not parse timing report'
                        print ret
                    break
        if not proj in self.Report:
            ret = '[StoreFiles] ERROR: could not find timing report'
            print ret
        return ret


    


    def PrepareRun(self, DryRun=False, Force=False):
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
            return -4
        r.Run("git rev-parse --verify {0}".format(self.TargetBranch))
        if not r.ReturnCode == 0:
            print name+"ERROR: target branch {0} does not exist".format(self.TargetBranch)
            self.RemoveLockFile()
            return -5

        r.Run('git submodule init')
	r.Run('git submodule update')
        if not DryRun:
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
	message="Merging {0} into {1} before automatic wrokflow...".format(self.TargetBranch,self.SourceBranch)
	print name+message
	git_response=r.Run("git merge -m \" {0} \" {1}".format(message,self.TargetBranch))
	if not r.ReturnCode == 0:
	    print name+"ERROR: Problems during merging {0} into {1}, aborting...".format(self.TargetBranch,self.SourceBranch)
            print git_response
            self.RemoveLockFile()
            return -3
	else:
	    print name+"Merge was successful"
	    self.Scan()
            OldVer = Version(0,0,0)
            OldOfficial = Version(0,0,0)
            # gets the previous tag
            OldVer.FromCommit(r.Run('git describe --always --match "[v|b]*" --long --tags')[0])
            # get the previous official tag
            OldOfficial.FromCommit(r.Run('git describe --always --match "v*" --long --tags')[0])
	    print name+"Repository is at {}, last official version is {}".format(OldVer,OldOfficial)            
            # Increase it by the proper Version Level
            OldOfficial.Increase(self.VersionLevel+1)
            if OldVer.isBeta() and not OldVer < OldOfficial:
                self.Ver = OldVer.Increase()
                print name+"This is attempt number {} for this merge request ({}), version will be: {}".format(self.Ver.x[3], self.Ver.mr, self.Ver.Tag())
                if not self.Ver.mr == self.MergeRequestNumber:
                    print name +"WARNING: merge request number mismatch, from repository tag is {} from gitlab webhook is {}, I shall trust gitlab...".format(self.Ver.mr, self.MergeRequestNumber)
                    self.Ver.mr = self.MergeRequestNumber
            else:

                if OldVer < OldOfficial:
                    print name+"Most recent version found {} is smaller than the required official: {}".format(OldVer,OldOfficial)
                    self.Ver = OldOfficial
                else:
                    print name+"Most recent version found is official: {}".format(OldVer)
                    self.Ver = OldVer.Increase(self.VersionLevel+1)
                self.Ver.SetBeta(self.MergeRequestNumber)
            print name+"Tagging version: {}".format(self.Ver.Tag())
            # Can't use lightweight tag, because the annotated ones are always preferred by git
            r.Run('git tag -m "Preliminary version for merge request {} for branch {} to branch {}" {}'.format(self.MergeRequestNumber, self.SourceBranch, self.TargetBranch, self.Ver.Tag()))
	    self.Commit = r.Run('git describe --always --match "b*" --long --tags')[0]
	    print name+"Project is now at {0} on {1}".format(self.Commit,self.SourceBranch)
	    AtLEastOne=self.Compare(OldProj)
	    self.EnableStartRun()
	    print name+"StartRun enabled"
            msg = "Starting automatic workflow for version {}, branch name {}\n\n".format(self.Ver.Tag(), self.SourceBranch)
            self.Recap += "Project | State | Old SHA | new SHA\n"
            self.Recap += "--------|-------|---------|--------\n"
            for n, s in self.State.iteritems():
                self.Recap += "{} | {} | {} | {}\n".format(n,s,OldProj.Status(n), self.Status(n))
                msg = self.CheckXML(n)
                SendNote(msg, self.MergeRequestNumber)                
            msg += self.Recap
            SendNote(msg, self.MergeRequestNumber)

            if AtLEastOne:
                return 0	
            else:
                return 1

    def StartRun(self, DryRun=False):
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
                    if not DryRun:
                        self.runner.RealTime(self.VivadoCommand(Project))
                        wait_time = 30
                    else:
                        wait_time = 2
                        print "[StartRun] WARNING: This is a DRY RUN, will return a successful status"
                        print "[StartRun] Creating dummy bitfiles..."
                        MakeDir(self.ArchiveDir(Project))
                        self.runner.Run("touch {}/impl_1/dummy_{}.bit".format(self.RunsDir(Project),Project))
                        self.runner.ReturnCode = 0
                    print "[StartRun] ***** VIVADO END for {0} *****".format(Project)
                    if self.runner.ReturnCode == 0:
                        ret = VivadoStatus(self.RunsDir(Project), self.StatusFile(Project), wait_time)                    
                        if ret == 0:
                            print "[StartRun] Vivado run was successful for {0} *****".format(Project)
                            self.StoreRun(Project)
                            if self.StoreBitFile(Project):
                                self.State[Project] = 'success'                                                        
                                time_rep = self.StoreFiles(Project)
                                # clean repo?? let's try not to
                                SendNote("## Project: {}\n\nWork-flow was successfull\n\n## Timing report\n\n{}".format(Project, time_rep), self.MergeRequestNumber)
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

    def Finalise(self, DryRun=False):
        RetVal = -1
        if self.CheckRuns():
            print "[CheckRuns] All runs were successful"
            print "[CheckRuns] Running doxigen..."
            self.RunDoxygen()
            RetVal = 0
            if not DryRun:
                self.PushBranch()
            else:
                print "[CheckRuns] This is a DRY RUN, will not push"                
        else:
            print "[CheckRuns] WARNING: Not all runs were successful"
        print "[VivadoProjects] Removing lock file, if any"
        self.RemoveLockFile()
        return RetVal

    def CheckRuns(self):
        AllGood = True
        for proj, state in self.State.iteritems():
            if self.isToDo(proj) and not state == 'success':
                print "[CheckRuns] WARNING: State for project {} is {}".format(proj, state)
                AllGood = False
            else:
                print "[CheckRuns] State for project {} is {}".format(proj, state)
        return AllGood
        
    def PushBranch(self):
        r = Runner()
        r.SetPath(self.RepoPath)
        print "[PushBranch] Pushing source branch: {} after successful workflow...".format(self.SourceBranch)
        r.Run("git push origin {0}".format(self.SourceBranch))
        print "[PushBranch] Pushing tag {}...".format(self.Ver.Tag())
        r.Run("git push origin {0}".format(self.Ver.Tag()))

    def RunDoxygen(self):
        # check that version is >= 1.8.13
        new_ver = self.Ver.Tag(True)
        print "[RunDoxygen] Project version will be set to {}".format(new_ver)
        print "[RunDoxygen] Running doxygen, this may take a while..."
        self.runner.Silent = True;
        DoxygenReport = self.runner.Run('(cat doxygen/doxygen.conf; echo -e "\nPROJECT_NUMBER={}") | doxygen -'.format(new_ver))
        self.runner.Silent = False;
        SendNote("## Doxygen report\n "+"  \n".join(DoxygenReport),self.MergeRequestNumber,False)
        src = self.RepoPath+"/../Doc/html"
        dst = self.DoxygenDir()
        print "[RunDoxygen] Moving {} to {}".format(src,dst)
        move(src,dst)

    def TagMsg(self):
        return "Version: {}".format(self.Ver.Tag(True))

    def TagNote(self):
        note = "# Version: {}\n".format(self.Ver.Tag(True))
        note += "*Source branch:* {}\n\n\n".format(self.SourceBranch)
        note += "*Target branch:* {}\n\n\n".format(self.TargetBranch)
        note += "-------------------\n\n"
        note += self.Recap
        note += "-------------------\n\n"
        for p, r in self.Report.iteritems():
            note += "## {}: timing report\n".format(p)
            note += r
            note += "\n\n-------------------\n\n\n"
        return note
        pass

    def MoveFileOfficial(self):
        for Project in self.ToDo.keys():
            self.StoreBitFile(Project, Official=True)
            self.StoreFiles(Project, Official=True)
        dst=self.WebPath+"/../doc"
        if path.isdir(dst):
            print '[MoveFileOfficial] Deleting doxygen directory {}...'.format(dst)
            rmtree(dst)
        print '[MoveFileOfficial] Copying doxygen documentation from {} to {}...'.format(self.DoxygenDir(), dst)
        self.runner.Run("cp -r {} {}".format(self.DoxygenDir(), dst))


    def XML(self, proj):
        ret = []
        for xml in glob.iglob(self.Path(proj)+'/xml/*.xml'):
            ret.append(xml)
        return ret        

    def AddressTables(self):
        ret = []
        for vhdl in glob.iglob(self.RepoPath+'/**/address_table/*.vhd'):
            ret.append(vhdl)
        return ret

    def CheckXML(self, proj):
        addr_table = self.AddressTables()
        RetVals = ""
        for xml in self.XML(proj):
            basename = path.basename(xml)
            Path =  path.dirname(xml)
            name, ext = path.splitext(basename)
            vhdl = "ipbus_decode_" + name + ".vhd"
            match = [x for x in addr_table if vhdl in x]
            if len(match) == 1:
                old_vhdl = match[0]
                print "[CheckXML] Comparing {} with {}...".format(xml,old_vhdl)
                self.runner.Run("gen_ipbus_addr_decode {}".format(xml))

                if Compare(self.runner.Path+"/"+vhdl, old_vhdl):
                    RetVal =  "Files {} and {} match".format(xml,old_vhdl)
                    print "[CheckXML] "+ RetVal
                else:
                    print "[CheckXML] Files do not match"
                    RetVal = "  \n".join(self.runner.Run("diff {} {}".format(vhdl,old_vhdl)))
                    RetVal = "Address file generated from {} differs from {} \n\n ------------------------------- \n\n".format(xml,old_vhdl) + RetVal
                remove(self.runner.Path+"/"+vhdl)
                
            elif len(match) == 0:
                RetVal = "File {} - corresponding to {} - was not found".format(vhdl,xml)
                print "[CheckXML] WARNING: "+ RetVal 
            elif len(match) > 1:
                RetVal = "More than one file correspond to {}".format(xml)
                print "[CheckXML] WARNING: "+ RetVal 
            RetVals = RetVals + RetVal + "\n\n"
        return "## XML files report for project {} \n\n".format(proj) + RetVals

###################################################
