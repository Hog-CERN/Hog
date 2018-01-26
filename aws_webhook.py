#!/usr/bin/python
import web
import json
import os
import sys
import requests
import time
from pprint import pprint
from threading import Thread

class hooks:
    def __init__(self):
        self.verbose = False

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
        if self.verbose:
            pprint(data_web)
        if status == 'can_be_merged' and tb == 'master' and state == 'opened' and last_commit_author != 'efex' and action != 'approved' and not wip:
            thread = Thread(target = StartWorkflow, args = (sb,tb,n))
            thread.start()
        return 'OK'

def StartWorkflow(sb,tb,n):
    print "*******************************************"
    print "Launching run for merge request {0}".format(n)
    print "From: {0}   To: {1}".format(sb,tb)
    print "*******************************************"
    sys.stdout.flush()
    REPO_PATH= '/home/efex/eFEXTest' #'/home/efex/eFEXTest'
    REVISION_PATH= '/home/efex/test' #'/mnt/vd/eFEX-revision'                                                        
    WEB_PATH= '/eos/user/e/efex/www/test' #'/eos/user/e/efex/www/revision'                               
    aws.SendNote('This merge request matches all the required criteria, I shall launch the automatic work flow now.', n)
    Run = aws.VivadoProjects(REPO_PATH, sb, tb, n, REVISION_PATH, WEB_PATH)
    Run.PrepareRun()
    # Send note with projects                                                                                                  
    val= Run.StartRun()
    if val < 2:
        if val == 1:
            aws.SendNote('This merge request does not modify any file that is revelant for any of the projects, so I shall approve it', n)
        else:
            aws.SendNote('The automatic design flow was successful, so I shall approve this merge reqest', n)
        approve = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/approve".format(n), headers=head)
    else:
        print "Auto launch run returned value {0}".format(val)
        aws.SendNote('The automatic design flow have failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    sys.stdout.flush()
        
if __name__ == '__main__':
    head ={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'}
    urls = ('/.*', 'hooks')
    app = web.application(urls, globals())
    session = web.session.Session(app, web.session.DiskStore('/home/efex/sessions'))
    app.run()
