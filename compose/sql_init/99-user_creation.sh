#!/bin/bash
set -e

echo $SIMPLERISK_PASS

mysql --protocol=socket -uroot -p$MYSQL_ROOT_PASSWORD <<EOSQL
CREATE USER 'simplerisk'@'%' IDENTIFIED BY '${SIMPLERISK_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON simplerisk.* TO 'simplerisk'@'%'; 
EOSQL