#!/bin/bash
#
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
  export NUM_PROCESSORS=`grep -c ^processor /proc/cpuinfo`
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
    libc6-dev-i386 \
    apache2 \
    cmake g++ autoconf patch libtool build-essential \
    gcc python-dev python-setuptools \
    git mercurial subversion \
    unzip libxml2-dev \
    emacs vim tmux \
    python3 \
    mysql-client \
    gsl-bin python-scipy \
    libboost-all-dev \
    libbz2-dev zlib1g-dev \
    libncurses5-dev libcurl4-gnutls-dev \
    qt4-dev-tools libglpk-dev \
    libgsl0-dev libxerces-c-dev libgsl0-dev \
    libsvm-dev libglpk-dev libzip-dev \
    x11-apps xauth xterm \
    cpanminus libmodule-find-perl libgetopt-declare-perl \
    libossp-uuid-perl libdigest-sha-perl libdata-hexdumper-perl \
    python-hachoir-parser libtie-ixhash-perl \
    tabix
  apt-get clean -y
  easy_install pip
}

# Setup bashrc to search for additional files in .d directory.
function setup_bashrc {
  mkdir -p /etc/bash.bashrc.d
  cat >> /etc/bash.bashrc <<EOF

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
  /etc/init.d/ssh restart
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

# Use the bcl2fastq 2.x.y.z conversion software to convert NextSeq 500 or HiSeq X output.
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

# SamTools is needed by TopHat2.
function install_samtools {
  local version=${1}
  cd ${BUILD_DIR}

  git clone https://github.com/samtools/samtools.git
  cd samtools
  git checkout ${version}  # TODO: Use 'tags' dir when its available.
  make -j${NUM_PROCESSORS}
  # There is no 'install' target, so install everything by hand.
  mkdir -p /usr/local/include/bam
  cp *.h /usr/local/include/bam
  cp *.a /usr/local/lib
  cp samtools bcftools/bcftools `find misc -executable -type f` /usr/local/bin

  cd ${BUILD_DIR}
  rm -r samtools
}

function install_tophat2 {
  local version=${1}
  cd ${BUILD_DIR}

  curl -L http://ccb.jhu.edu/software/tophat/downloads/tophat-${version}.tar.gz | tar zx
  cd tophat-${version}
  ./configure
  make install  # do not use -j option, as the Makefile seems unparallelizable

  cd ${BUILD_DIR}
  rm -r tophat-${version}
}

# Eigen is needed by cufflinks and OpenMS
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

  curl -L http://cufflinks.cbcb.umd.edu/downloads/cufflinks-${version}.tar.gz | tar zx
  cd cufflinks-${version}
  ./configure
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

function install_sra {
  local version=${1}
  cd ${BUILD_DIR}

  # TODO: install from https://github.com/ncbi/sratoolkit
  curl -L http://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/${version}/sratoolkit.${version}-ubuntu64.tar.gz | tar zx
  cat > /etc/bash.bashrc.d/sra.sh <<EOF
export PATH=${BUILD_DIR}/sratoolkit.${version}-ubuntu64/bin\${PATH:+:\$PATH}
EOF
}

function install_unfinnigan {
  local version=${1}
  cd ${BUILD_DIR}

  cpanm -i Digest::SHA1 XML::Generator

  hg clone -r ${version} https://code.google.com/p/unfinnigan/
  cd unfinnigan/perl/Finnigan
  perl Makefile.PL
  make install

  cd ${BUILD_DIR}
  rm -r unfinnigan
}

function install_openms {
  local version=${1}
  cd ${BUILD_DIR}

  # TODO: install from github repos:
  # git clone https://github.com/OpenMS/OpenMS
  # git clone https://github.com/OpenMS/contrib
  # git checkout tags/${version}

  local base=OpenMS-${version}
  curl -L http://sourceforge.net/projects/open-ms/files/OpenMS/${base}/${base}.tar.gz/download | tar zx
  cd ${base}

  # Fix for locating multi-arch libraries
  sed -i s/" NO_DEFAULT_PATH"// cmake/OpenMSBuildSystem_macros.cmake
  cd contrib
  cmake . -DBUILD_TYPE=SEQAN  # Only build Seqan, and none of the other contrib libraries.
  cd ..
  cmake . -DBOOST_USE_STATIC=off  # It does shared libraries (boo!!!), which run into PIC problems with static libraries.
  make -j${NUM_PROCESSORS}

  local openms_dir=${BUILD_DIR}/${base}
  cat > /etc/bash.bashrc.d/openms.sh <<EOF
export PATH=${openms_dir}/bin\${PATH:+:\$PATH}
export LD_LIBRARY_PATH=${openms_dir}/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
export OPENMS_DATA_PATH=${openms_dir}/share/OpenMS
EOF
}

function install_R {
  local version=${1}
  cd ${BUILD_DIR}

  apt-get build-dep -y r-base
  apt-get clean -y

  local major_version=$(echo ${version} | cut -f1 -d.)
  curl -L http://cran.cnr.berkeley.edu/src/base/R-${major_version}/R-${version}.tar.gz | tar zx
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
install_bwa         0.7.10
install_bowtie2     v2.2.3
install_samtools    standalone # master branch does not build
install_tophat2     2.0.12
install_eigen       3.2.1
install_cufflinks   2.2.1
install_bamtools    v2.3.0
install_pyvcf       0.6.7
install_vcftools    945  # equivalent to release 0.1.12a
install_freebayes   v9.9.13
install_sra         2.3.5-2
install_unfinnigan  ecf53d370bdd  # no real versioning
install_openms      1.11.1
install_R           3.1.0
install_Rpackages

create_image        006  # INCREMENT ME
delete_instance
