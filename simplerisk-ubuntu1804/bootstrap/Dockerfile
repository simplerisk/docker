FROM ubuntu:bionic
LABEL maintainer="SimpleRisk <support@simplerisk.com>"
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends apt-utils && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install pwgen openssl
ADD ./generate.sh /generate.sh
CMD ["/bin/bash", "/generate.sh"]
