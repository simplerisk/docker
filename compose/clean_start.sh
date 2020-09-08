#!/bin/bash

SCHEMA_FILE=sql_init/98-simplerisk_schema.sql

# Download script
if command -v wget &> /dev/null
then
    wget -qO- https://github.com/simplerisk/database/raw/master/simplerisk-en-20200711-001.sql > $SCHEMA_FILE
elif command -v curl &> /dev/null
then
    curl -sL https://github.com/simplerisk/database/raw/master/simplerisk-en-20200711-001.sql > $SCHEMA_FILE
else
    echo "(wget|curl) is required"
    exit 1
fi

sed -i '1s/^/USE simplerisk; \n/' $SCHEMA_FILE

if command -v docker-compose &> /dev/null
then
    docker-compose up
# Do check with docker swarm
else
    echo "Docker (compose|swarm) is needed"
fi
