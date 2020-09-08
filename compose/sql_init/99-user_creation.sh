#!/bin/bash
set -e

if [ -z $SIMPLERISK_DB_PASS ]; then
  pwgen -cn 20 1 > /tmp/pass_simplerisk.txt
  SIMPLERISK_DB_PASS=`cat /tmp/pass_simplerisk.txt`
fi

mysql --protocol=socket -uroot -p$MYSQL_ROOT_PASSWORD <<EOSQL
CREATE USER 'simplerisk'@'%' IDENTIFIED BY '${SIMPLERISK_DB_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'%'; 
EOSQL
