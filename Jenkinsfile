pipeline {
    agent any

    environment {
        ARM_CLIENT_ID       = credentials('azure-client-id')
        ARM_CLIENT_SECRET   = credentials('azure-client-secret')
        ARM_TENANT_ID       = credentials('azure-tenant-id')
        ARM_SUBSCRIPTION_ID = credentials('azure-sub-id')
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Cloning the repository...'
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                echo 'Initializing Terraform...'
                sh '''
                    terraform --version
                    terraform init -input=false
                '''
            }
        }

        stage('Terraform Validate') {
            steps {
                echo 'Validating Terraform configuration...'
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                echo 'Creating Terraform plan...'
                sh 'terraform plan -out=tfplan -input=false'
            }
        }

        stage('Terraform Apply') {
            steps {
                input message: 'Do you approve to apply the Terraform changes?'
                echo 'Applying Terraform changes...'
                sh 'terraform apply -auto-approve tfplan'
            }
        }

        // ✅ Added stage for safe infrastructure destruction
        stage('Terraform Destroy') {
            steps {
                input message: 'Are you sure you want to destroy all infrastructure?'
                sh '''
                    echo "Destroying Terraform-managed infrastructure..."
                    terraform destroy -auto-approve
                '''
            }
        }
    }

    post {
        success {
            echo '✅ Terraform pipeline executed successfully!'
        }
        failure {
            echo '❌ Terraform pipeline failed. Check logs for details.'
        }
    }
}
