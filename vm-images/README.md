Google Compute Engine virtual machine images
============================================

## Overview

Scripts that create a Google Compute Engine image containing a set of
popular genomics software. The exact list of software available will
change with time, but examples of software it may contain are tophat,
bwa, and freebayes.  Additionally, R is pre-installed along with some
bioconductor packages and bigrquery, the interface into Google's
BigQuery.

## Adding an image to your GCE project

When a new tag is created for this repository, a corresponding public
image is created in Cloud Storage.  So, instead of checking out this
repository and creating your own image, you can add one of the images
from the [public space]
(https://console.developers.google.com/storage/genomics-public-data/gce-images/)

```
  gcloud compute images create omics-<id> --project <project-name> --source-uri gs://genomics-public-data/gce-images/omics-<id>.image.tar.gz
```

## Execution

To create a new image directly in a project, execute the following bash shell.
The `cloud_storage_dir` is used to store a `.tar.gz` file of the image.

```
  ./omics_create_image.sh <project> <cloud_storage_dir>
```

For example, when creating a new image in our public data bucket, we run:

```
  ./omics_create_image.sh genomics-public-data gs://genomics-public-data/gce-images
```
