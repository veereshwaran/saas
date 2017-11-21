ARG VERSION

FROM hub.appranix.net/onprem/director:$VERSION

WORKDIR /home/prana/

ADD circuit-appranix-saas-1.tar.xz /home/prana/inductor/circuit-appranix-saas-1
