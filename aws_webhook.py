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
        print "[aws_webhook] --------------------------------"
        print "[aws_webhook] MERGE REQUEST RECEIVED:"
        print "[aws_webhook] --------------------------------"
        print "[aws_webhook] Merge request N:     ", n
        print "[aws_webhook] Source branch:       ", sb 
        print "[aws_webhook] Target branch:       ", tb 
        print "[aws_webhook] State:               ", state 
        print "[aws_webhook] Work in progress:    ", wip 
        print "[aws_webhook] Title:               ", title 
        print "[aws_webhook] Description:         ", description 
        print "[aws_webhook] Last commit author:  ", last_commit_author 
        print "[aws_webhook] Action:              ", action
        time.sleep(1)
        u = requests.get(url, headers=head)
        time.sleep(1)
        r = requests.get("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}".format(n), headers=head)
        data_web=json.loads(r.text)
        status=data_web['merge_status']
        print "[aws_webhook] Merge status:        ", status 
        print "[aws_webhook] --------------------------------"
        sys.stdout.flush()
        if self.Verbose:
            pprint(data_web)
        if status == 'can_be_merged' and tb == 'master' and state == 'opened' and last_commit_author != 'efex' and action != 'approved' and not wip and not 'TEST_MERGE' in description:
            if 'DRYRUN' in description:
                DryRun=True
                print "[aws_webhook] This is a DRY RUN"
            else:
                DryRun=False
            if 'MINOR_VERSION' in title:
                VersionLevel = 1
                print "[aws_webhook] This is a minor version release candidate x.y.z will become x.(y+1).0..."                
            elif 'MAJOR_VERSION' in title:
                VersionLevel = 2
                print "[aws_webhook] This is a major version release candidate x.y.z will become (x+1).0.0..."                
            else:
                VersionLevel = 0

            thread = Thread(target = StartWorkflow, args = (sb,tb,n, VersionLevel, DryRun))
            thread.start()


        elif (tb == 'master' and state == 'merged' and not wip) or 'TEST_MERGE' in description:
            print "[aws_webhook] Merge request was merged. Tagging new official version..."
            f_name = AWS_FILE.format(n)
            print "[aws_webhook] Open aws file {}...".format(f_name)
            f = open (f_name, 'r')
            Run = pickle.load(f)
            f.close()
            old_tag = Run.Ver.Tag()
            Run.Ver.SetAlpha()
            new_tag = Run.Ver.Tag()
            print "[aws_webhook] New tag is {}".format(new_tag)
            tag_msg = ""
            tag_note = "##Note:\n this is the release note  \n in markup *format*"
            ret=  aws.NewTag(new_tag, old_tag, Run.TagMsg(), Run.TagNote())
            if ret == 201:
                print "[aws_webhook] New tag created successfully"
            else:
                print "[aws_webhook] WARNING: error creating new tag ({})".format(ret)
            Run.MoveFileOfficial()
            #run doxygen
            # Run.Doxygen()
            print "[aws_webhook] All done."
        return 'OK'

def StartWorkflow(sb,tb,n,v_level=0,DryRun=False):
    print "[aws_webhook] *******************************************"
    print "[aws_webhook] Launching run for merge request {0}".format(n)
    print "[aws_webhook] From: {0}   To: {1}".format(sb,tb)
    print "[aws_webhook] *******************************************"
    sys.stdout.flush()
    aws.SendNote('This merge request matches all the required criteria, I shall launch the automatic work flow now.', n)
    Run = aws.VivadoProjects(REPO_PATH, sb, tb, n, REVISION_PATH, WEB_PATH, v_level)
    prep = Run.PrepareRun(DryRun=DryRun)
    if prep >= 0:
        if prep == 1:
            aws.SendNote('This merge request does not modify any file that is revelant for any of the projects, so I shall approve it.', n)
        else:
            Run.StartRun(DryRun=DryRun)
            final=Run.Finalise(DryRun=DryRun)
            if final == 0:
                aws.SendNote('The automatic design flow was successful, so I shall approve this merge reqest.', n)
                approve = requests.post("https://gitlab.cern.ch/api/v4/projects/atlas-l1calo-efex%2FeFEXFirmware/merge_requests/{0}/approve".format(n), headers=head)
                f_name = AWS_FILE.format(n)
                print "[aws_webhook] Writing run into aws file {}...".format(f_name)
                f = open (f_name, 'w')
                pickle.dump(Run, f)
                f.close()
            else:
                aws.SendNote('The automatic design flow has failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    else:
        print "[aws_webhook] Auto launch run preparation returned value {0}".format(prep)
        aws.SendNote('The automatic design flow preparation has failed, so I am afraid I shall not be able to approve this merge reqest.', n)
    print "[aws_webhook] All done."
    sys.stdout.flush()
        

if __name__ == '__main__':
    head ={'PRIVATE-TOKEN': 'CbWF_XrjGbEGMssj9fkZ'}
    urls = ('/.*', 'hooks')
    app = web.application(urls, globals())
    session = web.session.Session(app, web.session.DiskStore('/home/efex/sessions'))
    print "[aws_webhook] AWS WebHook started, waiting for merge requests."
    app.run()
