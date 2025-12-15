ARG REGISTRY_HOST
FROM ${REGISTRY_HOST}/beckhoff/bdpg:v13.3.0

COPY debian/control /debian/control
RUN bdpg install-build-deps && rm -rf /debian
