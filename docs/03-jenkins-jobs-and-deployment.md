# 03 — Jenkins Freestyle Jobs and Docker Deployment

[← Home](../README.md) · [← SSH agent](02-ssh-and-agent.md) · [Next: Troubleshooting →](04-troubleshooting.md)

## A. Configure Docker access on the agent

The SSH-launched agent executes as `ubuntu`; the Docker CLI needs access to `/var/run/docker.sock`.

On the agent:

```bash
getent group docker
sudo usermod -aG docker ubuntu
id ubuntu
```

**Disconnect and relaunch the Jenkins node** so the running SSH agent process receives updated supplementary groups. Test under the new agent connection:

```bash
docker --version
docker ps
```

**Security warning:** Docker group membership provides root-equivalent privileges. This is for the isolated lab only. See [Docker post-install docs](https://docs.docker.com/engine/install/linux-postinstall/).

## B. Test that jobs run on the agent

From Jenkins controller UI:

1. **New Item** → `test-slave-connection` → **Freestyle project**.
2. In General, check **Restrict where this project can be run**.
3. Label expression: `docker-slave`.
4. **Build Steps → Execute shell**: paste the following.
5. Save → **Build Now** → **Console Output**.

```sh
echo 'Jenkins Slave Connection Test'
hostname
whoami
pwd
```

The observed **#1** test build proved `Building remotely on docker-slave`, user `ubuntu`, agent workspace and `Finished: SUCCESS`.

Then replace the shell commands with the Docker access test:

```sh
echo 'Testing Docker on Slave'
whoami
docker --version
docker ps
```

The observed **#2** test build returned `Docker version 29.9.2`, an initially empty `docker ps` list and `Finished: SUCCESS`.

> Jenkins console text `Running as SYSTEM` describes its *internal security identity*; the Linux shell's `whoami` confirmed `ubuntu`.

## C. Deploy official Nginx image

1. **New Item** → `nginx-docker-deployment` → **Freestyle project**.
2. **Restrict where this project can be run** → `docker-slave`.
3. Under **Build Steps**, select **Execute shell**.
4. Paste the contents of [`../scripts/deploy-nginx.sh`](../scripts/deploy-nginx.sh), or its equivalent inline commands below.
5. Save → **Build Now** → **Console Output**.

```sh
set -e

echo 'Deploying Nginx on Jenkins Slave'
docker pull nginx:1.30.6

if docker container inspect jenkins-nginx >/dev/null 2>&1; then
    docker container rm --force jenkins-nginx
fi

docker run -d \
    --name jenkins-nginx \
    -p 8081:80 \
    nginx:1.30.6

docker ps
curl --fail --head http://127.0.0.1:8081/
```

The repository's [`deploy-nginx.sh`](../scripts/deploy-nginx.sh) uses the same logic plus **HTTP retries** to tolerate small startup delays. If entering the script in a Jenkins shell field, `set -e` and POSIX-compatible commands work with its `/bin/sh` launcher; a file executed via `bash scripts/deploy-nginx.sh` uses its Bash shebang.

### Why `nginx:1.30.6`?

It is a **version-specific, official, stable-series Nginx tag** verified in the [Docker Official Image manifest](https://github.com/docker-library/official-images/blob/master/library/nginx) and [Docker Hub](https://hub.docker.com/_/nginx). `nginx:stable` is also official, but moves as stable releases change. A fixed tag does **not** guarantee immutable bytes; use a verified SHA256 digest for immutable pinning.

### Command reference

| Command | Purpose |
| --- | --- |
| `docker pull` | Fetch the image from a registry |
| `docker container inspect` | Check whether a previous named container exists |
| `docker container rm --force` | Remove a previous container before recreation; causes brief downtime |
| `docker run -d --name ... -p 8081:80` | Start in background; map **agent host TCP/8081** to **container TCP/80** |
| `docker ps` | List running containers |
| `curl --fail --head http://127.0.0.1:8081/` | Verify HTTP headers locally, failing on HTTP errors |

**Port security:** without a host IP specified, Docker publishes the mapped port on all interfaces by default. Restrict public reachability using the agent's AWS security group. The app is not served from the controller.

## D. Verify in your browser

On agent:

```bash
docker ps --filter name=jenkins-nginx
curl -I http://127.0.0.1:8081/
```

Then, from your approved client:

```text
http://<AGENT_PUBLIC_IP>:8081
```

The supplied browser screenshot shows the Nginx welcome page on port 8081.

![Final Nginx website output](../assets/screenshots/06-nginx-browser.png)

## Not implemented yet

Git webhooks, a `Jenkinsfile`, code checkout, tests, artifact packaging, rollback and GitHub-triggered deployments were **not performed** in this lab. Do not label the result an end-to-end CI/CD pipeline.
