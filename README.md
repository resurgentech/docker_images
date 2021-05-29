# docker_images
Public docker images

## Usage
```
./build.py --container dev_base --os centos8
```
This would build an image based on the docker file at `containers/dev_base/Dockerfile.centos8` and label it as `resurgentech/dev_base__centos8:{GIT_SHORT_HASH}-{SECONDS_FROM_EPOCH}`

```
./build.py --container dev_base
```
Builds images based on Dockerfiles in `containers/dev_base/`

```
./build.py
```
Builds all images

```
./build.py --push [--tag XXXXX]
```
Pushes all, or just a single specific image

## Container Images
Directories in `./containers` define a sort of container class defining a role or job.  Inside of each subdirectory here is where Dockerfiles for each supported OS should be housed.

Naming convention for Dockerfiles is Dockerfile.OSNAME for example `Dockerfile.centos8`

A `deps.yaml` file in each subdirectory is required to define dependencies between container class.

### base
Base external images with updates
### dev_base
Base images with Development Tools / build-essential
### kernel_build
Required images for not just kernel but full os kernel packages
Depends on dev_base
