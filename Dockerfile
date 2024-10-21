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
