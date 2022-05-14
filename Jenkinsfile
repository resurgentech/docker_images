pipeline {
  agent none
  options { timestamps() }
  stages {
    stage('') {
      agent { label 'litedockerdedicated1' }
      steps {
        git branch: 'main',
          url: 'https://github.com/resurgentech/docker_images.git'
        sh './build.py  --container base'
        sh './build.py  --push'
        sh './build.py  --container dev_base'
        sh './build.py  --push'
        sh './build.py  --container kernel_build'
        sh './build.py  --push'
        sh './build.py  --container qt5_dev'
        sh './build.py  --push'
      }
    }
  }
}