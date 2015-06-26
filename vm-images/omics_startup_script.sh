#!/bin/bash
#
# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Install omics-related software tools.  It is expected that this
# script will be used to setup a Google Compute engine VM instance for
# use in omics work.
#
# This file must be smaller than 32kb to be usable as command-line
# metadata for gcutil.

set -x  # Print commands as they are executed, for easier debugging.
set -e  # Exit on error
set -u  # Exit upon using unitialized variable.

# Create useful environmental variables.
function setup_env {
  # Get the zone from the metadata server, which stores instance-specific
  # information.  The full zone returned is of the form:
  #   projects/<project-number>/zones/us-central1-a
  # We just want the last portion.
  export ZONE=$(curl http://metadata/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google" | cut -f4 -d/)

  # Location to put the resulting image.
  export CLOUD_STORAGE_DIR=$(curl http://metadata/computeMetadata/v1/instance/attributes/cloud-storage-dir -H "Metadata-Flavor: Google")

  # Directory where we store all source code while building.
  export BUILD_DIR=/usr/local/share/omics-build
  mkdir -p ${BUILD_DIR}

  # Useful for parallelizing builds.
  export NUM_PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
}

# Do basic upgrades first.
function init_apt {
  apt-get update
  apt-get upgrade -y
  apt-get clean -y
}

# Install a useful set of packages for development and to satisfy
# dependencies.
function install_packages {
  apt-get install -y \
    asciidoc \
    apache2 \
    autoconf \
    build-essential \
    cmake \
    cpanminus \
    emacs \
    expat \
    g++ \
    gcc \
    git \
    gnuplot \
    gsl-bin \
    libatlas3-base \
    libatlas3gf-base \
    libatlas-base-dev \
    libatlas-dev \
    libboost-all-dev \
    libbz2-dev \
    libc6-dev-i386 \
    libcurl4-openssl-dev \
    libdata-hexdumper-perl \
    libdigest-sha-perl \
    libfuse-dev \
    libgd2-xpm-dev \
    libgetopt-declare-perl \
    libglpk-dev \
    libgsl0-dev \
    libmodule-find-perl \
    libncurses5-dev \
    libossp-uuid-perl \
    libperl-dev \
    libpng12-dev \
    libsvm-dev \
    libtie-ixhash-perl \
    libtool \
    libxerces-c-dev \
    libxml2-dev \
    libxml-parser-perl \
    libzip-dev \
    mercurial \
    mysql-client \
    python-dev \
    python-hachoir-parser \
    python-scipy \
    python-setuptools \
    qt4-dev-tools \
    screen \
    subversion \
    swig \
    tabix \
    tmux \
    unzip \
    x11-apps \
    xsltproc \
    xterm \
    zlib1g-dev
  apt-get clean -y
  easy_install pip
}

# Setup bashrc:
#  - search for additional files in .d directory.
#  - include /usr/local paths for perl libraries
function setup_bashrc {
  mkdir -p /etc/bash.bashrc.d
  cat >> /etc/bash.bashrc <<EOF

export PERL5LIB="${PERL5LIB:+"$PERL5LIB:"}/usr/local/lib/perl5/site_perl"

# Search for program specific bashrc files.
if [ -d /etc/bash.bashrc.d ]; then
  for file in /etc/bash.bashrc.d/*.sh; do
    if [ -r \${file} ]; then
      . \${file}
    fi
  done
  unset i
fi
EOF
}

# Some useful commands for users.
function setup_aliases {
  cat > /etc/bash.bashrc.d/aliases.sh <<EOF
function mount_disk {
  local disk_name=\${1}
  sudo mkdir /mnt/\${disk_name} && \
    sudo /usr/share/google/safe_format_and_mount \
    -m "mkfs.ext4 -F" \
    /dev/disk/by-id/google-\${disk_name} \
    /mnt/\${disk_name}
}
EOF
}

# Allow x11 forwarding with the instance.
function setup_x {
  cat >> /etc/ssh/sshd_config <<EOF

# To allow x11 forwarding to work properly.
X11UseLocalhost no
EOF
  restart ssh
}

# In order for gsutil to be performant on large downloads, need
# to update crcmod.
function setup_crcmod {
  pip install crcmod
}

# Use bcl2fastq 1.x.y for MiSeq and HiSeq data conversion.
function install_bcl2fastq {
  local version=${1}
  cd ${BUILD_DIR}

  curl -L ftp://webdata:webdata@ussd-ftp.illumina.com/Downloads/Software/bcl2fastq/bcl2fastq-${version}.tar.bz2 | tar jx

  # Small fix that static_casts the &fs::path::string to its const
  # version, because in some versions of boost there are two versions
  # (const and non-const) and the compiler should get confused.
  #
  # This pattern is specific enough that it should become an no-op if
  # they fix things and remove the problematic section.  It also will
  # update any additional inclusions.
  sed -i s/"bind(&fs::path::string"/"bind(static_cast<std::string const\&(fs::path::*)() const>(\&fs::path::string)"/ \
    bcl2fastq/src/c++/lib/demultiplex/BclDemultiplexer.cpp

  mkdir bcl2fastq/build
  cd bcl2fastq/build
  # Must force the use of the installed cmake because
  # - it seems configure doesn't notice it is installed :/
  # - the default cmake version included with bcl2fastq does not
  #   support multi-arch libraries like /lib/x86_64-linux-gnu
  ../src/configure --with-cmake=/usr/bin/cmake
  make -j${NUM_PROCESSORS}
  make install

  cd ${BUILD_DIR}
  rm -r bcl2fastq
}

# Use the bcl2fastq 2.x.y.z conversion software to convert NextSeq 500
# or HiSeq X output.
function install_bcl2fastq2 {
  local version=${1}
  cd ${BUILD_DIR}

  curl -L ftp://webdata2:webdata2@ussd-ftp.illumina.com/downloads/Software/bcl2fastq/bcl2fastq2-v${version}.tar.gz | tar zx --transform 's!^bcl2fastq\($\|/\)!bcl2fastq2\1!'

  mkdir bcl2fastq2/build
  cd bcl2fastq2/build
  ../src/configure
  make -j${NUM_PROCESSORS}
  make install

  cd ${BUILD_DIR}
  rm -r bcl2fastq2
}

# Burrows-Wheeler Aligner
function install_bwa {
  local version=${1}
  cd ${BUILD_DIR}

  git clone https://github.com/lh3/bwa.git
  cd bwa
  git checkout tags/${version}
  make -j${NUM_PROCESSORS}
  cp bwa /usr/local/bin

  cd ${BUILD_DIR}
  rm -r bwa
}

# BowTie2 is needed by TopHat2.
function install_bowtie2 {
  local version=${1}
  cd ${BUILD_DIR}

  git clone https://github.com/BenLangmead/bowtie2.git
  cd bowtie2
  git checkout tags/${version}
  make -j${NUM_PROCESSORS}
  cp bowtie2* /usr/local/bin

  cd ${BUILD_DIR}
  rm -r bowtie2
}

# Libraries from SamTools are needed by Cufflinks.
# TopHat2 uses it's own packaging of SamTools.
# Due to samtools and bcftools depending on htslib, we just check all of
# these out at once and build them all together.
function install_samtools {
  local htslib_version=${1}
  local bcftools_version=${2}
  local samtools_version=${3}

  cd ${BUILD_DIR}
  git clone https://github.com/samtools/bcftools.git
  git clone https://github.com/samtools/htslib.git
  git clone https://github.com/samtools/samtools.git

  cd ${BUILD_DIR}/htslib
  git checkout tags/${htslib_version}
  make -j${NUM_PROCESSORS} install

  cd ${BUILD_DIR}/bcftools
  git checkout tags/${bcftools_version}
  make -j${NUM_PROCESSORS} install


  cd ${BUILD_DIR}/samtools
  git checkout tags/${samtools_version}
  make -j${NUM_PROCESSORS} install

  # Headers and libraries need to be installed manually.
  mkdir -p /usr/local/include/bam
  cp *.h /usr/local/include/bam
  cp *.a /usr/local/lib

  cd ${BUILD_DIR}
  rm -r htslib bcftools samtools
}

function install_tophat2 {
  local version=${1}
  cd ${BUILD_DIR}

  curl -L http://ccb.jhu.edu/software/tophat/downloads/tophat-${version}.tar.gz | tar zx
  cd tophat-${version}
  # TODO: Patch configuration to find the boost libraries automagically.
  ./configure --with-boost-libdir=/usr/lib/x86_64-linux-gnu
  make install  # Do not use -j option, as the Makefile seems unparallelizable.

  cd ${BUILD_DIR}
  rm -r tophat-${version}
}

# Eigen is needed by cufflinks.
function install_eigen {
  local version=${1}
  cd ${BUILD_DIR}

  hg clone -r ${version} https://bitbucket.org/eigen/eigen/
  cp -r eigen/Eigen /usr/local/include

  rm -r eigen
}

function install_cufflinks {
  local version=${1}
  cd ${BUILD_DIR}

  curl -L http://cole-trapnell-lab.github.io/cufflinks/assets/downloads/\
cufflinks-${version}.tar.gz | tar zx
  cd cufflinks-${version}
  # TODO: Patch configuration to find the boost libraries automagically.
  # TODO: Better handle that libhts needs to be explicitly given here.
  ./configure \
    --with-boost-system=/usr/lib/x86_64-linux-gnu/libboost_system.a \
    --with-boost-thread=/usr/lib/x86_64-linux-gnu/libboost_thread.a \
    --with-boost-serialization=/usr/lib/x86_64-linux-gnu/\
libboost_serialization.a \
    LIBS=-lhts
  make -j${NUM_PROCESSORS} install

  cd ${BUILD_DIR}
  rm -r cufflinks-${version}
}

function install_bamtools {
  local version=${1}
  cd ${BUILD_DIR}

  git clone https://github.com/pezmaster31/bamtools.git
  cd bamtools
  git checkout tags/${version}
  # Put the libraries in /usr/local/lib, not /usr/local/lib/bamtools.
  sed -i s/"lib\/bamtools"/"lib"/ src/api/CMakeLists.txt
  mkdir build
  cd build
  cmake ..
  make -j${NUM_PROCESSORS} install

  cd ${BUILD_DIR}
  rm -r bamtools
}

function install_pyvcf {
  local version=${1}
  pip install pyvcf==${version}
}

function install_vcftools {
  local version=${1}
  cd ${BUILD_DIR}

  svn checkout -r ${version} http://svn.code.sf.net/p/vcftools/code/trunk/ vcftools-${version}
  cd vcftools-${version}
  PREFIX=/usr/local make install

  cd ${BUILD_DIR}
  rm -r vcftools-${version}
}

function install_freebayes {
  local version=${1}
  cd ${BUILD_DIR}

  git clone --recursive git://github.com/ekg/freebayes.git
  cd freebayes
  git checkout tags/${version}
  make -j${NUM_PROCESSORS}
  make install
  cd ${BUILD_DIR}
  rm -r freebayes
}

function install_plink {
  local version=${1}
  cd ${BUILD_DIR}

  git clone --recursive git://github.com/chrchang/plink-ng.git
  cd plink-ng
  git checkout tags/${version}

  # Updates to find zlib in it's standard place on the system
  sed -i 's/^ZLIB.*/ZLIB=-lz/' Makefile.std
  sed -i 's/zlib-1.2.8\///' plink_common.h pigz.c

  make -j${NUM_PROCESSORS} -f Makefile.std
  cp plink /usr/local/bin

  cd ${BUILD_DIR}
  rm -r plink-ng
}

function install_pseq {
  local version=${1}
  cd ${BUILD_DIR}

  git clone https://bitbucket.org/statgen/plinkseq.git
  cd plinkseq
  git checkout ${version}
  make -j${NUM_PROCESSORS}
  cp \
    behead browser gcol mm mongoose pdas pseq smp tab2vcf \
    /usr/local/bin

  cd ${BUILD_DIR}
  rm -r plinkseq
}

function install_gvcftools {
  local version=${1}
  cd ${BUILD_DIR}

  git clone git://github.com/ctsa/gvcftools.git
  cd gvcftools
  git checkout tags/${version}
  make -j${NUM_PROCESSORS} install
  cp bin/* /usr/local/bin

  cd ${BUILD_DIR}
  rm -r gvcftools
}

function install_R {
  local version=${1}
  cd ${BUILD_DIR}

  apt-get build-dep -y r-base
  apt-get clean -y

  local major_version=$(echo ${version} | cut -f1 -d.)
  curl -L http://cran.rstudio.com/src/base/R-${major_version}/\
R-${version}.tar.gz | tar zx
  cd R-${version}
  ./configure

  make -j${NUM_PROCESSORS}
  make install
  make install-info

  cd ${BUILD_DIR}
  rm -r R-${version}
}

function install_Rpackages {
  # Install useful R and bioconductor packages.  For bioconductor, ask=FALSE
  # will skip interactive prompting and force updates of old packages.
  # The unzip line is needed to handle the following situation:
  # http://stackoverflow.com/questions/20408250/default-options-setting-for-unzip
  R --no-save --no-restore-data <<EOF
options(repos = "http://cran.cnr.berkeley.edu/")
if(getOption("unzip") == "") options(unzip = 'internal')
install.packages(c("ggplot2", "devtools", "httpuv"))
devtools::install_github("hadley/assertthat")
devtools::install_github("hadley/bigrquery")
source("http://bioconductor.org/biocLite.R")
biocLite(ask=FALSE)
biocLite(c("GenomicFeatures", "AnnotationDbi", "cummeRbund"), ask=FALSE)
q()
EOF
}

# Attach a disk, create an image, and publish it.
function create_image {
  local version=${1}
  local name=omics-${version}
  local disk=omics-${version}
  local zone=${ZONE}

  # Create disk an attach to this instance.
  gcutil adddisk ${disk} --size_gb=200 --zone=${zone}
  gcutil attachdisk --disk=${disk} ${HOSTNAME} --zone=${zone}

  # Mount the disk.
  mkdir -p /mnt/${disk}
  /usr/share/google/safe_format_and_mount \
    -m "mkfs.ext4 -F" \
    /dev/disk/by-id/google-${disk} \
    /mnt/${disk}

  # Create the disk image.
  gcimagebundle \
    -d /dev/sda \
    -o /mnt/${disk} \
    --log_file=/mnt/${disk}/${disk}.log

  # Copy to the cloud and add image to the project.
  local local_image=$(ls /mnt/${disk}/*.image.tar.gz)
  local remote_image=${CLOUD_STORAGE_DIR}/${name}.image.tar.gz
  gsutil cp ${local_image} ${remote_image}
  gcutil addimage ${name} ${remote_image}

  # Delete the disk.
  gcutil detachdisk ${HOSTNAME} --device_name=${disk} --zone=${zone}
  # --force skips interactive prompts.
  gcutil deletedisk --force ${disk}
}

function delete_instance {
  # --force skips interactive prompts.
  # --delete_boot_pd is required when doing --force.
  gcutil deleteinstance --force --delete_boot_pd ${HOSTNAME}
}

setup_env

init_apt
install_packages

setup_bashrc
setup_aliases
setup_x
setup_crcmod

install_bcl2fastq   1.8.4
install_bcl2fastq2  2.15.0.4
install_bwa         0.7.12
install_bowtie2     v2.2.5
install_samtools    1.2.1 1.2 1.2  # Versions for htslib, bcftools, samtools.
install_tophat2     2.0.14
install_eigen       3.2.4
install_cufflinks   2.2.1
install_bamtools    v2.3.0
install_pyvcf       0.6.7
install_vcftools    974  # Equivalent to release 0.1.13.
install_freebayes   v9.9.13
install_plink       v1.90b3
install_pseq        b4f9881  # Equivalent to release 0.10.
install_gvcftools   v0.16.1  # Includes tabix 0.2.6 w/faidx and boost 1.44.
install_R           3.2.0
install_Rpackages

create_image        008  # INCREMENT ME
delete_instance
