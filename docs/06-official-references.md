# 06 — Official Documentation and Sources

[← Home](../README.md)

**Verified for this write-up: 23 October 2026.** Product versions and UI labels evolve; prefer these vendor-owned pages when repeating the lab.

| Topic | Official source |
| --- | --- |
| Jenkins Ubuntu/Linux installation | https://www.jenkins.io/doc/book/installing/linux/ |
| Jenkins distributed agents | https://www.jenkins.io/doc/book/using/using-agents/ |
| Jenkins SSH Build Agents plugin (`ssh-slaves`) | https://plugins.jenkins.io/ssh-slaves/ |
| Docker Engine installation on Ubuntu | https://docs.docker.com/engine/install/ubuntu/ |
| Docker Linux post-installation / group permissions | https://docs.docker.com/engine/install/linux-postinstall/ |
| Docker CLI `docker run` / port publishing | https://docs.docker.com/reference/cli/docker/container/run/ |
| Docker `pull` | https://docs.docker.com/reference/cli/docker/image/pull/ |
| Docker `container inspect` | https://docs.docker.com/reference/cli/docker/container/inspect/ |
| Docker `container rm` | https://docs.docker.com/reference/cli/docker/container/rm/ |
| Docker Official Nginx image | https://hub.docker.com/_/nginx |
| Official Nginx supported tags (`1.30.6`, `stable`) | https://github.com/docker-library/official-images/blob/master/library/nginx |
| AWS security-group referencing/rules | https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html |

## Verification notes

- The Docker Official Images manifest includes `1.30.6` and `stable` for Nginx's stable Debian image in its published tag list.
- The SSH Build Agents plugin's display name differs from its retained plugin ID, `ssh-slaves`.
- The AWS private-IP SSH path requires a valid private network route and compatible SG rules; simply putting instances on EC2 is insufficient.
- A Docker group user can effectively control the host. This design is for a dedicated training agent, not an unrestricted shared worker.
