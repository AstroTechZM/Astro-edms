# syntax=docker/dockerfile:1.2
# vim:set ft=dockerfile:

####
# base_image - Bare bones image with the base packages needed to run
#              Mayan EDMS.
####

FROM debian:trixie-20260421-slim AS base_image

LABEL io.artifacthub.package.keywords="Python,Django,document management,OCR,PDF"
LABEL io.artifacthub.package.readme-url="https://gitlab.com/mayan-edms/mayan-edms/-/raw/master/README.md"
LABEL maintainer="Roberto Rosario roberto.rosario@mayan-edms.com"
LABEL org.opencontainers.image.authors="Roberto Rosario roberto.rosario@mayan-edms.com, https://forum.mayan-edms.com"
LABEL org.opencontainers.image.base.name="debian:trixie-20260421-slim"
LABEL org.opencontainers.image.description="Free Open Source Electronic Document Management System"
LABEL org.opencontainers.image.documentation="https://docs.mayan-edms.com/chapters/docker/index.html"
LABEL org.opencontainers.image.licenses="GPL-2.0-only"
LABEL org.opencontainers.image.source="https://gitlab.com/mayan-edms/mayan-edms/-/blob/master/mayan/apps/platform/templates/platform/docker/dockerfile.tmpl"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/mayanedms/mayanedms"
LABEL org.opencontainers.image.vendor="Roberto Rosario"
LABEL org.opencontainers.image.title="Mayan EDMS"

COPY config.env /config.env

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    PROJECT_INSTALL_DIR=/opt/mayan-edms/

ENV MAYAN_MEDIA_ROOT=/var/lib/mayan \
    MAYAN_STATIC_ROOT=${PROJECT_INSTALL_DIR}static

# Debian package caching.
ARG APT_PROXY

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/root/.cache/pip \
set -x \
&& if [ "${APT_PROXY}" ]; \
    then echo "Acquire::http { Proxy \"http://${APT_PROXY}\"; };" > /etc/apt/apt.conf.d/01proxy \
; fi \
# Install base OS packages to run Mayan EDMS.
&& apt-get update \
&& apt-get install --no-install-recommends --yes \
    ca-certificates clamav file fuse ghostscript git gnupg1 graphviz libarchive-zip-perl libfile-mimeinfo-perl libfuse2 libimage-exiftool-perl libmariadb3 libpq5 libreoffice-calc-nogui libreoffice-draw-nogui libreoffice-impress-nogui libreoffice-math-nogui libreoffice-writer-nogui poppler-utils sane-utils sudo supervisor tesseract-ocr \
# Remove make and build dependencies.
&& apt-get remove --purge --yes \
    libproxy-tools \
    libreoffice-avmedia-backend-vlc \
    libvlc-bin \
    libvlc5 \
    libvlccore9 \
    libgstreamer-plugins-base1.0-0 \
    make \
&& apt-get autoremove --purge --yes \
# Add mayan group and user.
&& groupadd \
--gid 1000 \
mayan \
&& adduser \
mayan \
--disabled-password \
--gecos "" \
--gid 1000 \
--uid 1000 \
&& sed --in-place 's/#user_allow_other/user_allow_other/g' /etc/fuse.conf \
# Update ClamAV database.
&& /usr/bin/freshclam

####
# builder_image - This image builds the Python package and is discarded afterwards
#                 only the build artifact is carried over to the next image.
####

# Reuse image.
FROM base_image AS builder_image

# Python libraries caching.
ARG PIP_INDEX_URL
ARG PIP_TRUSTED_HOST

WORKDIR /src

# Copy the source files needed to build the Python package.
COPY --chown=mayan:mayan requirements /src/requirements
COPY --chown=mayan:mayan \
    HISTORY.rst \
    LICENSE \
    MANIFEST-PRODUCTION.in \
    README.md \
    README.rst \
    setup.py \
    /src/

COPY --chown=mayan:mayan mayan /src/mayan

# Install development packages needed to build the Python packages.
RUN --mount=type=cache,target=/var/cache/apt \
apt-get install --no-install-recommends --yes \
    g++ gcc libffi-dev libjpeg-dev libldap2-dev libpng-dev libsasl2-dev libssl-dev libtiff-dev make pkg-config zlib1g-dev \
    default-libmysqlclient-dev \
    libpq-dev \
    make python3-dev python3-venv \
&& mkdir --parents "${PROJECT_INSTALL_DIR}" \
&& chown --recursive mayan:mayan "${PROJECT_INSTALL_DIR}" \
&& chown --recursive mayan:mayan /src

USER mayan

RUN --mount=type=cache,target=/home/mayan/.cache/pip,gid=1000,uid=1000 \
set -a \
&& sed -E "s/=(.*)/\=\"\1\"/g" /config.env > /tmp/config.env \
&& . /tmp/config.env \
&& rm /tmp/config.env \
&& set +a \
&& python3 -m venv "${PROJECT_INSTALL_DIR}" \
&& . "${PROJECT_INSTALL_DIR}bin/activate" \
&& pip install --no-cache-dir \
    pip==${PYTHON_PIP_VERSION} \
    setuptools==${PYTHON_SETUPTOOLS_VERSION} \
    wheel==${PYTHON_WHEEL_VERSION} \
&& pip install --no-cache-dir \
    amqp==${PYTHON_AMQP_VERSION} \
    mysqlclient==${PYTHON_MYSQL_VERSION} \
    psycopg==${PYTHON_PSYCOPG_VERSION} \
    redis==${PYTHON_REDIS_VERSION} \
# psutil is needed by ARM builds otherwise gevent and gunicorn fail to start.
&& UNAME=`uname --machine` && if [ "${UNAME#*arm}" != ${UNAME} ]; then \
    pip install --no-cache-dir \
    psutil==${PYTHON_PSUTIL_VERSION} \
; fi \
# Install the Python packages needed to build Mayan EDMS.
&& pip install --no-cache-dir \
    --requirement /src/requirements/build.txt \
# Build Mayan EDMS.
&& cp MANIFEST-PRODUCTION.in MANIFEST.in \
&& python3 setup.py sdist \
&& pip wheel \
    --wheel-dir dist \
    dist/mayan_edms-*.tar.gz \
# Install the built Mayan EDMS package.
&& pip install --no-cache-dir \
    dist/mayan_edms-*.whl \
# Install the static content.
&& ${PROJECT_INSTALL_DIR}bin/mayan-edms.py dependencies_install \
&& ${PROJECT_INSTALL_DIR}bin/mayan-edms.py appearance_prepare_static --link --noinput

####
# Final image - base_image + builder_image artifact (Mayan install directory).
####

FROM base_image

COPY --from=builder_image --chown=mayan:mayan "${PROJECT_INSTALL_DIR}" "${PROJECT_INSTALL_DIR}"

USER root

COPY docker/rootfs /

VOLUME ["/var/lib/mayan"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

EXPOSE 8000
CMD ["run_all"]

RUN set -a \
&& sed -E "s/=(.*)/\=\"\1\"/g" /config.env > /tmp/config.env \
&& . /tmp/config.env \
&& rm /tmp/config.env \
&& set +a \
&& ${PROJECT_INSTALL_DIR}bin/mayan-edms.py platforms_template docker_entrypoint > /usr/local/bin/entrypoint.sh \
&& chown mayan:mayan /usr/local/bin/entrypoint.sh \
&& chmod +x /usr/local/bin/entrypoint.sh \
&& ${PROJECT_INSTALL_DIR}bin/mayan-edms.py platforms_template docker_supervisord > ${SUPERVISOR_CONFIGURATION_DIRECTORY}${SUPERVISOR_CONFIGURATION_FILENAME} \
&& apt-get clean autoclean \
&& apt-get autoremove --purge --yes \
&& rm --force --recursive /var/lib/apt/lists/* \
&& rm --force /var/cache/apt/archives/*.deb \
# Remove temporary files owned by root from the platforms_template step.
&& rm --force /tmp/* \
# Keep displaying log messages to stdout
&& find /var/log -type f | while read f; do echo -ne '' > $f; done \
# Delete Debian package proxy used for the base image.
&& rm --force /etc/apt/apt.conf.d/01proxy \
# Remove the mayan user home directory
&& rm --force --recursive /home/mayan
