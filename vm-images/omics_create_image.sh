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
#
# Creates a Compute Engine VM, installs some omics-related software,
# and publishes the resulting image.
#
# + Access to compute and storage is granted in order to spin up
#   disks and store the image.
# + Uses a 16-core machine to parallelize some builds.
# + The startup-script is responsible for deleting the instance when
#   it has successfully completed.
# + If the script fails, ssh into the instance and view the log
#   at /var/log/startupscript.log

if [ "$#" -ne 2 ]; then
    echo "Usage:"
    echo " $0 [project] [cloud_storage_dir]"
    exit 1
fi

startup_script=omics_startup_script.sh
if [ ! -f "${startup_script}" ]; then
  echo "Startup script not in current directory: ${startup_script}"
  exit 2
fi

project=${1}
cloud_storage_dir=${2}
instance=${USER}-omics-create-image

# The flag usage of gcloud is quirky. Do not use:
# - equals sign, '--flag=value'
# - double quotes, '--flag="value1 value2"'
gcloud compute instances create ${instance} \
  --project ${project} \
  --zone us-central1-a \
  --image ubuntu-14-04 \
  --scopes compute-rw storage-full \
  --machine-type n1-standard-16 \
  --metadata cloud-storage-dir=${cloud_storage_dir} \
  --metadata-from-file startup-script=${startup_script}
