# SimpleRisk Minimal Image

This image is intended to run SimpleRisk in a 'microservices' approach (database is not included). **It is not intended to run standalone, unless a database is configured with the SimpleRisk schema and the connection is properly set up**.

It uses PHP 7.X with Apache as a base image. Also has the capability of setting properties of the `config.php` file through environment variables. 

## Build

Follow these instructions:

```
git clone https://github.com/wolfangaukang/docker
cd simplerisk-minimal
VERSION=7.X
docker build -f php$VERSION/Dockerfile -t simplerisk/simplerisk-minimal:$VERSION .
```

## Ways to run the application

### Run the application normally

If the database is already set up for SimpleRisk to use it, run the container without the `FIRST_TIME_SETUP` variables.

For example, if the database is located at `db-server.example.com`, the command to run the container would be:

```
docker run --name simplerisk -e SIMPLERISK_DB_HOST=db-server.example.com -p 80:80 -p 443:443 simplerisk-minimal
```

### Set up database (Optional)

If this is the first time running the application, the MySQL/MariaDB database needs to be set up with the SimpleRisk schema. For this, please provide the environment variable `FIRST_TIME_SETUP` and optionally provide any of the variables that start with `FIRST_TIME_SETUP_*` to customize the set up.

To only set up the database and discard the container afterwards, use the `FIRST_TIME_SETUP_ONLY` variable. This might be helpful in a situation where you only want to configure the database (like a initContainer on Kubernetes) and, if the process ran successfully, execute a new container with SimpleRisk running normally.

Another detail to consider is that if the database set up is being executed and the `SIMPLERISK_DB_PASSWORD` variable is not provided, the application will generate a random password and show it on the container logs.


## Environment variables

| Variable Name | Default Value | Purpose |
|:-------------:|:-------------:|:--------|
| `FIRST_TIME_SETUP` | `null` (Accepts any value) | Enables the database setup feature |
| `FIRST_TIME_SETUP_ONLY` | `null` (Accepts any value) | If enabled, it will discard the container after finishing the database setup |
| `FIRST_TIME_SETUP_USER` | `root` | User name of database privileged user to install SimpleRisk schema and other components |
| `FIRST_TIME_SETUP_PASS` | `root` | Password for database privileged user to install SimpleRisk schema and other components |
| `FIRST_TIME_SETUP_WAIT` | 20 | Time, in seconds, the application is going to wait to set up the database. Useful if you are deploying the database and SimpleRisk at the same time |
| `SIMPLERISK_DB_HOSTNAME` | `localhost` | Hostname of the database server |
| `SIMPLERISK_DB_PORT` | 3306 | Port to contact the database |
| `SIMPLERISK_DB_USERNAME` |`simplerisk` | User name to be used to access the SimpleRisk database |
| `SIMPLERISK_DB_PASSWORD` | `simplerisk` | Password to be used to access the SimpleRisk database. If not provided while setting up the database, a random password will be generated and shown on the container logs |
| `SIMPLERISK_DB_DATABASE` | `simplerisk` | Database name where all SimpleRisk objects are stored |
| `SIMPLERISK_DB_FOR_SESSIONS` | `true` | Indicator that the application will store all sessions on the configured database |
| `SIMPLERISK_DB_SSL_CERT_PATH` | Empty string (`''`) | Path where SSL certificates, to contact the database, are located |
