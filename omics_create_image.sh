#!/bin/bash
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

gcutil addinstance ${instance} \
  --image=debian-7 \
  --project=${project} \
  --service_account_scopes=https://www.googleapis.com/auth/devstorage.full_control,https://www.googleapis.com/auth/compute \
  --machine_type=n1-standard-16 \
  --zone=us-central1-a \
  --wait_until_running \
  --auto_delete_boot_disk \
  --metadata_from_file=startup-script:${startup_script} \
  --metadata=cloud-storage-dir:${cloud_storage_dir}
