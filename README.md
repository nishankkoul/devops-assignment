# DevOps Assessment Project – Yii2 + Docker Swarm + CI/CD + Ansible

This project demonstrates how to deploy a sample PHP Yii2 application using Docker Swarm and NGINX as a host-based reverse proxy on an AWS EC2 instance. The deployment is fully automated using Ansible, while a CI/CD pipeline powered by GitHub Actions ensures continuous integration and delivery.

---

## 🧩 Project Components

- **Application**: Sample Yii2 PHP app
- **Containerization**: Docker
- **Orchestration**: Docker Swarm
- **Web Server**: NGINX (host-based reverse proxy)
- **CI/CD**: GitHub Actions
- **Automation**: Ansible
- **Hosting**: AWS EC2 (Ubuntu)

---

## 1. Application Deployment

### a. Using a Sample Yii2 PHP Application

To begin the deployment, we used a minimal Yii2 PHP application created using Composer on an Ubuntu EC2 instance.

#### Step 1: Provision an Ubuntu EC2 Instance

- Launch an EC2 instance with the **Ubuntu Server 22.04 LTS** AMI.
- Choose an appropriate instance type (e.g., `t2.medium`).
- Configure the security group to allow:
  - **Port 22** (SSH)
  - **Port 80** (HTTP)

#### Step 2: SSH Into the Instance

Use the following command to connect:

```bash
ssh -i /path/to/your-key.pem ubuntu@<your-ec2-public-ip>
```

#### Step 3: Update the System

Update the package lists and upgrade installed packages:

```bash
sudo apt update && sudo apt upgrade -y
```

#### Step 4: Install PHP CLI, Composer, and Yii2

Install necessary dependencies and set up Composer:

```bash
sudo apt install php-cli unzip curl php-xml -y
curl -sS https://getcomposer.org/installer -o composer-setup.php
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
composer --version
composer install --ignore-platform-req=ext-curl
```

#### Step 5: Create a basic Yii2 application:

```bash
composer create-project --prefer-dist yiisoft/yii2-app-basic hello-world-yii2
```

This creates a folder hello-world-yii2 containing a functional Yii2 app ready for containerization and deployment.

#### Step 6: Start the Application on Port 8080

```bash
cd hello-world-yii2
php -S 0.0.0.0:8080 -t web
```

This will serve the Yii2 application on port 8080 of your EC2 instance.

#### Step 7: Open Port 8080 in EC2 Security Group

-> Go to the AWS EC2 Dashboard

-> Select your instance → click on the Security Group → Edit inbound rules.

-> Add a rule:

```bash
Type: Custom TCP
Port range: 8080
Source: Anywhere (or restrict as needed)
```

Now, you can access the Yii2 application in your browser at:
```bash
http://<your-ec2-public-ip>:8080
```

### b. Set up Docker Swarm mode on the EC2 instance.

Now, we proceed on to deploying the application using Docker Swarm.

#### Step 1: Install Docker on the EC2 Instance

To prepare the EC2 instance for Docker Swarm, Docker CE (Community Edition) must be installed first. Run the following commands to install and start Docker:

```bash
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get install docker-ce -y
```

Once Docker is installed, start and enable the Docker service:

```bash
sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl status docker
```

Verify the Docker installation:

```bash
docker --version
```

You should see the installed Docker version confirming a successful setup.

#### Step 2: Initialize Docker Swarm

After installing Docker, initialize Docker Swarm mode to orchestrate your containers. Run the following command, replacing the IP address with your EC2 instance's public IP:

```bash
sudo docker swarm init --advertise-addr <EC2-Public-IP>
```

This command initializes the current node as the manager node in the Swarm cluster and advertises its address for other nodes to join.

To confirm that the Swarm has been initialized successfully, use:

```bash
sudo docker info
```

You should see Swarm: active in the output, confirming that Docker Swarm mode is enabled.

### c. Containerize the Yii2 application using Docker

Once Docker Swarm is initialized, the next step is to Containerize the Yii2 application using Docker.

#### Step 1: Create a Dockerfile

Inside the `hello-world-yii2` application directory, create a `Dockerfile` to define the image build instructions:

```bash
# Use the Yii2 PHP 8.2 base image
FROM yiisoftware/yii2-php:8.2-fpm

# Set working directory inside the container
WORKDIR /app

# Copy the current directory (application code) to the container
COPY . /app

# Set up Composer (PHP dependency manager) and install dependencies
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer install --no-dev --optimize-autoloader

# Expose port 8080 (the application will run on this port)
EXPOSE 8080

# Start PHP's built-in server to run Yii2 on port 8080
CMD php -S 0.0.0.0:8080 -t web
```

#### Step 2: Build the Docker Image

Use the following command from the root of your project (where the Dockerfile resides) to build the Docker image:

```bash
docker build -t <your-dockerhub-username>/pearlthoughts-devops-assignment:v1.0 .
```

#### Step 3: Push the Image to DockerHub

To deploy via Docker Swarm, the image needs to be accessible from the remote host, so we push it to DockerHub.

```bash
sudo usermod -aG docker ${USER}
newgrp docker
docker login  # Enter your DockerHub username and password when prompted.
docker push <your-dockerhub-username>/pearlthoughts-devops-assignment:v1.0
```

#### Step 4: Create a docker-compose.yml File

On your EC2 instance, create a docker-compose.yml file with the following content:

```bash
version: '3.8'

services:
  php:
    image: <your-dockerhub-username>/pearlthoughts-devops-assignment:2.7
    volumes:
      - ./:/app:delegated
    ports:
      - '8080:8080'
    restart: always
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
      update_config:
        parallelism: 1
        delay: 10s
    healthcheck:
      test: ["CMD", "curl", "--silent", "--fail", "http://localhost:8080/"]
      interval: 30s
      retries: 3
      timeout: 10s
      start_period: 10s
```

Replace <your-dockerhub-username> with your actual DockerHub username.

#### Step 5: Deploy the Containerized App Using Docker Swarm

Now that the image is available publicly and the compose file is ready, deploy the stack using:

```bash
sudo docker stack deploy -c docker-compose.yml myapp
```

To confirm that the service is running:

```bash
sudo docker service ls
```

Access your app in the browser via:

```bash
http://<your-ec2-ip>:8080
```

### d. Configure NGINX as a Host-Based Reverse Proxy

NGINX runs directly on the host (not in a Docker container) and is configured to act as a reverse proxy to the Dockerized Yii2 application running inside the Swarm service.

#### Step 1: Install and Start NGINX

Run the following commands on the EC2 instance to install and enable the NGINX service:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### Step 2: Configure NGINX to Proxy Requests to the Docker Container

Create a new NGINX configuration file called yii2-app:

```bash
sudo vim /etc/nginx/sites-available/yii2-app
```

Add the following content: 

```bash
server {
    listen 80;
    server_name _;

    root /app/web;
    index index.php;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location ~ \.php$ {
        proxy_pass http://localhost:8080;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

Enable the configuration by creating a symbolic link:

```bash
sudo ln -s /etc/nginx/sites-available/yii2-app /etc/nginx/sites-enabled/
```

Test the configuration and reload NGINX:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

#### Step 3: Disable Default NGINX Site (Optional but Recommended)

To avoid conflicts with the default NGINX welcome page:

```bash
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl reload nginx
```

#### Step 4: Access the Application

Now, navigate to the following URL in your browser:

```bash
http://<your-ec2-ip>
```

You should see the Yii2 application served through NGINX acting as a reverse proxy to the Docker container.

---

## 2. CI/CD with GitHub Actions

To automate deployment of the Yii2 application, we use GitHub Actions. The pipeline builds the Docker image, pushes it to DockerHub, and triggers a remote deployment (can be expanded with SSH + Ansible for full automation).

#### Step 1: Navigate to GitHub Actions and Create a New Workflow

- Go to your GitHub repository.
- Click on the **Actions** tab.
- Choose **"set up a workflow yourself"** or select the **PHP** template.
- Name the workflow file `deploy.yml`.

#### Step 2: Create the CI/CD Pipeline File (`.github/workflows/deploy.yml`)

This is the pipeline that we will be going to use: 

```bash
name: CI/CD Pipeline for Docker Swarm Deployment with Rollback

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: Build, Push Docker Image, Deploy to Swarm, and Rollback on Failure
    runs-on: ubuntu-latest

    env:
      IMAGE_NAME: nishankkoul/pearlthoughts-devops-assignment
      COMPOSE_FILE: docker-compose.yml
      SSH_PRIVATE_KEY: ${{ secrets.EC2_SSH_KEY }}
      SSH_USER: ${{ secrets.EC2_USER }}
      SSH_HOST: ${{ secrets.EC2_HOST }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Get Latest Image Tag
        id: latest_tag
        run: |
          tags=$(curl -s https://hub.docker.com/v2/repositories/${{ env.IMAGE_NAME }}/tags/?page_size=100 | jq -r '.results[].name')
          latest=$(echo "$tags" | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -n1)
          echo "Latest tag: $latest"
          echo "latest_tag=$latest" >> $GITHUB_ENV

      - name: Calculate New Tag
        id: new_tag
        run: |
          if [ -z "${{ env.latest_tag }}" ]; then
            new_tag="1.0"
          else
            new_tag=$(awk "BEGIN {printf \"%.1f\", ${{ env.latest_tag }} + 0.1}")
          fi
          echo "New tag: $new_tag"
          echo "new_tag=$new_tag" >> $GITHUB_ENV

      - name: Build Docker Image
        run: |
          docker build -t ${{ env.IMAGE_NAME }}:${{ env.new_tag }} .

      - name: Push Docker Image
        run: |
          docker push ${{ env.IMAGE_NAME }}:${{ env.new_tag }}

      - name: Update docker-compose.yml with New Image Tag
        run: |
          sed -i "s|${{ env.IMAGE_NAME }}:[0-9.]*|${{ env.IMAGE_NAME }}:${{ env.new_tag }}|" ${{ env.COMPOSE_FILE }}
          cat ${{ env.COMPOSE_FILE }}

      - name: Configure Git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add ${{ env.COMPOSE_FILE }}
          git commit -m "Update image tag to ${{ env.new_tag }} [skip ci]" || echo "No changes to commit"
          git remote set-url origin https://${{ secrets.GITHUB_TOKEN }}@github.com/nishankkoul/pearlthoughts-assignment.git
          git push origin main

      - name: SSH into EC2 and Deploy
        id: deploy_app
        uses: appleboy/ssh-action@v0.1.7
        continue-on-error: true
        with:
          host: ${{ env.SSH_HOST }}
          username: ${{ env.SSH_USER }}
          key: ${{ env.SSH_PRIVATE_KEY }}
          script: |
            set -e
            cd hello-world-yii2
            git pull origin main
            docker pull ${{ env.IMAGE_NAME }}:${{ env.new_tag }}
            docker stack deploy -c docker-compose.yml myapp

      - name: Rollback if Deployment Failed
        if: steps.deploy_app.outcome == 'failure'
        uses: appleboy/ssh-action@v0.1.7
        with:
          host: ${{ env.SSH_HOST }}
          username: ${{ env.SSH_USER }}
          key: ${{ env.SSH_PRIVATE_KEY }}
          script: |
            echo "Deployment failed! Rolling back to previous version..."
            cd hello-world-yii2
            sed -i "s|${{ env.IMAGE_NAME }}:[0-9.]*|${{ env.IMAGE_NAME }}:${{ env.latest_tag }}|" ${{ env.COMPOSE_FILE }}
            git checkout -- docker-compose.yml
            docker pull ${{ env.IMAGE_NAME }}:${{ env.latest_tag }}
            docker stack deploy -c docker-compose.yml myapp
            echo "Rollback to version ${{ env.latest_tag }} completed!"
```

This GitHub Actions pipeline automates the complete CI/CD process for deploying a Dockerized Yii2 application on a Docker Swarm cluster. When code is pushed to the main branch, the pipeline builds a new Docker image, tags it with an incremented version, pushes it to DockerHub, and updates the docker-compose.yml file with the new image tag. It then commits and pushes the updated file back to the repository. Next, the pipeline connects to an EC2 instance via SSH, pulls the new image, and deploys the application using Docker Swarm. If the deployment fails, it automatically rolls back to the previously working image version to ensure service continuity.

#### Step 3: Add GitHub Secrets

-> Go to your repository:

-> Click Settings → Secrets and variables → Actions.

-> Add the following secrets:

```bash
DOCKERHUB_USERNAME – your DockerHub username
DOCKERHUB_TOKEN – your DockerHub personal access token
EC2_SSH_KEY - private SSH Key to authenticate with the EC2 Instance
EC2_HOST - public IPv4 Address of the EC2 Instance
EC2_USER - what user should be used to perform actions inside the EC2 Instance
```

#### Step 4: Push and Trigger the Pipeline

Make any commit to the main branch and push:

```bash
git add .
git commit -m "Trigger deployment pipeline"
git push origin main
```

You can monitor the pipeline execution in the Actions tab on GitHub.

---  

## 3.  Infrastructure Automation with Ansible

Here are the steps for Infrastructure Automation with Ansible:

#### Step 1: Create a New EC2 Instance

Launch a new Ubuntu-based EC2 instance from the AWS Console. This instance will act as the Ansible control node and the target node (for this example, we are configuring the same machine).

#### Step 2: Install Ansible

SSH into the EC2 instance and install Ansible with the following commands:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install ansible -y
```

#### Step 3: Create the Ansible Playbook and NGINX Template

- Create a file named playbook.yml with your desired Ansible tasks (e.g., installing and configuring NGINX).

```bash
---
- hosts: localhost
  become: yes

  vars:
    ansible_connection: local
    project_dir: "/home/ubuntu/pearlthoughts-devops-assignment"  # Set the path to your Yii2 project

  tasks:
    - name: Install Docker, Docker Compose, Git, PHP, and NGINX
      apt:
        update_cache: yes
        name:
          - docker.io
          - docker-compose
          - git
          - nginx
          - php
          - php-fpm
          - php-xml
          - php-mbstring
        state: present

    - name: Start and enable Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Add user to docker group
      user:
        name: ubuntu
        groups: docker
        append: yes

    - name: Clone the Yii2 repository
      git:
        repo: "https://github.com/nishankkoul/pearlthoughts-assignment.git"
        dest: "{{ project_dir }}"
        version: main

    - name: Install Composer
      shell: |
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
      args:
        creates: /usr/local/bin/composer

    - name: Install PHP dependencies using Composer
      command: composer install
      args:
        chdir: "{{ project_dir }}"

    - name: Install yii2-bootstrap5 via Composer
      composer:
        command: require
        arguments: yiisoft/yii2-bootstrap5
        working_dir: "{{ project_dir }}"
      environment:
        COMPOSER_ALLOW_SUPERUSER: 1

    - name: Set alias for yii2-bootstrap5 in web.php
      lineinfile:
        path: "{{ project_dir }}/config/web.php"
        regexp: '/Yii::setAlias/'
        line: "Yii::setAlias('@yii2-bootstrap5', dirname(__DIR__) . '/vendor/yiisoft/yii2-bootstrap5');"
        insertafter: "components:"

    - name: Initialize Docker Swarm
      shell: |
        docker swarm init || true

    - name: Check Docker Swarm status
      shell: docker info | grep "Swarm"
      register: swarm_status
      changed_when: false

    - name: Debug Swarm status
      debug:
        var: swarm_status.stdout

    - name: Pull the latest Docker image
      shell: |
        docker pull nishankkoul/pearlthoughts-devops-assignment:2.4
      args:
        chdir: "{{ project_dir }}"

    - name: Deploy Stack (if you have a docker-compose.yml in your repo)
      shell: |
        docker stack deploy -c docker-compose.yml myapp
      args:
        chdir: "{{ project_dir }}"

    - name: Configure NGINX for Yii2 App
      template:
        src: "/home/ubuntu/nginx.conf.j2"
        dest: "/etc/nginx/sites-available/default"

    - name: Restart NGINX
      service:
        name: nginx
        state: restarted
```

- Create a Jinja2 template file nginx.conf.j2 that will be used to generate the actual NGINX configuration dynamically.

Create both the files in the same directory for example, '/home/ubutu'.

#### Step 4: Run the Ansible Playbook

Execute the playbook locally (since the target host is the same as the control host):

```bash
ansible-playbook playbook.yml
```

Make sure your playbook.yml specifies hosts: localhost and includes connection: local.

#### Step 5: Access the Application

Open a browser and go to:

```bash
http://<EC2-IP>
```

You should see your Yii2 application served via the host-level NGINX configured by Ansible.

---

## 4. Monitoring using Prometheus and Node Exporter

Now comes the final step, Monitoring using Prometheus and Node Exporter

#### Step 1: Installing and Set Up Prometheus

- Update System Packages:

```bash
sudo apt update && sudo apt upgrade -y
```

- Create Prometheus User and Group

```bash
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
```

- Create Required Directories

```bash
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
```

- Download and Extract Prometheus

```bash
wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz
tar vxf prometheus*.tar.gz
cd prometheus-2.43.0.linux-amd64/
```

- Move Binaries and Set Ownership

```bash
sudo mv prometheus /usr/local/bin
sudo mv promtool /usr/local/bin
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
```

- Move Configuration Files

```bash
sudo mv consoles /etc/prometheus
sudo mv console_libraries /etc/prometheus
sudo mv prometheus.yml /etc/prometheus
```

- Set Ownership for Configuration and Data

```bash
sudo chown prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /var/lib/prometheus
```

- Create a Systemd Service File

```bash
sudo vim /etc/systemd/system/prometheus.service
```

- Paste the following configuration into the file:

```bash
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
```

- Reload Systemd and Start Prometheus

```bash
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
```

- Check Prometheus Status

```bash
sudo systemctl status prometheus
```

- Access Prometheus Web UI

```bash
http://<your_server_ip>:9090  # Make sure to open port 9090 under inbound rules.
```

Prometheus should now be running and accessible through the web interface.

#### Step 2: Installing and Set up Node Exporter

Node Exporter is used to expose hardware and OS metrics like CPU, memory, disk, and network stats to Prometheus.

- Download and Extract Node Exporter

```bash
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvf node_exporter-1.6.1.linux-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64
```

- Move Binary and Set Permissions

```bash
sudo mv node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter
```

- Create a Systemd Service for Node Exporter

```bash
sudo vim /etc/systemd/system/node_exporter.service
```

- Create a Systemd Service for Node Exporter

```bash
sudo vim /etc/systemd/system/node_exporter.service
```

- Paste the following content:

```bash
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
```

- Reload Systemd and Start Node Exporter

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

- Verify Node Exporter Status

```bash
sudo systemctl status node_exporter
```

- Add Node Exporter to Prometheus Targets.

Edit the Prometheus configuration file:

```bash
sudo vim /etc/prometheus/prometheus.yml
```

Add the following under the scrape_configs section:

```yaml
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
```

Save and exit, then restart Prometheus:

```bash
sudo systemctl restart prometheus
```

- Confirm Node Exporter in Prometheus

Open your browser and go to:

```bash
http://<your_server_ip>:9090/targets 
```

You should see node_exporter under active targets.

---

## Conclusion

This DevOps assessment successfully showcases the deployment of a Yii2 PHP application using a modern, production-grade stack combining Docker Swarm, Ansible, GitHub Actions, and NGINX. The infrastructure is fully automated with Ansible, provisioning the EC2 environment with necessary services like Docker, NGINX, and PHP dependencies, while Docker Swarm ensures scalable and manageable container orchestration. CI/CD is efficiently implemented using GitHub Actions, enabling seamless integration and delivery workflows triggered by code changes. NGINX serves as a host-based reverse proxy, and the inclusion of Prometheus with Node Exporter provides a foundation for observability and monitoring. This setup demonstrates a well-integrated DevOps pipeline focused on automation, scalability, maintainability, and monitoring — essential for real-world cloud-native application deployments.
