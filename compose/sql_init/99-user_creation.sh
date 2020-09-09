#!/bin/bash
set -e

if [ -z $SIMPLERISK_DB_PASS ]; then
  SIMPLERISK_DB_PASS=`pwgen -cn 20 1`
  echo "Generated Simplerisk Password: `echo $SIMPLERISK_DB_PASS`"
else
  echo "Using provided password"
fi

mysql --protocol=socket -uroot -p$MYSQL_ROOT_PASSWORD <<EOSQL
CREATE USER 'simplerisk'@'%' IDENTIFIED BY '${SIMPLERISK_DB_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'%'; 
EOSQL
