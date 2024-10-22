# Jenkins Docker-outside-of-Docker with Nexus Registry

## Table of Contents

1. [Introduction](#1-introduction)
2. [Requisites](#2-requisites)
3. [Run Nexus](#3-run-nexus)
4. [Configure Nexus](#4-configure-nexus)
5. [Run Jenkins](#5-run-jenkins)
6. [Configure Jenkins](#6-configure-jenkins)
7. [Create Jenkins Pipeline](#7-create-jenkins-pipeline)

## 1. Introduction

This project demonstrates how to set up a continuous integration and deployment (CI/CD) pipeline using Jenkins with Docker-outside-of-Docker (DooD) capabilities, integrated with a local Nexus repository for Docker images. This setup allows you to:

- Run Jenkins in a Docker container
- Build and manage Docker images within Jenkins pipelines
- Push and pull Docker images from a local Nexus repository

By following this guide, you'll have a powerful, local CI/CD environment that can be used for developing, testing, and deploying containerized applications.

## 2. Requisites

Before you begin, ensure you have the following in place:

1. **MacOS with Apple Silicon (ARM64 architecture)**:
   - This project is designed and tested on macOS running on Apple Silicon (M1/M2 chips).
2. **Docker Desktop**:
   - Install Docker Desktop for MacOS.
   - Verify installation by running:

     ```bash
     docker --version
     ```

3. **Git**:
   - Install Git for version control.
   - Verify installation by running:

     ```bash
     git --version
     ```

4. **Ports**:
   - The following ports should be free on your local machine:
     - 8080 (Jenkins web interface)
     - 8081 (Nexus web interface)
     - 8082 (Nexus Docker registry)
     - 50000 (Jenkins agents)

Verify Docker is running correctly by executing the following command:

```bash
docker run hello-world
```

If successful, you should see a "Hello from Docker!" message.

Once you have these prerequisites in place, you're ready to proceed with setting up Nexus and Jenkins.

## 3. Run Nexus

1. **Pull the Nexus image:**

   ```bash
   docker pull sonatype/nexus3:latest
   ```

2. **Run the Nexus container:**

   ```bash
   docker run -d -p 8081:8081 -p 8082:8082 --name nexus sonatype/nexus3:latest
   ```

3. **Wait for Nexus to start:**
   Nexus may take a few minutes to start. Monitor the logs:

   ```bash
   docker logs -f nexus
   ```

   Wait until you see the message "Started Sonatype Nexus".

4. **Access the Nexus web interface:**
   - Open a web browser and go to `http://localhost:8081`
   - You may need to wait a bit longer if the page doesn't load immediately

5. **Get the initial admin password:**

   ```bash
   docker exec -it nexus cat /nexus-data/admin.password
   ```

   Copy this password; you'll need it to log in.

## 4. Configure Nexus

1. **Log in to Nexus:**
   - Click on 'Sign In' in the top right corner of the Nexus web interface
   - Username: `admin`
   - Password: Use the password you retrieved in the previous section
   - You'll be prompted to change the password after first login

2. **Create a Docker hosted repository:**
   - Go to 'Server administration and configuration' (gear icon)
   - Click on 'Repositories' in the left sidebar
   - Click 'Create repository'
   - Select 'docker (hosted)' from the list
   - Name it `docker-hosted`
   - HTTP: Check and set port to 8082
   - Click 'Create repository' at the bottom of the page

3. **Create a user for Docker authentication:**
   - Go to 'Security' > 'Users' in the left sidebar
   - Click 'Create local user'
   - Fill in the details:
     - ID: `docker-user` (or any name you prefer)
     - First name: Docker
     - Last name: User
     - Email: <your-email@example.com>
     - Password: Choose a strong password
   - Status: Active
   - Roles: Select 'nx-admin' for this example (in production, you'd assign more specific roles)
   - Click 'Create local user'

4. **Configure Docker Bearer Token Realm:**
   - Go to 'Security' > 'Realms' in the left sidebar
   - Move 'Docker Bearer Token Realm' from the Available column to the Active column
   - Click 'Save'

5. **Test the Nexus Docker registry:**
   Log in to Docker registry:

   ```bash
   docker login localhost:8082
   ```

   Use the username and password you created in step 3.

   Push a test image:

   ```bash
   docker pull hello-world:latest
   docker tag hello-world:latest localhost:8082/hello-world:test
   docker push localhost:8082/hello-world:test
   ```

6. **Verify the image in Nexus repository:**
   - In the Nexus web interface, click on the 'Browse' button in the left sidebar
   - Select your `docker-hosted` repository from the list
   - You should see `hello-world` listed as a component
   - Click on `hello-world` to expand it
   - You should see the `test` tag listed

Your Nexus Docker registry is now set up and verified.

## 5. Run Jenkins

1. **Create a Dockerfile for Jenkins:**
   Create a file named `Dockerfile` with the following content:

   ```dockerfile
   FROM jenkins/jenkins:lts

   USER root

   # Install prerequisites
   RUN apt-get update && \
       apt-get install -y \
       apt-transport-https \
       ca-certificates \
       curl \
       gnupg \
       lsb-release

   # Install Docker CLI using the convenience script
   RUN curl -fsSL https://get.docker.com -o get-docker.sh && \
       sh get-docker.sh && \
       rm get-docker.sh

   # Install Docker Compose
   RUN curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
       chmod +x /usr/local/bin/docker-compose

   # Create docker group and add jenkins user to it
   RUN groupadd docker || true && usermod -aG docker jenkins

   # Create entrypoint script
   RUN echo '#!/bin/bash\n\
   if [ -S /var/run/docker.sock ]; then\n\
       chmod 666 /var/run/docker.sock\n\
       echo "Set permissions for Docker socket"\n\
   fi\n\
   exec /usr/local/bin/jenkins.sh "$@"' > /entrypoint.sh && \
       chmod +x /entrypoint.sh

   USER jenkins

   # Install Jenkins plugins
   RUN jenkins-plugin-cli --plugins docker-workflow docker-plugin

   ENTRYPOINT ["/entrypoint.sh"]
   ```

2. **Build the Jenkins Docker image:**

   ```bash
   docker build -t jenkins-dood .
   ```

3. **Run the Jenkins container:**

   ```bash
   docker run -d \
     --name jenkins-dood \
     --restart=on-failure \
     -p 8080:8080 \
     -p 50000:50000 \
     -v jenkins_home:/var/jenkins_home \
     -v /var/run/docker.sock:/var/run/docker.sock \
     --add-host=host.docker.internal:host-gateway \
     jenkins-dood
   ```

4. **Wait for Jenkins to start:**
   Monitor the logs:

   ```bash
   docker logs -f jenkins-dood
   ```

   Wait until you see the message "Jenkins is fully up and running".

5. **Get the initial admin password:**

   ```bash
   docker exec jenkins-dood cat /var/jenkins_home/secrets/initialAdminPassword
   ```

   Copy this password; you'll need it to log in to Jenkins.

## 6. Configure Jenkins

1. **Access Jenkins:**
   - Open a web browser and go to `http://localhost:8080`
   - Enter the initial admin password you retrieved in the previous step

2. **Complete the Jenkins Setup Wizard:**
   - Choose "Install suggested plugins" when prompted
   - Wait for the plugin installation to complete

3. **Create First Admin User:**
   - Fill in the required details (username, password, full name, email)
   - Click "Save and Continue"

4. **Configure Jenkins URL:**
   - The default Jenkins URL should be fine for local use (`http://localhost:8080/`)
   - Click "Save and Finish"

5. **Verify Docker Integration:**
   - Create a new Pipeline job (New Item > Pipeline)
   - In the Pipeline script area, paste the following:

     ```groovy
     pipeline {
         agent any
         stages {
             stage('Test Docker') {
                 steps {
                     sh 'docker version'
                     sh 'docker ps'
                 }
             }
         }
     }
     ```

   - Run the pipeline and check the console output to ensure Docker commands are executing successfully

6. **Add Nexus Credentials:**
   - Go to "Manage Jenkins" > "Manage Credentials"
   - Click on "(global)" under "Stores scoped to Jenkins"
   - Click "Add Credentials" in the left sidebar
   - Kind: Username with password
   - Scope: Global
   - Username: Your Nexus username (e.g., "docker-user")
   - Password: Your Nexus password
   - ID: nexus-credentials
   - Description: Nexus Docker Registry
   - Click "OK"

Your Jenkins instance is now set up with Docker integration and ready to use with your Nexus registry.

# 7. Create Jenkins Pipeline

In this section, we'll create a Jenkins pipeline that pulls code from a Git repository, builds a Docker image, runs tests, and pushes the image to our local Nexus registry.

1. Create a new pipeline in Jenkins:
   - From the Jenkins dashboard, click "New Item"
   - Enter "My Pipeline" as the item name
   - Choose "Pipeline" as the item type and click "OK"

2. Configure the pipeline:
   In the pipeline configuration page, scroll down to the "Pipeline" section and select "Pipeline script" from the Definition dropdown. Then, paste the following script:

```groovy
   pipeline {
       agent any
       
       environment {
           NEXUS_URL = "localhost:8082"
           IMAGE_NAME = "my-node-app"
           GIT_REPO = "https://github.com/EducacionMundose/PIN1.git"
       }
       
       stages {
           stage('Checkout') {
               steps {
                   git branch: 'main', url: env.GIT_REPO
               }
           }
           
           stage('Build Docker Image') {
               steps {
                   script {
                       dockerImage = docker.build("${NEXUS_URL}/${IMAGE_NAME}:${env.BUILD_ID}")
                   }
               }
           }
           
           stage('Run Tests') {
               steps {
                   script {
                       dockerImage.inside {
                           sh 'npm install --only=dev'
                           sh 'npm test'
                       }
                   }
               }
           }
           
           stage('Push to Nexus') {
               steps {
                   script {
                       docker.withRegistry("http://${NEXUS_URL}", 'nexus-credentials') {
                           dockerImage.push("${env.BUILD_ID}")
                           dockerImage.push("latest")
                       }
                   }
               }
           }
       }
       
       post {
           always {
               sh 'docker rmi ${NEXUS_URL}/${IMAGE_NAME}:${BUILD_ID}'
           }
       }
   }
```

3. Explanation of the pipeline:
   - The pipeline uses the 'agent any' directive, allowing it to run on any available Jenkins agent.
   - Environment variables are set for the Nexus URL, image name, and Git repository URL.
   - The 'Checkout' stage pulls the code from the specified Git repository.
   - The 'Build Docker Image' stage builds a Docker image using the Dockerfile in the repository.
   - The 'Run Tests' stage runs 'npm test' inside the built Docker container. It installs dev dependencies first to ensure all necessary packages for testing are available.
   - The 'Push to Nexus' stage pushes the built image to the Nexus registry, tagging it with both the build number and "latest".
   - The 'post' section ensures that the local Docker image is removed after the pipeline completes, regardless of success or failure.

4. Save and run the pipeline:
   - Click "Save" to store the pipeline configuration.
   - On the pipeline page, click "Build Now" to run the pipeline.

5. Monitor the pipeline execution:
   - Click on the build number in the "Build History" section.
   - Click "Console Output" to view the detailed logs of the pipeline execution.

6. Verify the results:
   - Check that the pipeline completes successfully.
   - Verify that the Docker image has been pushed to your Nexus registry by logging into the Nexus web interface and checking the Docker hosted repository.

This pipeline automates the process of building, testing, and deploying your Node.js application as a Docker image to your local Nexus registry. Adjust the 'GIT_REPO' URL if your repository is different, and make sure your project has a valid Dockerfile and npm test script configured.
