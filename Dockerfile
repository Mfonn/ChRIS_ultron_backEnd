#
# Docker file for CUBE image
#
# Build production image:
#
#   docker build -t <name> .
#
# For example if building a local production image:
#
#   docker build -t local/chris .
#
# Build development image:
#
#   docker build --build-arg ENVIRONMENT=local -t <name>:<tag> .
#
# For example if building a local development image:
#
#   docker build --build-arg ENVIRONMENT=local -t local/chris:dev .
#
# In the case of a proxy (located at say proxy.tch.harvard.edu:3128), do:
#
#    export PROXY="http://proxy.tch.harvard.edu:3128"
#
# then add to any of the previous build commands:
#
#    --build-arg http_proxy=${PROXY}
#
# For example if building a local development image:
#
# docker build --build-arg http_proxy=${PROXY} --build-arg ENVIRONMENT=local -t local/chris:dev .
#

FROM fnndsc/ubuntu-python3:ubuntu20.04-python3.8.5

LABEL org.opencontainers.image.authors="FNNDSC <dev@babyMRI.org>" \
      org.opencontainers.image.title="ChRIS Ultron Backend" \
      org.opencontainers.image.description="ChRIS backend" \
      org.opencontainers.image.url="https://chrisproject.org/" \
      org.opencontainers.image.source="https://github.com/FNNDSC/ChRIS_ultron_backEnd" \
      org.opencontainers.image.licenses="MIT"


# Pass a UID on build command line (see above) to set internal UID
ARG UID=1001
ARG ENVIRONMENT=production
ENV UID=$UID DEBIAN_FRONTEND=noninteractive VERSION="0.1"

# setting non-root privileges to user
ARG USERNAME=localuser
ARG USER_UID=1000
ARG USER_GID=$USER_UID


# Set the default user.
USER $USERNAME


ENV APPROOT="/home/localuser/chris_backend" REQPATH="/usr/src/requirements"
COPY ["./requirements", "${REQPATH}"]
COPY ["./docker-entrypoint.sh", "/usr/src"]

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME         \
  && apt-get update                                               \
  && apt-get install -y locales                                   \
  && apt-get install -y sudo                                      \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME
  && export LANGUAGE=en_US.UTF-8                                 \
  && export LANG=en_US.UTF-8                                     \
  && export LC_ALL=en_US.UTF-8                                   \
  && locale-gen en_US.UTF-8                                      \
  && dpkg-reconfigure locales                                    \
  && apt-get install -y build-essential libldap2-dev libsasl2-dev slapd ldap-utils lcov valgrind \
  && apt-get install -y libssl-dev libpq-dev                     \
  && apt-get install -y apache2 apache2-dev                      \
  && python manage.py collectstatic --noinput                    \
  && pip install --upgrade pip                                   \
  && pip install -r ${REQPATH}/${ENVIRONMENT}.txt                \
  && useradd -l -u $UID -ms /bin/bash localuser

# Start as user localuser
USER localuser



# Copy source code and make localuser the owner
COPY --chown=localuser ["./chris_backend", "${APPROOT}"]

WORKDIR $APPROOT
ENTRYPOINT ["/usr/src/docker-entrypoint.sh"]
EXPOSE 8000



# Start ChRIS production server
CMD ["mod_wsgi-express", "start-server", "config/wsgi.py", "--host", "0.0.0.0", "--port", "8000",  \
"--processes", "4", "--limit-request-body", "5368709120", "--server-root", "/home/localuser/mod_wsgi-0.0.0.0:8000"]
#to start daemon:
#/home/localuser/mod_wsgi-0.0.0.0:8000/apachectl start
#to stop deamon
#/home/localuser/mod_wsgi-0.0.0.0:8000/apachectl stop
