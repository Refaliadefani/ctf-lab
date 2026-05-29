FROM alpine:latest

RUN apk add --no-cache openssh bash

# Create analyst user with required credentials
RUN adduser -D -s /bin/bash analyst && \
    echo "analyst:blue_team_rocks" | chpasswd

# Configure SSH
RUN ssh-keygen -A && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "AllowUsers analyst" >> /etc/ssh/sshd_config

# Create logs directory for read access
RUN mkdir -p /opt/admin/logs

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
