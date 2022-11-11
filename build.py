#!/usr/bin/python3
import sys
import shutil
import jinja2
from docker_image_tools import *


def read_config(args):
    success = True
    with open(args.config, 'r') as file:
        rawconfig = yaml.load(file, Loader=yaml.FullLoader)
    config = []

    # Check for basic sections in config file
    for a in ['ansible', 'distros', 'templates']:
        if rawconfig.get(a, None) is None:
            success = False
            print("Config file '{}' is missing '{}'".format(args.config, a))
    if rawconfig.get('templates', {}).get('distros', None) is None:
        print("Config file '{}' is missing 'distros' in 'templates'".format(args.config))
    if not success:
        sys.exit(1)

    # Merge in templates and update the containers
    default_ansible = rawconfig['ansible']
    distro_templates = rawconfig['templates']['distros']
    for distro_name, distro_data in rawconfig['distros'].items():
        # Skip out when we specify distro
        if args.distro is not None:
            if args.distro != distro_name:
                continue
        a = {}
        a['name'] = distro_name
        # Figure out template
        if distro_data.get('template', None) is None:
            template = {}
        else:
            template_name = distro_data['template']
            template = distro_templates.get(template_name, {})
        # First merge in stuff from your template, if any
        for k,v in template.items():
            a[k] = json.loads(json.dumps(v))
        # Second merge in stuff from the distro to override or add
        for k,v in distro_data.items():
            # Filter out stuff that are just for templating
            if k in ['template', 'root_image']:
                continue
            a[k] = json.loads(json.dumps(v))
        # Reconcile container images
        if a.get('containers', None) is None:
            print("Skipping distro '{}' in config file '{}' is missing 'containers'".format(distro_name, args.config))
            continue
        for i, container_name in enumerate(a['containers']):
            container_data = a['containers'][container_name]
            # Base container is a special case where we specify it's base_image upfront
            if container_data.get('base_image', None) is not None:
                if container_data['base_image'] == 'root_image':
                    if distro_data.get('root_image', None) is not None:
                        container_data['base_image'] = distro_data['root_image']
            else:
                # These other containers just build on the previous
                container_names = list(a['containers'].keys())
                last_container_name = container_names[i-1]
                container_data['base_image'] = "{}/{}-{}:latest".format(args.org, last_container_name, distro_name)
            container_data['image'] = "{}/{}-{}".format(args.org, container_name, distro_name)
            # Adding ansible_url
            if container_data.get('ansible', None) is None:
                container_data['ansible'] = json.loads(json.dumps(default_ansible))
        for container_name in list(a['containers'].keys()):
            # Skip out when we specify container
            if args.container is not None:
                if args.container != container_name:
                    del a['containers'][container_name]
                    continue

        config.append(a)
    return config


def create_dockerfile(build_dir, template_path, data):
    shutil.rmtree(build_dir, ignore_errors=True)
    os.makedirs(build_dir)
    file_loader = jinja2.FileSystemLoader(template_path)
    env = jinja2.Environment(loader=file_loader)
    template = env.get_template(data['template'])
    output = template.render(data)
    dockerfile = os.path.join(build_dir, 'Dockerfile')
    with open(dockerfile, 'w') as file:
        file.write(output)


if __name__ == '__main__':
    # Make sure we know what our working dir is
    path = os.path.realpath(os.path.dirname(__file__))
    template_path = os.path.join(path, 'templates', 'Dockerfiles')
    build_dir = os.path.join(path, 'build')
    os.chdir(path)

    # Process command line
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', help='Config file', default='config.yaml', type=str)
    parser.add_argument('--container', help='Container type', type=str)
    parser.add_argument('--distro', help='os version to build', type=str)
    parser.add_argument('--clean', help='remove images locally', action='store_true')
    parser.add_argument('--no_push', help='Do not push images', action='store_true')
    parser.add_argument('--org', help='organization', type=str, default='resurgentech')
    args = parser.parse_args()

    # Create list of targeted container types
    distros = read_config(args)
    print(yaml.dump(distros))

    # Clean up images
    if args.clean:
        print("****Cleaning Images****")
        for distro in distros:
            containers = dict(distro['containers'].items())
            distro_name = distro['name']
            for container_data in reversed(containers.values()):
                image = container_data['image']
                docker_clean_images(image)
        sys.exit(0)

    # Do build
    print("****Building Images****")
    for distro in distros:
        for container_name, container_data in distro['containers'].items():
            # Get latest base image
            baseimage = container_data['base_image']
            image = container_data['image']
            docker_pull(baseimage)

            # make Dockerfile
            create_dockerfile(build_dir, template_path, container_data)

            # build actual image
            tag = metadata_image_tag(seconds_from_epoch())
            fullimage = "{}:{}".format(image, tag)
            metadata_create(build_dir, args.org, baseimage, fullimage)
            start_images = docker_get_all_images()
            docker_build(build_dir, fullimage)

            # tag as latest
            docker_tag(image, tag, 'latest')

            # Push
            if not args.no_push:
                docker_push_images(image)
            docker_cleanup_images(start_images)

