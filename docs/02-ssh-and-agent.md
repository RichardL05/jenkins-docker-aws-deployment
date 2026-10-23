# 02 — SSH Keys, Jenkins Credentials and Agent Registration

[← Home](../README.md) · [← Infrastructure](01-infrastructure-setup.md) · [Next: Jobs →](03-jenkins-jobs-and-deployment.md)

## A. Generate an RSA key *as the Jenkins service user* on the controller

The completed lab used a **4096-bit RSA** key pair and the filename `jenkins_slave_rsa`:

```bash
sudo -u jenkins mkdir -p /var/lib/jenkins/.ssh
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh

sudo -u jenkins ssh-keygen -t rsa -b 4096 \
  -f /var/lib/jenkins/.ssh/jenkins_slave_rsa -N ''

sudo ls -l /var/lib/jenkins/.ssh/
```

- Private key: `/var/lib/jenkins/.ssh/jenkins_slave_rsa` — **never commit or send**.
- Public key: `/var/lib/jenkins/.ssh/jenkins_slave_rsa.pub` — copy to the agent.
- `-t rsa`: RSA algorithm; `-b 4096`: 4096-bit modulus; `-f`: path; `-N ''`: no passphrase (lab automation only).

For a production environment, prefer an organization-approved key type, credential policies and secret lifecycle. Do not assume RSA is inherently superior to Ed25519.

## B. Authorize the public key on the agent

On the controller, display **only** the public key:

```bash
sudo cat /var/lib/jenkins/.ssh/jenkins_slave_rsa.pub
```

On the agent, log in as `ubuntu` (using your existing EC2 admin access):

```bash
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
nano /home/ubuntu/.ssh/authorized_keys
# Paste controller's *public* key on its own line; keep existing login key(s).
chmod 600 /home/ubuntu/.ssh/authorized_keys
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh
```

**Correctly troubleshoot key mismatches by fingerprint**, not by key size alone:

```bash
# Controller
sudo ssh-keygen -lf /var/lib/jenkins/.ssh/jenkins_slave_rsa.pub

# Agent
ssh-keygen -lf /home/ubuntu/.ssh/authorized_keys
```

A matching fingerprint must appear among the agent's authorized keys. The project originally had a different RSA 2048-bit authorized key; it was **not a converted** version of the new RSA 4096-bit key.

## C. Connect from controller through the private network

Make sure agent SG allows TCP/22 inbound from controller SG; check controller TCP/22 egress if restricted.

```bash
sudo -u jenkins ssh -o IdentitiesOnly=yes \
  -i /var/lib/jenkins/.ssh/jenkins_slave_rsa \
  ubuntu@<AGENT_PRIVATE_IP>
```

Verify the *agent SSH host key fingerprint* before trusting the first connection; this is different from the user's RSA **authentication** key fingerprint. A verified first connection typically writes the host key to the Jenkins user's `known_hosts` file. Use `exit` to leave the agent.

## D. Create Jenkins SSH credential

Jenkins Dashboard → **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**:

| Field | Value |
| --- | --- |
| Kind | **SSH Username with private key** |
| Username | `ubuntu` |
| Private key | **Enter directly**; paste controller's private key securely into Jenkins UI |
| Passphrase | Blank, because `-N ''` was used |
| ID | `slave-ssh-key` |
| Description | `Jenkins controller to agent SSH` |

For this lab, the private key can be displayed locally via:

```bash
sudo cat /var/lib/jenkins/.ssh/jenkins_slave_rsa
```

**Do not take a screenshot of its contents; do not include it in this repository.** The Jenkins Credentials store must be access-controlled and backed up securely.

## E. Prepare the agent filesystem

On the agent, while logged in as `ubuntu`:

```bash
mkdir -p /home/ubuntu/jenkins-agent
java -version
```

## F. Register agent in Jenkins

Jenkins Dashboard → **Manage Jenkins → Nodes → New Node** → Name `docker-slave` → **Permanent Agent**.

| Setting | Value |
| --- | --- |
| Executors | `1` |
| Remote root | `/home/ubuntu/jenkins-agent` |
| Labels | `docker-slave` |
| Usage | Only build jobs with label expressions matching this node |
| Launch method | Launch agents via SSH |
| Host | `<AGENT_PRIVATE_IP>` (**private**, not public) |
| Credentials | `slave-ssh-key` |
| Port | `22` |
| Host Key Verification Strategy | Known hosts file Verification Strategy |
| Availability | Keep this agent online as much as possible |

Save and check **Nodes → docker-slave → Log**. The connection succeeded in this lab, and later console jobs proved it could run remote shell commands.

For dedicated-controller practice, set the built-in controller node's executor count to `0` so your application builds run only on agents. Be sure at least one eligible agent exists for jobs you run.

Read the official [Jenkins agent guide](https://www.jenkins.io/doc/book/using/using-agents/) and [SSH Build Agents plugin](https://plugins.jenkins.io/ssh-slaves/).
