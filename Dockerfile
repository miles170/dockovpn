FROM alpine:3.24.2 AS openvpn-build

RUN apk add --no-cache alpine-sdk && apk update && \
    adduser -D builder && addgroup builder abuild
USER builder
COPY --chown=builder:builder packaging/openvpn/APKBUILD /home/builder/build/openvpn/APKBUILD
WORKDIR /home/builder/build/openvpn
RUN abuild-keygen -a -n
USER root
RUN cp /home/builder/.abuild/*.rsa.pub /etc/apk/keys/
USER builder
RUN abuild -r

FROM alpine:3.24.2

LABEL maintainer="Alexander Litvinenko <array.shift@yahoo.com>"

# System settings. User normally shouldn't change these parameters
ENV APP_NAME=Dockovpn
ENV APP_INSTALL_PATH=/opt/${APP_NAME}
ENV APP_PERSIST_DIR=/opt/${APP_NAME}_data

# Configuration settings with default values
ENV NET_ADAPTER=eth0
ENV HOST_ADDR=""
ENV HOST_TUN_PORT=1194
ENV HOST_CONF_PORT=80
ENV HOST_TUN_PROTOCOL=udp
ENV CRL_DAYS=3650

WORKDIR ${APP_INSTALL_PATH}

COPY scripts .
COPY config ./config
COPY VERSION ./config

# Security fixes: OpenVPN CVE-2026-84790 and OpenSSL's 2026-09-29 advisory.
RUN --mount=type=bind,from=openvpn-build,source=/home/builder/packages/build,target=/packages \
    apk add --no-cache --allow-untrusted /packages/*/openvpn-2.7.8-r0.apk && \
    apk add --no-cache 'openvpn>=2.7.8' 'openssl>=3.5.9' 'libssl3>=3.5.9' 'libcrypto3>=3.5.9' openvpn-auth-ldap easy-rsa bash netcat-openbsd zip curl dumb-init iptables iproute2 && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/bin/easyrsa && \
    mkdir -p ${APP_PERSIST_DIR} /etc/openvpn && \
    cd ${APP_PERSIST_DIR} && \
    easyrsa init-pki && \
    easyrsa gen-dh && \
    # DH parameters of size 2048 created at /usr/share/easy-rsa/pki/dh.pem
    # Copy DH file
    cp pki/dh.pem /etc/openvpn && \
    # Copy FROM ./scripts/server/conf TO /etc/openvpn/server.conf in DockerFile
    cd ${APP_INSTALL_PATH} && \
    cp config/server.conf /etc/openvpn/server.conf


EXPOSE 1194/${HOST_TUN_PROTOCOL}

VOLUME [ "/opt/Dockovpn_data" ]

ENTRYPOINT [ "dumb-init", "./start.sh" ]
CMD [ "" ]
