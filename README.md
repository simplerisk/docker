# Official SimpleRisk Docker images

These images are available on [DockerHub](https://hub.docker.com/u/simplerisk).

## Images Overview 
- [`simplerisk`](https://github.com/wolfangaukang/docker/tree/master/simplerisk): Contains all necessary components to make a SimpleRisk instance work (LAMP stack and mail utilities).
- [`simplerisk-minimal`](https://github.com/wolfangaukang/docker/tree/master/simplerisk-minimal): Only packs components for the SimpleRisk application. You will need to connect it with an external database.

## Using Docker Compose/Swarm

A `docker-compose.yml` file is provided for a stack deployment of the application on Docker Compose, while `docker-stack.yml` is for Docker Swarm. It will deploy the application with the following components:
- [SimpleRisk Application](https://hub.docker.com/r/wolfangaukang/simplerisk-minimal) (`simplerisk-minimal`)
- [MariaDB Database](https://hub.docker.com/_/mariadb) (version 10.4)
- [SMTP Server](https://hub.docker.com/r/namshi/smtp)

Change its settings according to your needs.

[![Try in PWD](https://raw.githubusercontent.com/play-with-docker/stacks/master/assets/images/button.png)](https://labs.play-with-docker.com/?stack=https://raw.githubusercontent.com/WolfangAukang/docker/master/docker-stack.yml)

## Build it yourself

Click on the image name on the [Images Overview](#images-overview) section for more details.
