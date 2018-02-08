#!/usr/bin/python
import web, json, os, sys, requests, time, pickle
import aws
from pprint import pprint
from threading import Thread

REPO_PATH= '/home/efex/eFEXFirmware'
REVISION_PATH= '/mnt/vd/eFEX-revision'                                                        
WEB_PATH= '/eos/user/e/efex/www/revision'                               
AWS_FILE = REVISION_PATH+'/merge_request{}.aws'

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
        print
        print 'MERGE REQUEST RECEIVED:'
        print "--------------------------------"
        print
        print "Merge request N:     ", n
        print "Source branch:       ", sb 
        print "Target branch:       ", tb 
        print "State:               ", state 
        print "Work in progress:    ", wip 
        print "Title:               ", title 
        print "Description:         ", description 
        print "Last commit author:  ", last_commit_author 
        print "Action:              ", action
        time.sleep(1)
        u = requests.get(url, headers=head)
        time.sleep(1)
        r = requests.get("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}".format(n), headers=head)
        data_web=json.loads(r.text)
        status=data_web['merge_status']
        print "Merge status:        ", status 
        print "--------------------------------"
        sys.stdout.flush()
        if self.Verbose:
            pprint(data_web)
        if status == 'can_be_merged' and tb == 'master' and state == 'opened' and last_commit_author != 'efex' and action != 'approved' and not wip:
            if 'DRYRUN' in description:
                DryRun = True
            else:
                DryRun=False
            VersionLevel = 0
            thread = Thread(target = StartWorkflow, args = (sb,tb,n, VersionLevel, DryRun))
            thread.start()
        elif tb == 'master' and state == 'merged' and not wip:
            print "Tagging new official version..."
            f_name = AWS_FILE.format(n)
            print "Open aws file {}...".format(f_name)
            f = open (f_name, 'w')
            Run = pickle.load(f)
            f.close()
            old_tag = Run.Ver.Tag()
            Run.Ver.SetAlpha()
            new_tag = Run.Ver.Tag()
            aws.NewTag(old_tag, new_tag, "this is the tag message", "this is the release note")
            #move file and folders in official path
            #run doxygen

        return 'OK'

def StartWorkflow(sb,tb,n,v_level=0,DryRun=False):
    print "*******************************************"
    print "Launching run for merge request {0}".format(n)
    print "From: {0}   To: {1}".format(sb,tb)
    print "*******************************************"
    sys.stdout.flush()
    aws.SendNote('This merge request matches all the required criteria, I shall launch the automatic work flow now.', n)
    Run = aws.VivadoProjects(REPO_PATH, sb, tb, n, REVISION_PATH, WEB_PATH, v_level)
    prep = Run.PrepareRun()
    if prep >= 0:
        if prep == 1:
            aws.SendNote('This merge request does not modify any file that is revelant for any of the projects, so I shall approve it.', n)
        else:
            Run.StartRun()
            final=Run.Finalise()
            if final == 0:
                aws.SendNote('The automatic design flow was successful, so I shall approve this merge reqest.', n)
                approve = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/approve".format(n), headers=head)
                f_name = AWS_FILE.format(n)
                print "Writing run into aws file {}...".format(f_name)
                f = open (f_name, 'w')
                pickle.dump(Run, f)
                f.close()
            else:
                aws.SendNote('The automatic design flow has failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    else:
        print "Auto launch run preparation returned value {0}".format(prep)
        aws.SendNote('The automatic design flow preparation has failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    sys.stdout.flush()
        

if __name__ == '__main__':
    head ={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'}
    urls = ('/.*', 'hooks')
    app = web.application(urls, globals())
    session = web.session.Session(app, web.session.DiskStore('/home/efex/sessions'))
    app.run()
