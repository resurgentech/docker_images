import subprocess
import sys
import datetime


def seconds_from_epoch():
    dto = datetime.datetime.utcnow()
    dt = dto.timestamp()
    ts = int(dt)
    return ts


def run_cmd(cmd, allow_errors=False, verbose=False, live_output=False):
    """
    run a command in the shell

    :param cmd: string with command to run in shell
    :param allow_errors: don't fail
    :param verbose: print stuff
    :param live_output: print data to stdout from process as you go
    :return: exitcode, stdout, stderr
    """
    aout = []
    aerr = []
    with subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=1, universal_newlines=True) as p:
        for line in p.stdout:
            if live_output:
                print(line, end='')
                sys.stdout.flush()
            aout.append(line)
        for line in p.stderr:
            if live_output:
                print(line, end='')
                sys.stdout.flush()
            aerr.append(line)
    exitcode = p.returncode
    out = "".join(aout)
    err = "".join(aerr)
    if verbose:
        print("cmd: {}".format(cmd))
    if verbose and not live_output:
        print("stdout: {}".format(out))
        print("stderr: {}".format(err))
    if verbose:
        print("exitcode: {}".format(exitcode))
        print("")
    if allow_errors is False and exitcode != 0:
        if not verbose:
            print("cmd: {}".format(cmd))
            print("stdout: {}".format(out))
            print("stderr: {}".format(err))
            print("exitcode: {}".format(exitcode))
            print("")
        raise
    sys.stdout.flush()
    return exitcode, out, err
