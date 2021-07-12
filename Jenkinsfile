pipeline {
	agent {
		label 'buildtestmed'
	}
	stages {
		stage ('Initializing Variables') {
			steps {
				script {
					current_version = getOfficialVersion("updates")
					instance_id = getEC2Metadata("instance-id")
				}
			}
		}
		stage ('Log into Docker Hub') {
			steps {
				withCredentials([usernamePassword(credentialsId: 'cb153fa6-2299-4bdb-9ef0-9c3e6382c87a', passwordVariable: 'docker_pass', usernameVariable: 'docker_user')]) {
					sh '''
						set +x
						echo $docker_pass >> /tmp/password.txt
						cat /tmp/password.txt | sudo docker login --username $docker_user --password-stdin
						rm /tmp/password.txt
					'''
				}
			}
			post {
				failure {
					node("jenkins") {
						terminateInstance("${instance_id}")
					}
					error("Stopping full build")
				}
			}
		}
		stage ('simplerisk/simplerisk') {
			stages {
				stage ('Build') {
					parallel {
						stage ('SimpleRisk Ubuntu 18.04') {
							steps {
								sh """
									sudo docker build -t simplerisk/simplerisk -f simplerisk/bionic/Dockerfile simplerisk/
									sudo docker build -t simplerisk/simplerisk:$current_version -f simplerisk/bionic/Dockerfile simplerisk/
									sudo docker build -t simplerisk/simplerisk:$current_version-bionic -f simplerisk/bionic/Dockerfile simplerisk/
								"""
							}
						}
						stage ('SimpleRisk Ubuntu 20.04') {
							steps {
								sh """
									sudo docker build -t simplerisk/simplerisk:$current_version-focal -f simplerisk/focal/Dockerfile simplerisk/
								"""
							}
						}
					}
					post {
						success {
							if (env.BRANCH_NAME != 'master') {
								node("jenkins") {
									terminateInstance("${instance_id}")
								}
							}
						}
						failure {
							node("jenkins") {
								terminateInstance("${instance_id}")
							}
							error("Stopping full build")
						}
					}
				}
				stage ('Push') {
					when {
						expression {
							env.BRANCH_NAME == "master"
						}
					}
					parallel {
						stage ('Push SimpleRisk latest') {
							steps {
								sh "sudo docker push simplerisk/simplerisk"
							}
						}
						stage ('Push SimpleRisk current version') {
							steps {
								sh "sudo docker push simplerisk/simplerisk:$current_version"
							}
						}
						stage ('Push SimpleRisk current version for Bionic') {
							steps {
								sh "sudo docker push simplerisk/simplerisk:$current_version-bionic"
							}
						}
						stage ('Push SimpleRisk current version for Focal') {
							steps {
								sh "sudo docker push simplerisk/simplerisk:$current_version-focal"
							}
						}

					}
					post {
						always {
							node("jenkins") {
								terminateInstance("${instance_id}")
							}
						}
						failure {
							error("Stopping full build")
						}
					}
				}
			}
		}
		stage ('simplerisk/simplerisk-minimal') {
			stages {
				stage ('Build') {
					parallel {
						stage ('Build SimpleRisk Minimal PHP 7.2') {
							steps {
								sh """
									sudo docker build -t simplerisk/simplerisk-minimal -f simplerisk-minimal/php7.2/Dockerfile simplerisk-minimal/
									sudo docker build -t simplerisk/simplerisk-minimal:$current_version -f simplerisk-minimal/php7.2/Dockerfile simplerisk-minimal/
									sudo docker build -t simplerisk/simplerisk-minimal:$current_version-php72 -f simplerisk-minimal/php7.2/Dockerfile simplerisk-minimal/
								"""
							}
						}
						stage ('Build SimpleRisk Minimal PHP 7.4') {
							steps {
								sh """
									sudo docker build -t simplerisk/simplerisk-minimal:$current_version-php74 -f simplerisk-minimal/php7.4/Dockerfile simplerisk-minimal/
								"""
							}
						}
					}
					post {
						success {
							if (env.BRANCH_NAME != 'master') {
								node("jenkins") {
									terminateInstance("${instance_id}")
								}
							}
						}
						failure {
							node("jenkins") {
								terminateInstance("${instance_id}")
							}
							error("Stopping full build")
						}
					}
				}
				stage ('Push') {
					when {
						expression {
							env.BRANCH_NAME == "master"
						}
					}
					parallel {
						stage ('Push SimpleRisk Minimal latest') {
							steps {
								sh "sudo docker push simplerisk/simplerisk-minimal"
							}
						}
						stage ('Push SimpleRisk Minimal current version') {
							steps {
								sh "sudo docker push simplerisk/simplerisk-minimal:$current_version"
							}
						}
						stage ('Push SimpleRisk Minimal current version for PHP 7.2') {
							steps {
								sh "sudo docker push simplerisk/simplerisk-minimal:$current_version-php72"
							}
						}
						stage ('Push SimpleRisk Minimal current version for PHP 7.4') {
							steps {
								sh "sudo docker push simplerisk/simplerisk-minimal:$current_version-php74"
							}
						}
					}
					post {
						always {
							node("jenkins") {
								terminateInstance("${instance_id}")
							}
						}
						failure {
							error("Stopping full build")
						}
					}
				}
			}
		}
	}
}

def getEC2Metadata(String attribute){
	return sh(script: "echo \$(TOKEN=`curl -s -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 21600\"` && curl -s -H \"X-aws-ec2-metadata-token: \$TOKEN\" http://169.254.169.254/latest/meta-data/$attribute)", returnStdout: true).trim()
}

def getOfficialVersion(String updatesDomain="updates-test") {
	return sh(script: "echo \$(curl -sL https://$updatesDomain\\.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1)", returnStdout: true).trim()
}

void sendEmail(String message) {
	mail from: 'jenkins@simplerisk.com', to: "$env.GIT_AUTHOR_EMAIL", bcc: '',  cc: 'pedro@simplerisk.com', replyTo: '',
             subject: """${env.JOB_NAME} (Branch ${env.BRANCH_NAME}) - Build # ${env.BUILD_NUMBER} - ${currentBuild.currentResult}""",
             body: """Check console output at ${env.BUILD_URL} to view the results (The Blue Ocean option will provide the detailed flow of execution)."""
}

void sendErrorEmail() {
	sendEmail("""Build failed at stage \"${env.STAGE_NAME}\". Check console output at ${env.BUILD_URL} to view the results (The Blue Ocean option will provide the detailed execution flow).""")
}

void sendSuccessEmail() {
	sendEmail("""Check console output at ${env.BUILD_URL} to view the results (The Blue Ocean option will provide the detailed execution flow).""")
}

void terminateInstance(String instanceId, String region="us-east-1") {
	sh "aws ec2 terminate-instances --instance-ids $instanceId --region $region"
}
