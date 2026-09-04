ARG CHROME_VERSION="141.0.7390.55"

FROM debian:stable-slim AS downloader_libreoffice
ARG TARGETARCH
ARG LO_VERSION="26.2.4.2"
ARG ARCH=${TARGETARCH/arm64/aarch64}
ARG ARCH=${ARCH/amd64/x86-64}
ADD https://bin.carbone.io/libreoffice-headless-carbone/LibreOffice_${LO_VERSION}_Linux_${ARCH}_deb.tar.gz /libreoffice.tar.gz

FROM debian:stable-slim AS downloader_onlyoffice
ARG TARGETARCH
ARG OO_VERSION="9.0.4"
ARG ARCH=${TARGETARCH/arm64/aarch64}
ADD https://bin.carbone.io/onlyoffice-converter/onlyoffice-converter-standalone_${OO_VERSION}_${ARCH}.deb /onlyoffice.deb

FROM chromedp/headless-shell:${CHROME_VERSION} AS downloader_chrome-headless

FROM node:22 AS s3_plugin_install
RUN git clone https://github.com/carboneio/carbone-ee-plugin-s3.git && \
	cd carbone-ee-plugin-s3 && npm ci --omit=dev && rm -R test

FROM node:22 AS azure_plugin_install
RUN git clone https://github.com/carboneio/carbone-ee-plugin-azure-storage-blob.git && \
	cd carbone-ee-plugin-azure-storage-blob && npm i && npm ci --omit=dev

# ---------------------------------------------------------------------------
# base: everything every variant needs (user, carbone binary, plugins, entrypoint).
# No office suite, no chrome, no extra fonts yet.
# ---------------------------------------------------------------------------
FROM debian:stable-slim AS base

ARG TARGETPLATFORM
ARG TARGETARCH
ARG CARBONE_VERSION="5.4.2"

LABEL carbone.version=${CARBONE_VERSION}

WORKDIR /tmp
RUN apt update && \
    apt install -y libfreetype6 fontconfig libgssapi-krb5-2 unzip libpixman-1-0 dnsutils iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# Create Carbone user
RUN useradd -d /app carbone

# Copy the local binary into the image folder "app"
ENV APP_ROOT=/app/
RUN mkdir ${APP_ROOT} && chown -R carbone:nogroup ${APP_ROOT}

WORKDIR ${APP_ROOT}

ADD --chown=carbone:nogroup --chmod=755 https://bin.carbone.io/carbone/carbone-ee-${CARBONE_VERSION}-linux-${TARGETARCH/amd64/x64} ./carbone-ee-linux

COPY --chown=carbone:nogroup --chmod=755 ./docker-entrypoint.sh ./docker-entrypoint.sh

# Include plugins
COPY --chown=carbone:nogroup --from=s3_plugin_install carbone-ee-plugin-s3 /app/plugin-s3/
COPY --chown=carbone:nogroup --from=azure_plugin_install carbone-ee-plugin-azure-storage-blob /app/plugin-azure/

# ---------------------------------------------------------------------------
# Office suite / chrome mixins, each layered on "base".
# Combos that need more than one are chained (with-lo-oo, with-lo-oo-chrome, ...)
# so every variant below just picks the mixin matching the axes it wants.
# ---------------------------------------------------------------------------
FROM base AS with-lo
RUN --mount=type=bind,from=downloader_libreoffice,target=/tmp/libreoffice.tar.gz,source=libreoffice.tar.gz \
	tar -zxf /tmp/libreoffice.tar.gz && \
	dpkg -i LibreOffice*_Linux_*_deb/DEBS/*.deb && \
	rm -r LibreOffice*

FROM base AS with-oo
ENV CARBONE_EE_ONLYOFFICEPATH=auto
RUN --mount=type=bind,from=downloader_onlyoffice,target=/tmp/onlyoffice.deb,source=onlyoffice.deb \
	dpkg -i /tmp/onlyoffice.deb

FROM with-lo AS with-lo-oo
ENV CARBONE_EE_ONLYOFFICEPATH=auto
RUN --mount=type=bind,from=downloader_onlyoffice,target=/tmp/onlyoffice.deb,source=onlyoffice.deb \
	dpkg -i /tmp/onlyoffice.deb

FROM with-lo AS with-lo-chrome
ENV CARBONE_EE_CHROMEPATH=/opt/headless-shell/headless-shell
RUN --mount=type=bind,from=downloader_chrome-headless,target=/tmp/headless-shell,source=headless-shell \
	cp -r /tmp/headless-shell /opt/headless-shell && \
	apt update && \
	apt install -y libnspr4 libnss3 libexpat1 libfontconfig1 libuuid1 socat && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

FROM with-oo AS with-oo-chrome
ENV CARBONE_EE_CHROMEPATH=/opt/headless-shell/headless-shell
RUN --mount=type=bind,from=downloader_chrome-headless,target=/tmp/headless-shell,source=headless-shell \
	cp -r /tmp/headless-shell /opt/headless-shell && \
	apt update && \
	apt install -y libnspr4 libnss3 libexpat1 libfontconfig1 libuuid1 socat && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

FROM with-lo-oo AS with-lo-oo-chrome
ENV CARBONE_EE_CHROMEPATH=/opt/headless-shell/headless-shell
RUN --mount=type=bind,from=downloader_chrome-headless,target=/tmp/headless-shell,source=headless-shell \
	cp -r /tmp/headless-shell /opt/headless-shell && \
	apt update && \
	apt install -y libnspr4 libnss3 libexpat1 libfontconfig1 libuuid1 socat && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# slim: base only, no LibreOffice / OnlyOffice / Chrome.
# ---------------------------------------------------------------------------
FROM base AS slim

COPY --chown=carbone:nogroup fonts /usr/share/fonts/
RUN fc-cache -f -v

USER carbone

RUN mkdir /app/template && mkdir /app/render && mkdir /app/config && mkdir /app/asset && mkdir /app/plugin && mkdir /app/database

EXPOSE 4000/tcp

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["webserver"]

# ---------------------------------------------------------------------------
# no-onlyoffice: LibreOffice + Chrome, no OnlyOffice.
# ---------------------------------------------------------------------------
FROM with-lo-chrome AS no-onlyoffice

COPY --chown=carbone:nogroup fonts /usr/share/fonts/
RUN fc-cache -f -v

USER carbone

RUN mkdir /app/template && mkdir /app/render && mkdir /app/config && mkdir /app/asset && mkdir /app/plugin && mkdir /app/database

EXPOSE 4000/tcp

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["webserver"]

# ---------------------------------------------------------------------------
# no-libreoffice: OnlyOffice + Chrome, no LibreOffice.
# ---------------------------------------------------------------------------
FROM with-oo-chrome AS no-libreoffice

COPY --chown=carbone:nogroup fonts /usr/share/fonts/
RUN fc-cache -f -v

# Prepare Onlyoffice font cache
RUN /opt/onlyoffice-converter-standalone/documentserver/documentserver-generate-allfonts.sh

USER carbone

RUN mkdir /app/template && mkdir /app/render && mkdir /app/config && mkdir /app/asset && mkdir /app/plugin && mkdir /app/database

EXPOSE 4000/tcp

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["webserver"]

# ---------------------------------------------------------------------------
# no-chrome: LibreOffice + OnlyOffice, no Chrome.
# ---------------------------------------------------------------------------
FROM with-lo-oo AS no-chrome

COPY --chown=carbone:nogroup fonts /usr/share/fonts/
RUN fc-cache -f -v

# Prepare Onlyoffice font cache
RUN /opt/onlyoffice-converter-standalone/documentserver/documentserver-generate-allfonts.sh

USER carbone

RUN mkdir /app/template && mkdir /app/render && mkdir /app/config && mkdir /app/asset && mkdir /app/plugin && mkdir /app/database

EXPOSE 4000/tcp

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["webserver"]

# ---------------------------------------------------------------------------
# full-fonts: LibreOffice + OnlyOffice + Chrome + full carbone-fonts set.
# ---------------------------------------------------------------------------
FROM with-lo-oo-chrome AS full-fonts

COPY --chown=carbone:nogroup fonts /usr/share/fonts/
COPY --chown=carbone:nogroup carbone-fonts /usr/share/fonts/carbone-fonts
RUN fc-cache -f -v

# Prepare Onlyoffice font cache
RUN /opt/onlyoffice-converter-standalone/documentserver/documentserver-generate-allfonts.sh

USER carbone

RUN mkdir /app/template && mkdir /app/render && mkdir /app/config && mkdir /app/asset && mkdir /app/plugin && mkdir /app/database

EXPOSE 4000/tcp

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["webserver"]

# ---------------------------------------------------------------------------
# full: LibreOffice + OnlyOffice + Chrome. Default target (last stage).
# ---------------------------------------------------------------------------
FROM with-lo-oo-chrome AS full

COPY --chown=carbone:nogroup fonts /usr/share/fonts/
RUN fc-cache -f -v

# Prepare Onlyoffice font cache
RUN /opt/onlyoffice-converter-standalone/documentserver/documentserver-generate-allfonts.sh

USER carbone

RUN mkdir /app/template && mkdir /app/render && mkdir /app/config && mkdir /app/asset && mkdir /app/plugin && mkdir /app/database

EXPOSE 4000/tcp

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["webserver"]
