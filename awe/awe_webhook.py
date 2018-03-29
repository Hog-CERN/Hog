#!/usr/bin/python
import web, json, os, sys, requests, time, pickle, ConfigParser, urllib
import awe
from pprint import pprint
from threading import Thread

REPO_PATH= '/home/efex/eFEXFirmware'
REVISION_PATH= '/mnt/vd/eFEX-revision'                                                        
WEB_PATH= '/eos/user/e/efex/www/revision'                               
REPO_NAME='atlas-l1calo-efex%2FeFEXFirmware'
USERNAME='efex'

class hooks:
    def __init__(self):
        self.Verbose = False

    def POST(self):
        data = json.loads(web.data())
        if self.Verbose:
            pprint(data)
        sb=data['object_attributes']['source_branch']
        tb=data['object_attributes']['target_branch']
        state=data['object_attributes']['state']
        wip=data['object_attributes']['work_in_progress']        
        description=data['object_attributes']['description']
        title=data['object_attributes']['title']
        n=data['object_attributes']['iid']
        url=data['object_attributes']['url']
        last_commit_author=data['object_attributes']['last_commit']['author']['name']
        action=data['object_attributes']['action']
        print "[awe_webhook] --------------------------------"
        print "[awe_webhook] MERGE REQUEST RECEIVED:"
        print "[awe_webhook] --------------------------------"
        print "[awe_webhook] Merge request N:     ", n
        print "[awe_webhook] Source branch:       ", sb 
        print "[awe_webhook] Target branch:       ", tb 
        print "[awe_webhook] State:               ", state 
        print "[awe_webhook] Work in progress:    ", wip 
        print "[awe_webhook] Title:               ", title 
        print "[awe_webhook] Description:         ", description 
        print "[awe_webhook] Last commit author:  ", last_commit_author 
        print "[awe_webhook] Action:              ", action
        time.sleep(1)
        u = requests.get(url, headers=head)
        time.sleep(1)
        r = requests.get("https://gitlab.cern.ch/api/v4/projects/{}/merge_requests/{}".format(RepoAddress,n), headers=head)
        data_web=json.loads(r.text)
        status=data_web['merge_status']
        print "[awe_webhook] Merge status:        ", status 
        print "[awe_webhook] --------------------------------"
        sys.stdout.flush()
        if self.Verbose:
            pprint(data_web)
        if status == 'can_be_merged' and tb == 'master' and state == 'opened' and last_commit_author != USERNAME and action != 'approved' and not wip and not 'TEST_MERGE' in description:
            if 'DRYRUN' in description:
                DryRun=True
                print "[awe_webhook] This is a DRY RUN"
            else:
                DryRun=False

            if 'NO_TIME' in description:
                NoTime=1
                print "[awe_webhook] Time and date will not be added to firmware registers"
            else:
                NoTime=0

            if 'MINOR_VERSION' in title:
                VersionLevel = 1
                print "[awe_webhook] This is a minor version release candidate x.y.z will become x.(y+1).0 ..."                
            elif 'MAJOR_VERSION' in title:
                VersionLevel = 2
                print "[awe_webhook] This is a major version release candidate x.y.z will become (x+1).0.0 ..."                
            else:
                VersionLevel = 0

            thread = Thread(target = StartWorkflow, args = (sb,tb,n, VersionLevel, DryRun, NoTime))
            thread.start()


        elif (tb == 'master' and state == 'merged' and not wip) or 'TEST_MERGE' in description:
            print "[awe_webhook] Merge request was merged. Tagging new official version..."
            sys.stdout.flush()
            f_name = AweFile.format(n)
            print "[awe_webhook] Open awe file {}...".format(f_name)
            f = open (f_name, 'r')
            Run = pickle.load(f)
            f.close()
            old_tag = Run.Ver.Tag()
            new_tag = Run.Ver.Tag(True)
            print "[awe_webhook] New tag is {}".format(new_tag)
            sys.stdout.flush()
            tag_msg = ""
            tag_note = "##Note:\n this is the release note  \n in markup *format*"
            ret=  awe.NewTag(new_tag, old_tag, Run.TagMsg(), Run.TagNote())
            if ret == 201:
                print "[awe_webhook] New tag created successfully"
            else:
                print "[awe_webhook] WARNING: error creating new tag ({})".format(ret)
            Run.MoveFileOfficial()
            print "[awe_webhook] All done."
            sys.stdout.flush()
        return 'OK'

def StartWorkflow(sb,tb,n,v_level=0,DryRun=False,NoTime=0):
    print "[awe_webhook] *******************************************"
    print "[awe_webhook] Launching run for merge request {0}".format(n)
    print "[awe_webhook] From: {0}   To: {1}".format(sb,tb)
    print "[awe_webhook] *******************************************"
    sys.stdout.flush()
    awe.SendNote('This merge request matches all the required criteria, I shall launch the automatic work flow now.', n)
    Run = awe.VivadoProjects(REPO_PATH, sb, tb, n, REVISION_PATH, WEB_PATH, v_level, NoTime)
    prep = Run.PrepareRun(DryRun=DryRun)
    if prep >= 0:
        if prep == 1:
            awe.SendNote('This merge request does not modify any file that is revelant for any of the projects, so I shall approve it.', n)
        else:
            Run.StartRun(DryRun=DryRun)
            final=Run.Finalise(DryRun=DryRun)
            if final == 0:
                awe.SendNote('The automatic design flow was successful, so I shall approve this merge reqest.', n)
                approve = requests.post("https://gitlab.cern.ch/api/v4/projects/{}/merge_requests/{0}/approve".format(RepoAddress,n), headers=head)
                f_name = AweFile.format(n)
                print "[awe_webhook] Writing run into awe file {}...".format(f_name)
                f = open (f_name, 'w')
                pickle.dump(Run, f)
                f.close()
            else:
                awe.SendNote('The automatic design flow has failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    else:
        print "[awe_webhook] Auto launch run preparation returned value {0}".format(prep)
        awe.SendNote('The automatic design flow preparation has failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    print "[awe_webhook] All done."
    sys.stdout.flush()
        

if __name__ == '__main__':
    ConfigFile = "/etc/awe-{}.conf".format(sys.argv[1])
    Port = 8000

    head ={'PRIVATE-TOKEN': awe.GetPrivateToken()}
    urls = ('/.*', 'hooks')
    RepoAddress = urllib.quote_plus(REPO_NAME)
    AweFile = REVISION_PATH+'/merge_request{}.awe'
    app = web.application(urls, port=Port)
    session = web.session.Session(app, web.session.DiskStore('/home/{}/sessions'.format(USERNAME)))

    print "[awe_webhook] AWE WebHook started"
    print "[awe_webhook] Reading config file {}...".format(ConfigFile)                                  
    config = ConfigParser.RawConfigParser()
    config.optionxform = str #make it case sensitive
    AweConfiguration = {}
    for s in config.items('awe'):
        AweConfiguration[s[0]] =  s[1]

    REPO_PATH=AweConfiguration['RepositoryPath']
    REVISION_PATH=AweConfiguration['RevisionPath']
    WEB_PATH=AweConfiguration['WebPath']
    REPO_NAME=AweConfiguration['Repository']
    USERNAME=AweConfiguration['Username']
    
    print "[awe_webhook] Configuration: {}".format(AweConfiguration)    
    print "[awe_webhook] Waiting for merge requests on port {}...".format(Port)

    sys.stdout.flush()
    app.run()
