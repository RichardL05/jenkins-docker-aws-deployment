# 04 — Troubleshooting Case Study (Actual Incidents)

[← Home](../README.md) · [← Jobs](03-jenkins-jobs-and-deployment.md) · [Next: Validation →](05-validation-and-cleanup.md)

This section records **errors actually encountered**, along with relevant commands and the eventual working state. Values shown in commands use placeholders to protect the instance's private addressing.

## Incident 1 — SSH private-key filename did not exist

**Error**

```text
Warning: Identity file /var/lib/jenkins/.ssh/jenkins_slave not accessible: No such file or directory.
Permission denied (publickey).
```

**Cause** — The generated RSA key had been named `jenkins_slave_rsa`, but the SSH test referred to an older suggested name `jenkins_slave`. The missing file prevented SSH from using the intended private key.

**Fix** — Verify the file and select the actual key:

```bash
sudo ls -l /var/lib/jenkins/.ssh/
sudo -u jenkins ssh -o IdentitiesOnly=yes \
  -i /var/lib/jenkins/.ssh/jenkins_slave_rsa \
  ubuntu@<AGENT_PRIVATE_IP>
```

The filename fix alone did **not** resolve the next issue.

## Incident 2 — RSA public key did not match

**Symptoms** — SSH continued to return `Permission denied (publickey)`. Agent-side log also contained an EC2 Instance Connect `AuthorizedKeysCommand ... failed, status 22` message; that line by itself did **not** prove a local `authorized_keys` mismatch.

**Evidence** — The controller's new RSA public key measured **4096 bits**, while the public key found in agent `authorized_keys` measured **2048 bits**, and their **SHA256 fingerprints differed**.

**Diagnosis**

```bash
# Controller
sudo ssh-keygen -lf /var/lib/jenkins/.ssh/jenkins_slave_rsa.pub

# Agent
ssh-keygen -lf /home/ubuntu/.ssh/authorized_keys
```

**Root cause** — Two **distinct RSA key pairs**, not key size conversion. The correct controller-generated 4096-bit RSA public key was missing from the agent user's authorized keys.

**Resolution** — Copied the entire `.pub` key from controller to agent `/home/ubuntu/.ssh/authorized_keys` on its own line while retaining existing EC2 login keys. Applied ownership and permissions:

```bash
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh
sudo chmod 700 /home/ubuntu/.ssh
sudo chmod 600 /home/ubuntu/.ssh/authorized_keys
```

**Verification** — Matching fingerprint appeared; controller successfully connected as `ubuntu` to the agent's **private** IP without a password.

> RSA 4096-bit keys **do not become RSA 2048-bit keys during SSH or copying**. `authorized_keys` can contain several independent authorized public keys.

## Incident 3 — Jenkins agent marked offline for temp-space threshold

**Warning in UI**

```text
Disk space is below threshold of 1.00 GiB.
Only 952.41 MiB ... left on /tmp.
```

**Check on agent**

```bash
df -hT /tmp
```

Observed values:

```text
Filesystem  Type   Size   Used  Avail  Use%  Mounted on
tmpfs       tmpfs  953M   164K  953M   1%   /tmp
```

**Root cause** — `/tmp` was an almost-empty memory-backed `tmpfs` with less **total** free capacity than the Jenkins **default monitoring threshold of 1 GiB**. This was **not** a 99%-full disk and not an SSH issue.

**Resolution** — Under **Manage Jenkins → Nodes → docker-slave → Configure → Node Properties → Disk Space Monitoring Thresholds**, use a reduced **Free Temp Space Threshold** appropriate for an isolated lab (e.g. `256MiB`, with warning threshold `512MiB`), save, and click **Bring this node back online**. More storage/appropriate sizing is preferable in production.

**Verification** — Jenkins agent monitoring data became visible and the **Disconnect** action was available; subsequent Jenkins Freestyle jobs ran successfully.

**Unrelated observation** — `Free Swap Space: 0 B` was shown in red on the monitoring dashboard. It is not proof that swap exhaustion caused this temporary-space offline state.

## Incident 4 — Docker daemon access for remote jobs

**Requirement** — The agent connects via SSH as `ubuntu`, but Docker's UNIX socket is not generally available to a standard user by default.

**Change applied as part of lab setup**

```bash
sudo usermod -aG docker ubuntu
id ubuntu
```

Then reconnect the Jenkins agent to refresh its supplementary groups.

**Verification** — Jenkins build #2 executed `docker --version` and `docker ps` without `sudo` and returned `Finished: SUCCESS`. **A `permission denied` Docker error was not captured** in the supplied console output, so we do not invent one.

**Risk** — Docker's official docs warn that `docker` group membership grants root-level privileges. Use a disposable isolated agent and avoid this arrangement on shared production hosts.

## Evidence images

- [Offline monitoring warning](../assets/screenshots/04-temp-threshold-warning.png)
- [Temp space filesystem output](../assets/screenshots/05-tmpfs-evidence.png)
- [Agent online](../assets/screenshots/01-agent-online.png)
- [Remote job succeeded](../assets/screenshots/02-remote-job-success.png)
- [Docker CLI worked from Jenkins](../assets/screenshots/03-docker-access-success.png)
