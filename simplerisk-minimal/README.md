# SimpleRisk Minimal Image

This image is intended to run SimpleRisk in a 'microservices' approach (database is not included). It uses PHP 7.X with Apache as a base image. Also has the capability of setting properties of the `config.php` file through environment variables.

For any of the executions, it is recommended to map the 80 and 443 ports to be able to access the application.

## Build

To build this image, run the following commands:

```
# From the root directory of the repository
cd simplerisk-minimal
VERSION=7.X
docker build -f php$VERSION/Dockerfile -t simplerisk/simplerisk-minimal:$VERSION .
```

## Run 

There are two ways to run this container:

### Database Setup (Optional)

If this is the first time running the application, the MySQL/MariaDB database needs to be set up with the SimpleRisk schema. You have two options to set it up:

#### New Installer (GUI)

Since the `20220306-001` release, SimpleRisk offers a graphical installation method. You will need to run the container the following way:
```
docker run -d --name simplerisk -e DB_SETUP=manual -p 80:80 -p 443:443 simplerisk/simplerisk-minimal
```

#### Docker Setup (CLI)

You must provide the environment variable `DB_SETUP=automatic|automatic-only` and optionally provide any of the variables from the **Environment variables** section that start with `AUTO_DB_SETUP_*` to customize the setup. The only difference between the `DB_SETUP` values shown before is that `automatic` will configure the database and leave the container running until it stops, while `automatic-stop` will stop the container after configuring the database. The latter might be helpful in a situation where you only want to configure the database.

Another detail to consider is that if the database set up is being executed and the `SIMPLERISK_DB_PASSWORD` variable is not provided, the application will generate a random password and show it on the container logs.

The way to run the container on this mode are the following:
```
# Automatic setup (set database and keep running)
docker run -d --name simplerisk -e DB_SETUP=automatic -e AUTO_DB_SETUP_PASS=test -e SIMPLERISK_DB_HOSTNAME=172.17.0.2 -p 80:80 -p 443:443 simplerisk/simplerisk-minimal

# Automatic-only setup (set database and stop container)
docker run -d --name simplerisk -e DB_SETUP=automatic-only -e AUTO_DB_SETUP_PASS=test -e SIMPLERISK_DB_HOSTNAME=172.17.0.2 -p 80:80 -p 443:443 simplerisk/simplerisk-minimal
```

### Normal execution

If the database is already set up for SimpleRisk to use it, run the container by just providing the `SIMPLERISK_DB_*` options. For example, if the database is located at `db-server.example.com` on port 45329, the command to run the container would be:
```
docker run -d --name simplerisk -e SIMPLERISK_DB_PASSWORD=pass -e SIMPLERISK_DB_HOSTNAME=db-server.example.com -e SIMPLERISK_DB_PORT=45329 -p 80:80 -p 443:443 simplerisk/simplerisk-minimal
```

## Environment variables

| Variable Name | Default Value | Purpose |
|:-------------:|:-------------:|:--------|
| `DB_SETUP` | `null` (Accepts any value) | The container will start as if the database has not been set up. The valid options here are `automatic` (in case you want the container to configure the database), `automatic-only` (the same as `automatic`, but stops the container after finishing the setup) or `manual` (allows the user to run the manual setup) |
| `AUTO_DB_SETUP_USER` | `root` | Used when `DB_SETUP=automatic|automatic-only`. User name of database privileged user to install SimpleRisk schema and other components |
| `AUTO_DB_SETUP_PASS` | `root` | Used when `DB_SETUP=automatic|automatic-only`. Password for database privileged user to install SimpleRisk schema and other components |
| `AUTO_DB_SETUP_WAIT` | 20 | Used when `DB_SETUP=automatic|automatic-only`. Time, in seconds, the application is going to wait to set up the database. Useful if you are deploying the database and SimpleRisk at the same time |
| `SIMPLERISK_DB_HOSTNAME` | `localhost` | Hostname of the database server |
| `SIMPLERISK_DB_PORT` | 3306 | Port to contact the database |
| `SIMPLERISK_DB_USERNAME` |`simplerisk` | User name to be used to access the SimpleRisk database |
| `SIMPLERISK_DB_PASSWORD` | `simplerisk` | Password to be used to access the SimpleRisk database. If not provided while setting up the database, a random password will be generated and shown on the container logs |
| `SIMPLERISK_DB_DATABASE` | `simplerisk` | Database name where all SimpleRisk objects are stored |
| `SIMPLERISK_DB_FOR_SESSIONS` | `true` | Indicator that the application will store all sessions on the configured database |
| `SIMPLERISK_DB_SSL_CERT_PATH` | Empty string (`''`) | Path where SSL certificates, to contact the database, are located |
