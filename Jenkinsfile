pipeline {
  agent none
  options { timestamps() }
  stages {
    stage('ubuntu2004') {
      agent { label 'litedockerdedicated1' }
      steps {
        git branch: 'ansible',
          url: 'https://github.com/resurgentech/docker_images.git'
        sh './build.py  --distro ubuntu2004'
      }
    }
    stage('ubuntu2204') {
      agent { label 'litedockerdedicated1' }
      steps {
        git branch: 'ansible',
          url: 'https://github.com/resurgentech/docker_images.git'
        sh './build.py  --distro ubuntu2204'
      }
    }
    stage('rockylinux8') {
      agent { label 'litedockerdedicated1' }
      steps {
        git branch: 'ansible',
          url: 'https://github.com/resurgentech/docker_images.git'
        sh './build.py  --distro rockylinux8'
      }
    }
    stage('amazonlinux2') {
      agent { label 'litedockerdedicated1' }
      steps {
        git branch: 'ansible',
          url: 'https://github.com/resurgentech/docker_images.git'
        sh './build.py  --distro amazonlinux2'
      }
    }
  }
}

# litedockerdedicated1 needs to have docker login run as the user
