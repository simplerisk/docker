FROM mysql/mysql-server:5.7.28
LABEL maintainer="SimpleRisk <support@simplerisk.com>"
ADD ./my.cnf /etc/my.cnf
ADD https://github.com/simplerisk/database/raw/master/simplerisk-en-20190930-001.sql /docker-entrypoint-initdb.d/script.sql
RUN chmod -R 775 /docker-entrypoint-initdb.d
