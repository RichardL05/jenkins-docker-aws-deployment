# 01 — Infrastructure and Tool Installation

[← Home](../README.md) · [Next: SSH and agent →](02-ssh-and-agent.md)

## Architecture prerequisites

Two Ubuntu EC2 instances with private IP connectivity, usually in one VPC:

| Host | Role | Installed components |
| --- | --- | --- |
| `master` | Jenkins **controller** | Ubuntu Linux, Java 21, Jenkins LTS service, Docker Engine |
| `slave` | Jenkins **agent** | Ubuntu Linux, Java 21, Docker Engine, SSH server; **no full Jenkins server installation** |

The hostnames are explanatory labels; the agent's actual Jenkins node name is `docker-slave`. Instance types, Ubuntu release, and exact public IPs are intentionally omitted (not recorded for this project).

## Suggested EC2 security groups

| Instance | Direction | TCP port | Narrowest practical source/destination |
| --- | --- | --- | --- |
| Controller | Inbound | 22 | Your admin public IP `/32` (only if direct SSH administration is needed) |
| Controller | Inbound | 8080 | Your admin public IP `/32` (lab Jenkins UI; not the open internet) |
| Controller | Outbound | 22 | Agent SG, if outbound is not already permitted |
| Agent | Inbound | 22 | **Controller security group ID**; plus your admin IP if separately needed |
| Agent | Inbound | 8081 | Your admin public IP `/32` for browser validation |
| Both | Outbound | 443 / DNS | Only destinations required for package/image downloads, subject to your network rules |

AWS Security Groups are stateful. Referencing the controller security group for agent TCP/22 allows private traffic from controllers in that group when the topology supports security-group referencing.

**Do not require inbound TCP/2375 or 2376:** Docker here is accessed locally by the agent user; no remote Docker API is exposed.

## Controller: Java + Jenkins

Commands used for Ubuntu APT-based installation follow the official [Jenkins Linux guide](https://www.jenkins.io/doc/book/installing/linux/).

```bash
sudo apt update
sudo apt install -y fontconfig openjdk-21-jre wget
java -version

sudo install -m 0755 -d /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' | \
  sudo tee /etc/apt/sources.list.d/jenkins.list

sudo apt update
sudo apt install -y jenkins
sudo systemctl enable --now jenkins
sudo systemctl status jenkins
```

Open `http://<CONTROLLER_PUBLIC_IP>:8080` from your approved admin IP and unlock Jenkins. The initial password **must not be published**; retrieve it locally with:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Install suggested plugins and complete the administrator setup. The **SSH Build Agents** plugin (`ssh-slaves` plugin ID) was already installed/enabled in this lab.

## Controller and agent: Docker Engine

These commands reproduce the Docker **official Ubuntu APT repository** method ([Docker documentation](https://docs.docker.com/engine/install/ubuntu/)). Run on **both** instances.

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo systemctl status docker
sudo docker run --rm hello-world
```

> **Before installation:** Docker officially recommends checking/removing **conflicting distro Docker packages** (`docker.io`, `podman-docker`, etc.) if present. Do not blindly remove packages on a populated server. See [official prerequisites](https://docs.docker.com/engine/install/ubuntu/).

On the **agent**, also ensure Java 21 is installed:

```bash
sudo apt update
sudo apt install -y fontconfig openjdk-21-jre
java -version
```

Checks:

```bash
docker --version
sudo docker ps
```

Observed in the lab's agent job log: `Docker version 29.9.2`. Ubuntu patch version and Java patch release were not captured.

## Why Docker on the controller?

It was installed to meet this lab's stated setup requirement. **The demonstrated deployment does not use the controller's Docker daemon.** The Freestyle job is restricted to the agent and invokes the agent's local Docker daemon.
