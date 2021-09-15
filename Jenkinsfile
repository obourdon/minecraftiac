pipeline {
 
    agent {
		docker { 
			image 'cpruvost/terransible:latest'
			args '-u root:root'
		}
	}
	
	//Parameters of the pipeline. You can define more parameters in this pipeline in order to have less hard code variables.
	parameters {
		//Jenkins Bugg with password so I used string for demo
        //password(defaultValue: "xxxxxxxxxx", description: 'What is the vault token ?', name: 'VAULT_TOKEN')
		string(defaultValue: "WdPdcgUA1XNy23MoiR8uuOWu", description: 'What is the vault token ?', name: 'VAULT_TOKEN')
		string(defaultValue: "130.61.125.123", description: 'What is the vault server IP Address ?', name: 'VAULT_SERVER_IP')
		string(defaultValue: "demoatp", description: 'What is the vault secret name ?', name: 'VAULT_SECRET_NAME')  	
		string(defaultValue: "https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/cnNvV3PkZmsWFgy3q7YnNXyBe8ukmwvDNA_OIm56V9wLXSPnDk5nMl0ugEJzo_Up/n/oraseemeafrtech1/b/Minecraft/o/terraform.tfstate", description: 'Where is stored the terraform state ?', name: 'TERRAFORM_STATE_URL')  
		choice(name: 'CHOICE', choices: ['Create', 'Remove'], description: 'Choose between Create or Remove Infrastructure')
    }
	
	//Load the parameters as environment variables
	environment {
		//Vault Env mandatory variables
		VAULT_TOKEN = "${params.VAULT_TOKEN}"
		VAULT_SERVER_IP = "${params.VAULT_SERVER_IP}"
		VAULT_ADDR = "http://${params.VAULT_SERVER_IP}:8200"
		VAULT_SECRET_NAME = "${params.VAULT_SECRET_NAME}"
		CHOICE = "${params.CHOICE}"
		
		//Terraform variables
		TF_CLI_ARGS = "-no-color"
		TF_VAR_terraform_state_url = "${params.TERRAFORM_STATE_URL}"
	}
    
    stages {
		//Only for debug due to Jenkins password bugg
        /*stage('Check Vault Information') {
            steps {
				echo "${VAULT_TOKEN}"
				echo "${VAULT_SERVER_IP}"
				echo "${VAULT_ADDR}"
				echo "${VAULT_SECRET_NAME}"
            }
        }*/

		stage('Display User Name') {
			agent any
            steps {
			    wrap([$class:'BuildUser']) {
				    echo "${BUILD_USER}"
				}
            }
        }
	
        stage('Check Infra As Code Tools') {
            steps {
				sh 'whoami'
				sh 'pwd'
				sh 'ls'
			    sh 'chmod +x ./showtoolsversion.sh'
                sh './showtoolsversion.sh'
            }
        }
		
		stage('Init Cloud Env Variables') {
            steps {
				script {
					//Get all cloud information.
					env.TF_VAR_tenancy_ocid = sh returnStdout: true, script: 'vault kv get -field=tenancy_ocid secret/demoatp'
					env.TF_VAR_user_ocid = sh returnStdout: true, script: 'vault kv get -field=user_ocid secret/demoatp'
					env.TF_VAR_fingerprint = sh returnStdout: true, script: 'vault kv get -field=fingerprint secret/demoatp'
					env.TF_VAR_compartment_ocid = sh returnStdout: true, script: 'vault kv get -field=compartment_ocid secret/demoatp'
					env.TF_VAR_region = sh returnStdout: true, script: 'vault kv get -field=region secret/demoatp'
					env.DOCKERHUB_USERNAME = sh returnStdout: true, script: 'vault kv get -field=dockerhub_username secret/demoatp'
					env.DOCKERHUB_PASSWORD = sh returnStdout: true, script: 'vault kv get -field=dockerhub_password secret/demoatp'
					
					//Terraform debugg option if problem
					//env.TF_LOG="DEBUG"
					//env.OCI_GO_SDK_DEBUG="v"
				}
				
				//Check all cloud information.
				echo "TF_VAR_tenancy_ocid=${TF_VAR_tenancy_ocid}"
				echo "TF_VAR_user_ocid=${TF_VAR_user_ocid}"
				echo "TF_VAR_fingerprint=${TF_VAR_fingerprint}"
				echo "TF_VAR_compartment_ocid=${TF_VAR_compartment_ocid}"
				echo "TF_VAR_region=${TF_VAR_region}"
				echo "TF_VAR_terraform_state_url=${TF_VAR_terraform_state_url}"
				echo "DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME}"
				echo "DOCKERHUB_PASSWORD=${DOCKERHUB_PASSWORD}"
				//echo "KUBECONFIG=${KUBECONFIG}"
				
				dir ('./tf/modules/vm') {
					script {
						//Get the API and SSH encoded key Files with vault client because curl breaks the end line of the key file
						sh 'vault kv get -field=api_private_key secret/demoatp | tr -d "\n" | base64 --decode > bmcs_api_key.pem'
						sh 'vault kv get -field=ssh_private_key secret/demoatp | tr -d "\n" | base64 --decode > id_rsa'
						sh 'vault kv get -field=ssh_public_key secret/demoatp | tr -d "\n" | base64 --decode > id_rsa.pub'
						
						//OCI CLI permissions mandatory on some files.
						sh 'oci setup repair-file-permissions --file ./bmcs_api_key.pem'
						
						sh 'ls'
						sh 'cat ./bmcs_api_key.pem'
						sh 'cat ./id_rsa'
						sh 'cat ./id_rsa.pub'
						
						env.TF_VAR_private_key_path = './bmcs_api_key.pem'
						echo "TF_VAR_private_key_path=${TF_VAR_private_key_path}"
						env.TF_VAR_ssh_private_key = sh returnStdout: true, script: 'cat ./id_rsa'
						echo "TF_VAR_ssh_private_key=${TF_VAR_ssh_private_key}"
						env.TF_VAR_ssh_public_key = sh returnStdout: true, script: 'cat ./id_rsa.pub'
						echo "TF_VAR_ssh_public_key=${TF_VAR_ssh_public_key}"
					}
				}
				
				//OCI CLI Setup
				sh 'mkdir -p /root/.oci'
				sh 'rm -rf /root/.oci/config'
				sh 'echo "[DEFAULT]" > /root/.oci/config'
				sh 'echo "user=${TF_VAR_user_ocid}" >> /root/.oci/config'
				sh 'echo "fingerprint=${TF_VAR_fingerprint}" >> /root/.oci/config'
				sh 'echo "key_file=./bmcs_api_key.pem" >> /root/.oci/config'
				sh 'echo "tenancy=${TF_VAR_tenancy_ocid}" >> /root/.oci/config'
				sh 'echo "region=${TF_VAR_region}" >> /root/.oci/config'
				sh 'cat /root/.oci/config'
				
				//OCI CLI permissions mandatory on some files.
				sh 'oci setup repair-file-permissions --file /root/.oci/config'
            }
        }
		
		stage('TF Plan Minecraft VM') { 
            steps {
				dir ('./tf/modules/vm') {
					sh 'ls'
					
					//Terraform initialization in order to get oci plugin provider	
					sh 'terraform init -input=false -backend-config="address=${TF_VAR_terraform_state_url}"'
					
					
					script {
						echo "CHOICE=${env.CHOICE}"
					    //Terraform plan
					    if (env.CHOICE == "Create") {
							sh 'terraform plan -out myplan'
						}
						else {
						    sh 'terraform plan -destroy -out myplan'
						}
					}
				}
			}
		}
		
		stage('TF Apply Minecraft VM') { 
            steps {
				dir ('./tf/modules/vm') {
					sh 'ls'
					
					script {				
						echo "CHOICE=${env.CHOICE}"
						
					    //Terraform plan
					    if (env.CHOICE == "Create") {
							sh 'terraform apply -input=false -auto-approve myplan'
						}
						else {
						    sh 'terraform destroy -input=false -auto-approve'
						}
					}
				}
			}
		}
    } 

	stage('Update Ansible Host File') { 
            steps {
				dir ('./ansible') {
					sh 'ls'
					sh 'sed -i "s/ipaddressparam/129.159.193.222/"'
					sh 'cat ./hosts'
				}
			}
		}
    }       
}