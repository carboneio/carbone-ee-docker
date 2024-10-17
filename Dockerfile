FROM debian:stable-slim AS downloader
ARG TARGETARCH
ARG LO_VERSION="24.8.2.1"
ARG ARCH=${TARGETARCH/arm64/aarch64}
ARG ARCH=${ARCH/amd64/x86-64}
ADD https://bin.carbone.io/libreoffice-headless-carbone/LibreOffice_${LO_VERSION}_Linux_${ARCH}_deb.tar.gz /libreoffice.tar.gz

FROM debian:stable-slim

ARG TARGETPLATFORM
ARG TARGETARCH
ARG CARBONE_VERSION="4.23.7"

WORKDIR /tmp
RUN apt update && \
    apt install -y libfreetype6 fontconfig libgssapi-krb5-2 && \
    rm -rf /var/lib/apt/lists/*

# Create Carbone user
RUN adduser carbone --home /app --no-create-home --disabled-password --system

# Copy the local binary into the image folder "app"
ENV APP_ROOT=/app/
RUN mkdir ${APP_ROOT} && chown -R carbone:nogroup ${APP_ROOT}

WORKDIR ${APP_ROOT}

ADD --chown=carbone:nogroup --chmod=755 https://bin.carbone.io/carbone/carbone-ee-${CARBONE_VERSION}-linux-${TARGETARCH/amd64/x64} ./carbone-ee-linux

COPY --chown=carbone:nogroup --chmod=755 ./docker-entrypoint.sh ./docker-entrypoint.sh

# Include plugins
COPY --chown=carbone:nogroup ./carbone-ee-plugin-s3 /app/plugin-s3/
COPY --chown=carbone:nogroup ./carbone-ee-plugin-azure-storage-blob /app/plugin-azure/

# Download and install LibreOffice
RUN --mount=type=bind,from=downloader,target=/tmp/libreoffice.tar.gz,source=libreoffice.tar.gz \
	tar -zxf /tmp/libreoffice.tar.gz && \
	dpkg -i LibreOffice*_Linux_*_deb/DEBS/*.deb && \
	rm -r LibreOffice*

# Include basic fonts
COPY --chown=carbone:nogroup fonts /usr/share/fonts/
RUN fc-cache -f -v

USER carbone

RUN mkdir /app/template && mkdir /app/render && mkdir /app/config && mkdir /app/asset && mkdir /app/plugin

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["webserver"]
