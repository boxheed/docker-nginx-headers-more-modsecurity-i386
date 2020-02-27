FROM boxheed/nginx-headers-more:latest as build

USER 0
RUN install_packages \
  wget \
  nfs-common \
  apt-utils \
  autoconf \
  automake \
  build-essential \
  git \
  libcurl4-openssl-dev \
  libgeoip-dev \
  liblmdb-dev \
  libpcre++-dev \
  libtool \
  libxml2-dev \
  libyajl-dev \
  pkgconf \
  zlib1g-dev

RUN git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity \
  && cd ModSecurity \
  && git submodule init \
  && git submodule update \
  && ./build.sh \
  && ./configure \
  && make \
  && make install \
  && cd / \
  && rm -rf ModSecurity

RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git \
  && wget http://nginx.org/download/nginx-1.17.8.tar.gz \
  && tar zxvf nginx-1.17.8.tar.gz \
  && rm -f nginx-1.17.8.tar.gz \
  && cd nginx-1.17.8 \
  && ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx \
  && make modules \
  && cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules \
  && cd / \
  && rm -rf /nginx-1.17.8 \
  && rm -rf /ModSecurity-nginx  

FROM boxheed/nginx-headers-more:latest as RUN

USER 0

RUN install_packages \
    apt-utils \
    openssl \
    libcurl4 \
    libgeoip1 \
    geoip-bin \
    liblmdb0 \
    libpcre++0v5 \
    libxml2 \
    libyajl2 \
    zlib1g

COPY --from=build /usr/local/modsecurity /usr/local/modsecurity
COPY --from=build /etc/nginx/modules/ngx_http_modsecurity_module.so /etc/nginx/modules/ngx_http_modsecurity_module.so

ADD owasp-modsecurity-crs-3.0.2.tar.gz /etc/nginx/modsec
ADD nginx.conf /etc/nginx/
ADD modsecurity.conf /etc/nginx/modsec/
ADD unicode.mapping /etc/nginx/modsec/
ADD main.conf /etc/nginx/modsec/
RUN chmod 755 /etc/nginx/modsec \
  && find /etc/nginx/modsec -type d -exec chmod 755 {} \; \
  && find /etc/nginx/modsec -type f -exec chmod 644 {} \; \
  && chmod 644 /etc/nginx/conf.d/* \
  && chmod 644 /etc/nginx/modules/* \
  && chmod 644 /etc/nginx/nginx.conf \
  && mkdir -p /var/log/modsec \
  && chown nginx:nginx /var/log/modsec \
  && chmod 770 /var/log/modsec/ \
  && mv /etc/nginx/modsec/owasp-modsecurity-crs-3.0.2/crs-setup.conf.example /etc/nginx/modsec/owasp-modsecurity-crs-3.0.2/crs-setup.conf \
  && mv /etc/nginx/modsec/owasp-modsecurity-crs-3.0.2/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example /etc/nginx/modsec/owasp-modsecurity-crs-3.0.2/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf \
  && mv /etc/nginx/modsec/owasp-modsecurity-crs-3.0.2/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example /etc/nginx/modsec/owasp-modsecurity-crs-3.0.2/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf

USER 101

CMD ["nginx", "-g", "daemon off;"]
