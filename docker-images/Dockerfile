### Start from Bioconductor view for Sequencing workflows.
# The suggested name for this image is: googlegenomics/devel_sequencing

FROM bioconductor/devel_sequencing:20150506
MAINTAINER deflaux@google.com
RUN apt-get update && \
    apt-get install -y -t unstable\
    screen \
    emacs


### Google-specific R Setup #################################
# Modelled after https://github.com/Bioconductor/bioc_docker/blob/master/out/devel_sequencing/Dockerfile


ADD .Rprofile /home/rstudio/

ADD installGooglePackages.R /tmp/

RUN cd /tmp && \
    R -f /tmp/installGooglePackages.R


### INSTALL  gcloud ########################################
# Modelled after https://github.com/GoogleCloudPlatform/cloud-sdk-docker/blob/master/Dockerfile

RUN apt-get update && apt-get install -y -qq --no-install-recommends wget unzip python php5-mysql php5-cli php5-cgi openjdk-7-jre-headless openssh-client python-openssl && apt-get clean
RUN wget https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.zip && unzip google-cloud-sdk.zip && rm google-cloud-sdk.zip
ENV CLOUDSDK_PYTHON_SITEPACKAGES 1
RUN google-cloud-sdk/install.sh --usage-reporting=true --path-update=true --bash-completion=true --rc-path=/.bashrc --disable-installation-options
RUN google-cloud-sdk/bin/gcloud --quiet components update pkg-go pkg-python pkg-java preview alpha beta app
RUN google-cloud-sdk/bin/gcloud --quiet config set component_manager/disable_update_check true
RUN mkdir /.ssh
ENV PATH /google-cloud-sdk/bin:$PATH
