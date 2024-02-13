ARG R_VERSION=4.3.2
ARG NUM_BUILD_CORES=4

FROM debian:bullseye-slim as r-base
ARG DEBIAN_FRONTEND=noninteractive
ARG R_VERSION

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV R_VERSION=${R_VERSION}

# Install required dependencies and add CRAN repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        dirmngr \
        gnupg2 \
        ca-certificates \
        curl \
        locales \
        software-properties-common \
    && gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B8F25A8A73EACF41 \
    && gpg --export --armor B8F25A8A73EACF41 | gpg --dearmor -o /usr/share/keyrings/marutter-archive-keyring.gpg \
    && echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/99sandbox \
    && echo "deb [signed-by=/usr/share/keyrings/marutter-archive-keyring.gpg] https://cloud.r-project.org/bin/linux/debian bullseye-cran40/" > /etc/apt/sources.list.d/cran.list \
    && echo "deb-src [signed-by=/usr/share/keyrings/marutter-archive-keyring.gpg] https://cloud.r-project.org/bin/linux/debian bullseye-cran40/" >> /etc/apt/sources.list.d/cran.list

# Configure locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# Install R
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        r-base=${R_VERSION}* \
        r-base-dev=${R_VERSION}* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


### dependencies for cimage ###
FROM r-base as cimage-deps
ARG NUM_BUILD_CORES

RUN apt-get update \ 
  && apt-get install -y --no-install-recommends --no-install-suggests \
    # general
    build-essential \
    # cimage
    gfortran \
    netcdf-bin \
    libnetcdf-dev \
    libglpk-dev \
    libxml2 \
    libxml2-dev \
    libssl-dev \
  && rm -rf /var/lib/apt/lists/*

RUN <<-EOF
    echo "options(Ncpus=${NUM_BUILD_CORES})" >> /tmp/cimage_deps.R
    echo "install.packages('BiocManager')" >> /tmp/cimage_deps.R
    echo "BiocManager::install(c('xcms', 'limma'), ask=FALSE, UPDATE=TRUE)" >> /tmp/cimage_deps.R

    Rscript /tmp/cimage_deps.R
    rm /tmp/cimage_deps.R
EOF

LABEL org.opencontainers.image.source https://github.com/radusuciu/docker-cimage-base
