pipeline {
	agent none
	stages {
		stage ('Initializing Common Variables') {
			agent { label 'terminator' }
			steps {
				script {
					current_version = getOfficialVersion("updates")
					committer_email = getCommitterEmail()
				}
			}
			post {
				failure {
					sendErrorEmail("${env.STAGE_NAME}", "${committer_email}")
				}
			}
		}
		stage ('simplerisk/simplerisk') {
			stages {
				stage ('Initialize Variables') {
					agent { label 'buildtestmed' }
					steps {
						script {
							instance_id = getEC2Metadata("instance-id")
							main_stage = "simplerisk"
						}
					}
					post {
						failure {
							terminateInstance("${instance_id}")
							sendErrorEmail("${main_stage}/${env.STAGE_NAME}", "${committer_email}")
						}
						aborted {
							terminateInstance("${instance_id}")
						}
					}
				}
				stage ('Build') {
					parallel {
						stage ('Ubuntu 18.04') {
							agent { label 'buildtestmed' }
							steps {
								script {
									image = env.STAGE_NAME
								}
								sh """
									sudo docker build -t simplerisk/simplerisk:$current_version-bionic -f simplerisk/bionic/Dockerfile simplerisk/
								"""
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "build/simplerisk/ubuntu-1804", description: "Image built successfully", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}/${image}", "${committer_email}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
						stage ('Ubuntu 20.04') {
							agent { label 'buildtestmed' }
							steps {
								script {
									image = env.STAGE_NAME
								}
								sh """
									sudo docker build -t simplerisk/simplerisk -f simplerisk/focal/Dockerfile simplerisk/
									sudo docker build -t simplerisk/simplerisk:$current_version -f simplerisk/focal/Dockerfile simplerisk/
									sudo docker build -t simplerisk/simplerisk:$current_version-focal -f simplerisk/focal/Dockerfile simplerisk/
								"""
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "build/simplerisk/ubuntu-2004", description: "Image built successfully", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}/${image}", "${committer_email}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
					}
				}
				stage ('Push to Docker Hub') {
					when { branch 'master' }
					stages {
						stage ('Log into Docker Hub') {
							agent { label 'buildtestmed' }
							steps {
								setDockerCreds()
							}
							post {
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}", "${committer_email}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
						stage ('Push') {
							parallel {
								stage ("Current Version - bionic") {
									agent { label 'buildtestmed' }
									steps {
										script {
											image = env.STAGE_NAME
										}
										sh """
											sudo docker push simplerisk/simplerisk:$current_version-bionic
										"""
									}
								}
								stage ("Latest/Current Version/Current Version - focal") {
									agent { label 'buildtestmed' }
									steps {
										script {
											image = env.STAGE_NAME
										}
										sh """
											sudo docker push simplerisk/simplerisk
											sudo docker push simplerisk/simplerisk:$current_version
											sudo docker push simplerisk/simplerisk:$current_version-focal
										"""
									}
								}
							}
							post {
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}/${image}", "${committer_email}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
					}
				}
			}
			post {
				cleanup {
					terminateInstance("${instance_id}")
					sleep 60
				}
			}
		}
		stage ('simplerisk/simplerisk-minimal') {
			stages {
				stage ('Initialize Variables') {
					agent { label 'buildtestmed' }
					steps {
						script {
							instance_id = getEC2Metadata("instance-id")
							main_stage = "simplerisk-minimal"
						}
					}
					post {
						failure {
							terminateInstance("${instance_id}")
							sendErrorEmail("${main_stage}/${env.STAGE_NAME}", "${committer_email}")
						}
						aborted {
							terminateInstance("${instance_id}")
						}
					}
				}
				stage ('Build') {
					parallel {
						stage ('PHP 7.2') {
							agent { label 'buildtestmed' }
							steps {
								script {
									image = env.STAGE_NAME
								}
								sh """
									sudo docker build -t simplerisk/simplerisk-minimal:$current_version-php72 -f simplerisk-minimal/php7.2/Dockerfile simplerisk-minimal/
								"""
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "build/simplerisk-minimal/php-72", description: "Image built successfully", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}/${image}", "${committer_email}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
						stage ('PHP 7.4') {
							agent { label 'buildtestmed' }
							steps {
								script {
									image = env.STAGE_NAME
								}
								sh """
									sudo docker build -t simplerisk/simplerisk-minimal -f simplerisk-minimal/php7.4/Dockerfile simplerisk-minimal/
									sudo docker build -t simplerisk/simplerisk-minimal:$current_version -f simplerisk-minimal/php7.4/Dockerfile simplerisk-minimal/
									sudo docker build -t simplerisk/simplerisk-minimal:$current_version-php74 -f simplerisk-minimal/php7.4/Dockerfile simplerisk-minimal/
								"""
							}
							post {
								success {
									script {
										if (env.CHANGE_ID) {
											pullRequest.createStatus(status: "success", context: "build/simplerisk-minimal/php-74", description: "Image built successfully", targetUrl: "$BUILD_URL")
										}
									}
								}
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}/${image}", "${committer_email}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
					}
				}
				stage ('Push to Docker Hub') {
					when { branch 'master' }
					stages {
						stage ('Log into Docker Hub') {
							agent { label 'buildtestmed' }
							steps {
								setDockerCreds()
							}
							post {
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}", "${committer_email}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
						stage ('Push') {
							parallel {
								stage ('Current Version - PHP 7.2') {
									agent { label 'buildtestmed' }
									steps {
										script {
											image = env.STAGE_NAME
										}
										sh """
											sudo docker push simplerisk/simplerisk-minimal:$current_version-php72
										"""
									}
								}
								stage ("Latest/Current Version/Current Version - PHP 7.4") {
									agent { label 'buildtestmed' }
									steps {
										script {
											image = env.STAGE_NAME
										}
										sh """
											sudo docker push simplerisk/simplerisk-minimal
											sudo docker push simplerisk/simplerisk-minimal:$current_version
											sudo docker push simplerisk/simplerisk-minimal:$current_version-php74
										"""
									}
								}
							}
							post {
								failure {
									terminateInstance("${instance_id}")
									sendErrorEmail("${main_stage}/${env.STAGE_NAME}/${image}")
								}
								aborted {
									terminateInstance("${instance_id}")
								}
							}
						}
					}
				}
			}
			post {
				cleanup {
					terminateInstance("${instance_id}")
					sleep 60
				}
			}
		}
	}
	post {
		success {
			sendSuccessEmail("${committer_email}")
		}
	}
}

def getCommitterEmail() {
	return sh(script: "git --no-pager show -s --format='%ae'", returnStdout: true).trim()
}

def getEC2Metadata(String attribute){
	return sh(script: "echo \$(TOKEN=`curl -s -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 21600\"` && curl -s -H \"X-aws-ec2-metadata-token: \$TOKEN\" http://169.254.169.254/latest/meta-data/$attribute)", returnStdout: true).trim()
}

def getOfficialVersion(String updatesDomain="updates-test") {
	return sh(script: "echo \$(curl -sL https://$updatesDomain\\.simplerisk.com/Current_Version.xml | grep -oP '<appversion>(.*)</appversion>' | cut -d '>' -f 2 | cut -d '<' -f 1)", returnStdout: true).trim()
}

void sendEmail(String message, String recipient) {
	mail from: 'jenkins@simplerisk.com', to: """${recipient}""", bcc: '',  cc: 'pedro@simplerisk.com', replyTo: '',
             subject: """${env.JOB_NAME} (Branch ${env.BRANCH_NAME}) - Build # ${env.BUILD_NUMBER} - ${currentBuild.currentResult}""",
             body: "$message"
}

void sendErrorEmail(String stage_name, String recipient) {
	sendEmail("""Job failed at stage \"${stage_name}\". Check console output at ${env.BUILD_URL} to view the results (The Blue Ocean option will provide the detailed execution flow).""", "$recipient")
}

void sendSuccessEmail(String recipient) {
	sendEmail("""Check console output at ${env.BUILD_URL} to view the results (The Blue Ocean option will provide the detailed execution flow).""", "$recipient")
}

void setDockerCreds() {
	withCredentials([usernamePassword(credentialsId: 'cb153fa6-2299-4bdb-9ef0-9c3e6382c87a', passwordVariable: 'docker_pass', usernameVariable: 'docker_user')]) {
		sh '''
			set +x
			echo $docker_pass >> /tmp/password.txt
			cat /tmp/password.txt | sudo docker login --username $docker_user --password-stdin
			rm /tmp/password.txt
		'''
	}
}

void terminateInstance(String instanceId, String region="us-east-1") {
	node ("terminator") {
		sh "aws ec2 terminate-instances --instance-ids $instanceId --region $region"
	}
}
