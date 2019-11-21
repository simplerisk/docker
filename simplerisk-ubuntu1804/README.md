# Simplerisk in Docker

- `git clone https://github.com/simplerisk/docker.git simplerisk-docker && cd simplerisk-docker`
- Populate the .env file with the relevant secrets and keys (keys will need line endings to be replaced with '\n'; literally the backslash then n rather than escape-n which is a newline). If you need help with this run ``docker build -t simplerisk-bootstrap:latest ./bootstrap && docker run -v `pwd`/data/bootstrap:/bootstrap simplerisk-bootstrap:latest`` and then copy `data/bootstrap/.env` to `.env`)
- `docker-compose up -d` to run in daemon mode (detached shell)
- Visit [https://localhost:8443](https://localhost:8443) for Simplerisk, you'll have to accept a self-signed certificate. The username is `admin` and the password `admin`
- See the database using phpMyAdmin at [https://localhost:8081](https://localhost:8081)

## Troubleshooting

- To wipe everthing and start again `rm -Rf ./data`
- Shell into the app container with: ``docker exec -ti `docker ps | grep 'simplerisk-www' | cut -d " " -f1` /bin/bash``
- For a completely insecure installation (because everyone knows the secrets) you can use the example env file `.env.example` by copying it: `cp .env.example .env`

## Building the images independantly of `docker-compose`

- Simplerisk: `docker build -t simplerisk-www:latest ./simplerisk`
- Database: `docker build -t simplerisk-db:latest ./database`
- phpMyAdmin doesn't need building but you can fetch the image locally using `docker pull phpmyadmin/phpmyadmin:4.8`
