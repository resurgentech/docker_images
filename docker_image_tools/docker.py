from docker_image_tools.common import *
import json


def docker_run(cmd, imagename):
    cmdline = "docker run -it --rm {} {}".format(imagename, cmd)
    exitcode, out, err = run_cmd(cmdline, allow_errors=True, verbose=True, live_output=True)
    return exitcode, out, err


def docker_build(workdir, dockerfile, imagename):
    cmd = "cd {}; docker build -f {} . --tag {}".format(workdir, dockerfile, imagename)
    run_cmd(cmd, verbose=True, live_output=True)


def docker_pull(imagename, allow_errors=False):
    cmd = "docker pull {}".format(imagename)
    run_cmd(cmd, allow_errors=allow_errors, verbose=True, live_output=True)


def docker_push(imagename):
    cmd = "docker push {}".format(imagename)
    run_cmd(cmd, verbose=True, live_output=True)


def docker_tag(repo, src, dst):
    cmd = "docker tag {}:{} {}:{}".format(repo, src, repo, dst)
    run_cmd(cmd, verbose=True, live_output=False)


def docker_image_inspect(imagename):
    cmd = "docker image inspect {}".format(imagename)
    _, out, _ = run_cmd(cmd, verbose=False, live_output=False)
    image_metadata = json.loads(out)
    return image_metadata


def docker_image_inspect_metadata(imagename):
    image_metadata = docker_image_inspect(imagename)
    output = {}
    output['imagename'] = imagename
    for k in ['Id', 'Created', 'Size', 'RepoTags']:
        try:
            output[k] = image_metadata[0][k]
            if k == 'Id':
                output[k] = output[k].split(":")[1]
        except:
            print("Can't find '{}' in '{}'".format(k, imagename))
    return output


def dockerfile_get_base_image(path):
    baseimage = None
    with open(path, "r") as file:
        dockerfile = file.readlines()
    for line in dockerfile:
        if line.find('FROM') == 0:
            output = line.replace('FROM ', '')
            baseimage = output.lstrip().rstrip()
            break
    return baseimage


def docker_get_images(repo):
    cmd = "docker images -a"
    _, out, _ = run_cmd(cmd, verbose=False, live_output=False)
    images = []
    lines = out.splitlines()
    line = lines.pop(0)
    headers = line.split()
    for line in lines:
        a = line.split()
        b = {}
        for i in range(3):
            h = headers[i]
            b[h] = a[i]
        if b['REPOSITORY'] == repo:
            images.append(b)
    return images


def docker_delete_image(image):
    cmd = "docker image rm -f {}".format(image)
    run_cmd(cmd, verbose=False, live_output=False, allow_errors=True)
