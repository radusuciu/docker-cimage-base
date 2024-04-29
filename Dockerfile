ARG R_VERSION=4.4.0
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.source https://github.com/radusuciu/docker-cimage-base


### dependencies for cimage ###
FROM r-base as cimage-deps
ARG NUM_BUILD_CORES
ARG R_VERSION

RUN apt-get update \ 
  && apt-get install -y --no-install-recommends --no-install-suggests \
    # general
    build-essential \
    r-base-dev=${R_VERSION}* \
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


### now we copy the dependencies to a new image that can be used as a runtime base ###
FROM r-base as cimage-runtime

RUN apt-get update \ 
  && apt-get install -y --no-install-recommends --no-install-suggests \
    # cimage runtime deps
    libglpk40 \
    netcdf-bin \
    libxml2 \
    libnetcdf-dev \
    imagemagick \
    pdftk \
  && rm -rf /var/lib/apt/lists/*

COPY --from=cimage-deps /usr/local/lib/R/ /usr/local/lib/R/
COPY --from=cimage-deps /usr/lib/R/ /usr/lib/R/
COPY --from=cimage-deps /usr/share/R/ /usr/share/R/


### testing that we correctly installed xcms and limma ###
FROM cimage-deps as cimage-deps-test
RUN Rscript -e "library(xcms)" -e "library(limma)"


### testing that xcms and limma still work with the runtime deps ###
FROM cimage-runtime as cimage-runtime-test
RUN Rscript -e "library(xcms)" -e "library(limma)"
