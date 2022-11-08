from docker_image_tools.docker import *
from docker_image_tools.git import *
import yaml
import os


def metadata_read_file_image(org, imagename):
    cmd = "cat /etc/docker_image_history.{}.yaml".format(org)
    exitcode, out, _ = docker_run(cmd, imagename)
    if exitcode != 0:
        return None
    metadata = yaml.safe_load(out)
    return metadata


def metadata_write_file(metadata, workdir, org):
    path = os.path.join(workdir, "docker_image_history.{}.yaml".format(org))
    with open(path, 'w') as file:
        yaml.dump(metadata, file)


def metadata_make_for_baseimage(org, baseimage):
    metadata = metadata_read_file_image(org, baseimage)
    if metadata is None:
        metadata = [{}]
    docker_metadata = docker_image_inspect_metadata(baseimage)
    image_metadata = metadata[-1]
    for k, v in docker_metadata.items():
        if image_metadata.get(k, None) is not None:
            continue
        image_metadata[k] = v
    return metadata


def metadata_create(workdir, org, baseimage, imagename):
    metadata = metadata_make_for_baseimage(org, baseimage)
    new_image = {}
    new_image['imagename'] = imagename
    new_image['git_url'] = git_url()
    new_image['git_hash'] = git_short_hash()
    metadata.append(new_image)
    metadata_write_file(metadata, workdir, org)


def metadata_image_tag(ts):
    hash = git_short_hash()
    tag = "{}-{}".format(ts, hash)
    return tag


def metadata_image_repo(org, container_name, os_name):
    repo = "{}/{}-{}".format(org, container_name, os_name)
    return repo


def metadata_imagename(org, container_name, os_name, ts):
    tag = metadata_image_tag(ts)
    repo = metadata_image_repo(org, container_name, os_name)
    imagename = "{}:{}".format(repo, tag)
    return imagename
