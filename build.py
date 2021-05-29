#!/usr/bin/python3
from docker_image_tools import *


if __name__ == '__main__':
    # Make sure we know what our working dir is
    path = os.path.realpath(os.path.dirname(__file__))
    os.chdir(path)

    # Process command line
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--container', help='Container type', type=str)
    parser.add_argument('--os_name', help='os version to build', type=str)
    parser.add_argument('--push', help='push images to hub.docker.com', type=str)
    parser.add_argument('--clean', help='remove images locally', action='store_true')
    parser.add_argument('--tag', help='tag version', type=str)
    parser.add_argument('--org', help='organization', type=str, default='resurgentech')
    args = parser.parse_args()


    # Create list of targeted container types
    dfd = DockerfileDiscovery(org=args.org, container=args.container, os_name=args.os_name)

    # Clean up images
    if args.clean:
        dfd.reverse_deps = True
        for container_name, os_name in dfd:
            print("container_name='{}' os_name='{}".format(container_name, os_name))
            repo = metadata_image_repo(args.org, container_name, os_name)
            dfd.clean(repo)
        sys.exit(0)

    # Do push actions if request
    if args.push is not None:
        if args.tag is not None:
            docker_push(args.tag)
            sys.exit(0)
        for container_name, os_name in dfd:
            repo = metadata_image_repo(args.org, container_name, os_name)
            dfd.push(repo)
        sys.exit(0)

    # Do build
    for container_name, os_name in dfd:
        # update base image
        dfd.pull_base_image(container_name, os_name, allow_errors=True)

        repo = metadata_image_repo(args.org, container_name, os_name)
        ts = seconds_from_epoch()
        tag = metadata_image_tag(ts)

        # build actual image
        dfd.build(container_name, os_name, repo, tag)

        # tag as latest
        docker_tag(repo, tag, 'latest')
