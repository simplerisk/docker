# Simplerisk Image

This image tries to transform Simplerisk into a more microservices approach by using a container based on PHP:7.2-apache and with the specific capability of setting properties of the config.php file through environment variables.

## How to build this image?

Please run the following command according to your container engine:
- **Docker**: `docker build -t simplerisk/simplerisk:php7.2-apache`
- **Podman**: `podman build -t simplerisk/simplerisk:php7.2-apache`

## Environment variables

### FIRST_TIME_SETUP

This indicates if the database is going to be set up from zero. This means installing the necessary schema and creating the user, in case there is any setup. Requires `FIRST_TIME_SETUP_USER` and `FIRST_TIME_SETUP_USER_PASS`. As long it is a non-null value, it will run. By default, it assumes everything is already set up.

### FIRST_TIME_SETUP_ONLY

This indicates if the container will only be used to configure the database, and will exit after finishing it. As long it is a non-null value, it will run. By default, it will let the container alive.

### FIRST_TIME_SETUP_USER and FIRST_TIME_SETUP_PASS

Credentials for the privileged user that will be used to install the schema on the database. Default value for both is `root`.

### FIRST_TIME_SETUP_WAIT

This is the time, in seconds, the application is going to wait to set up the installation, in case the database is being loaded at the same time. It works together with `FIRST_TIME_SETUP`. Default value is `20`.

### SIMPLERISK_DB_HOSTNAME

This will replace the content of the DB_HOSTNAME property, which is where Simplerisk should look for a database. Default value is `localhost`.

### SIMPLERISK_DB_PORT

This will replace the content of the DB_PORT property, which is where Simplerisk will look for a database port  to connect. Default value is `3306`.

### SIMPLERISK_DB_USERNAME

This will replace the content of the DB_USERNAME property, which is the username to be used to connect to the database. Default value is `simplerisk`.

### SIMPLERISK_DB_PASSWORD

This will replace the content of the DB_PASSWORD property, which is the password to be used to connect to the database. Default value is `simplerisk`.

### SIMPLERISK_DB_DATABASE

This will replace the content of the DB_DATABASE property, which is the name of the database to connect. Default value is `simplerisk`.

### SIMPLERISK_DB_FOR_SESSIONS

This will replace the content of the USE_DATABASE_FOR_SESSIONS property, which if marked as true, will store all sessions on the configured database. Default value is `true`. 

### SIMPLERISK_DB_SSL_CERT_PATH

This will replace the content of the DB_SSL_CERTIFICATE_PATH property, which is the path where the SSL certificates to access the database are located. Default is empty (`''`).