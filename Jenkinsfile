pipeline {
	agent {
		label 'buildtestmed'
	}
	stages {
		stage ('Initializing Variables') {
			steps {
				script {
					current_version = getOfficialVersion("updates")
				}
			}
		}
		stage ('Build') {
			parallel {
				stage ('Build Simplerisk Ubuntu 18.04') {
					steps {
						sh """
							sudo docker build -t simplerisk/simplerisk -f simplerisk/bionic/Dockerfile simplerisk/
							sudo docker build -t simplerisk/simplerisk:$current_version -f simplerisk/bionic/Dockerfile simplerisk/
							sudo docker build -t simplerisk/simplerisk:$current_version-bionic -f simplerisk/bionic/Dockerfile simplerisk/
						"""
					}
				}
				stage ('Build Simplerisk Ubuntu 20.04') {
					steps {
						sh """
							sudo docker build -t simplerisk/simplerisk:$current_version-focal -f simplerisk/bionic/Dockerfile simplerisk/
						"""
					}
				}
			}
		}
	}
}

def getCurrentDate() {
	return sh(script: "date +\"%Y%m%d-001\"", returnStdout: true).trim()
}

def getOfficialVersion(String updatesDomain="updates-test") {
    return sh(script: "echo \$(curl -sL https://$updatesDomain\\.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1)", returnStdout: true).trim()
}
