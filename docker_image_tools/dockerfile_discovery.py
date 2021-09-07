from docker_image_tools.metadata import *


def get_by_name(data_list, key_name, name):
    for d in data_list:
        if d[key_name] == name:
            return d
    return None


class DockerfileDiscovery:
    def __init__(self, org=None, container=None, os_name=None, searchdir="./containers"):
        self.org = org
        self.data = self.discover_all(searchdir)
        self.discover_resolve_dependants()
        self.jobs = []
        self.reverse_deps = False
        self.filter_failure = self.filter_data(container, os_name)

    def filter_data(self, container_name, os_name):
        if container_name is not None:
            tempdata = []
            container = self.get_container(container_name)
            if container is None:
                print("ERROR: Can't find container {}".format(container_name))
                return True
            tempdata.append(container)
            self.data = tempdata
        if os_name is not None:
            is_os_name_missing = True
            for c in self.data:
                df = self.get_dockerfile(c['name'], os_name)
                if df is not None:
                    is_os_name_missing = False
                c['dockerfiles'] = [df]
            if is_os_name_missing:
                print("ERROR: Can't find OS named {} in container {}".format(os_name, container_name))
                return True
        return False

    def setup_jobs(self):
        for c in self.data:
            nc = {}
            for k, v in c.items():
                if k == 'dockerfiles':
                    continue
                nc[k] = v
            nc['dockerfiles'] = self.get_dockerfiles(c['name'])
            self.jobs.append(nc)

    def delete_dockerfile_from_jobs(self, container_name, os_name):
        tempjobs = []
        for c in self.jobs:
            if c['name'] != container_name:
                tempjobs.append(c)
                continue
            tempdf = []
            for df in c['dockerfiles']:
                if df['os_name'] == os_name:
                    continue
                tempdf.append(df)
            if len(tempdf) == 0:
                continue
            c['dockerfiles'] = tempdf
            tempjobs.append(c)
        self.jobs = tempjobs

    def discover_add_dockerfiles(self, container):
        container['dockerfiles'] = []
        files = [f.path for f in os.scandir(container['path']) if f.is_file()]
        for file_path in files:
            file_entry = {}
            a = os.path.basename(file_path).split('.')
            if len(a) < 2:
                continue
            if a[0] != 'Dockerfile':
                continue
            file_entry['os_name'] = a[1]
            file_entry['path'] = file_path
            container['dockerfiles'].append(file_entry)

    def discover_add_dependancies(self, container):
        dir = container['path']
        path = os.path.join(dir, 'deps.yaml')
        if not os.path.isfile(path):
            return
        with open(path, 'r') as file:
            deps = yaml.load(file, Loader=yaml.FullLoader)
        for df in container['dockerfiles']:
            for dep in deps:
                if df['os_name'] == dep['os_name']:
                    df['depends'] = dep['depends']

    def discover_all(self, searchdir):
        subfolders = [f.path for f in os.scandir(searchdir) if f.is_dir()]
        containers = []
        for d in subfolders:
            container = {}
            container['name'] = os.path.basename(d)
            container['path'] = d
            self.discover_add_dockerfiles(container)
            self.discover_add_dependancies(container)
            containers.append(container)
        return containers

    def discover_resolve_dependants(self):
        for container_name in self.get_container_names():
            for os_name in self.get_dockerfile_names(container_name):
                df = self.get_dockerfile(container_name, os_name)
                if df.get('depends', None) is None:
                    continue
                container_we_depend_on = df['depends']
                parent_df = self.get_dockerfile(container_we_depend_on, os_name)
                parent_df['dependant'] = container_name

    def build(self, container_name, os_name, repo, tag):
        imagename = "{}:{}".format(repo, tag)
        workdir = self.get_container_path(container_name)
        dockerfile_name = self.get_dockerfile_filename(container_name, os_name)
        dockerfile_path = self.get_dockerfile_path(container_name, os_name)
        metadata_create(workdir, self.org, dockerfile_path, imagename)
        docker_build(workdir, dockerfile_name, imagename)

    def get_dockerfiles(self, container_name):
        output = []
        container = self.get_container(container_name)
        if container is None:
            return output
        for d in container['dockerfiles']:
            output.append(d)
        return output

    def get_dockerfile(self, container_name, os_name):
        dfs = self.get_dockerfiles(container_name)
        df = get_by_name(dfs, 'os_name', os_name)
        return df

    def get_dockerfile_names(self, container_name):
        output = []
        for d in self.get_dockerfiles(container_name):
            output.append(d['os_name'])
        return output

    def get_dockerfile_path(self, container_name, os_name):
        d = self.get_dockerfile(container_name, os_name)
        if d is None:
            return None
        return d['path']

    def get_dockerfile_filename(self, container_name, os_name):
        path = self.get_dockerfile_path(container_name, os_name)
        filename = os.path.basename(path)
        return filename

    def get_container(self, container_name):
        return get_by_name(self.data, 'name', container_name)

    def get_container_names(self):
        output = []
        for c in self.data:
            output.append(c['name'])
        return output

    def get_container_path(self, container_name):
        c = self.get_container(container_name)
        if c is None:
            return None
        return c['path']

    def get_base_image(self, container_name, os_name):
        path = self.get_dockerfile_path(container_name, os_name)
        baseimage = dockerfile_get_base_image(path)
        return baseimage

    def pull_base_image(self, container_name, os_name, allow_errors=False):
        baseimage = self.get_base_image(container_name, os_name)
        docker_pull(baseimage, allow_errors=allow_errors)

    def clean(self, repo):
        images = docker_get_images(repo)
        for image in images:
            image_hash = image['IMAGE']
            docker_delete_image(image_hash)

    def push(self, repo):
        images = docker_get_images(repo)
        for image in images:
            tag = image['TAG']
            imagename = "{}:{}".format(repo, tag)
            docker_push(imagename)

    def __iter__(self):
        self.setup_jobs()
        return self

    def get_next_job(self, container_name, os_name):
        c = get_by_name(self.jobs, 'name', container_name)
        if c is None:
            return None, None
        dfs = c['dockerfiles']
        df = get_by_name(dfs, 'os_name', os_name)
        if df is None:
            return None, None
        # Dependancies need to loaded first
        # Dependants need to be cleaned first
        if self.reverse_deps:
            key = 'dependent'
        else:
            key = 'depends'
        if df.get(key, None) is None:
            return container_name, os_name
        dep = df[key]
        if get_by_name(self.jobs, 'name', dep) is None:
            # dependancy is missing from jobs, assume it's met
            return container_name, os_name
        cnout, osnout = self.get_next_job(dep, os_name)
        if cnout is None:
            return container_name, os_name
        return cnout, osnout

    def __next__(self):
        if len(self.jobs) == 0:
            raise StopIteration
        c = self.jobs[0]['name']
        o = self.jobs[0]['dockerfiles'][0]['os_name']
        container_name, os_name = self.get_next_job(c, o)
        self.delete_dockerfile_from_jobs(container_name, os_name)
        return container_name, os_name
