from docker_image_tools.common import *


def git_url():
    cmd = "git config --get remote.origin.url"
    _, out, _ = run_cmd(cmd, verbose=False, live_output=False)
    url = out.strip()
    return url


def git_short_hash():
    cmd = "git rev-parse --short HEAD"
    _, out, _ = run_cmd(cmd)
    hash = out.strip()
    cmd = "git diff --shortstat 2> /dev/null | tail -n1"
    _, out2, _ = run_cmd(cmd)
    if out2.strip() != "":
        hash = "{}_dirty".format(hash)
    return hash
