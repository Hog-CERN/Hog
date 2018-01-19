#!/usr/bin/python
import subprocess
from shutil import move, copy2 as copy


def Run(command, path='.', verbose=False):
    if verbose:
        print "Running: '", command, "' From: '", path, "'"
    cmd = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, cwd=path)
    return [x.rstrip() for x in list(cmd.stdout)]

#print Run("git log --format=%h -1 -- $(awk '!/^ *#/ && NF {print $1}' ./list/*) .")[0]
#print Run("ls", "./list")

def SendMail(txt, subject, address):
    Run("echo \"{0}\" | mail -s \"{1}\" {2}".format(txt, subject,address))

print Run("ls")
