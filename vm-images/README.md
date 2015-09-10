Google Compute Engine virtual machine images
============================================

## Overview

These scripts create a Google Compute Engine image containing a set of popular genomics software. 

The exact list of software available will change with time, but examples of software it may contain are:
 * [TopHat](https://ccb.jhu.edu/software/tophat/index.shtml)
 * [bwa](http://bio-bwa.sourceforge.net/)
 * [freebayes](https://github.com/ekg/freebayes)
 
Additionally, R is pre-installed along with some [Bioconductor](http://www.bioconductor.org/) packages and [bigrquery](http://cran.r-project.org/web/packages/bigrquery/index.html), the R interface to Google BigQuery.  

See [omics_startup_script.sh](./omics_startup_script.sh) for the current list of software and versions.

## Create the Image

To create a new image directly in a Google Cloud Platform project, execute the shell script:
```
./omics_create_image.sh <YOUR-PROJECT-ID> gs://<YOUR-BUCKET>/<OPTIONAL-SUBDIRECTORY>
```
It will create a GCE instance, install all the software, and create an image of itself.  After about an hour you will see the new `.tar.gz` file under the Cloud Storage path specified and the virtual machine will be automatically deleted..
 
## Add the image to your Google Cloud Platform project

To add this to the list of available images in your project, you can either use the [Google Developers Console](https://cloud.google.com/compute/docs/console) or the gcloud command line tool.
```
  gcloud compute images create omics-<id> --project <YOUR-PROJECT-ID> \
  --source-uri gs://<YOUR-BUCKET>/<OPTIONAL-SUBDIRECTORY>/omics-<VERSION>.image.tar.gz
```
