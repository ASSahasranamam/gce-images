Docker Image Scripts
=============================================

[Bioconductor](http://www.bioconductor.org/) provides an excellent set of [docker images](http://www.bioconductor.org/help/docker/) containing R, RStudioServer, and the sets of Bioconductor packages appropriate for certain use cases.

Here we have a version of the Bioconductor [Sequencing View](http://www.bioconductor.org/packages/release/BiocViews.html#___Sequencing) which adds on [GoogleGenomics](http://bioconductor.org/packages/release/bioc/html/GoogleGenomics.html), [bigrquery](http://cran.r-project.org/web/packages/bigrquery/index.html), [gcloud](https://cloud.google.com/sdk/gcloud/), and some configuration to .Rprofile.

Deploying a new version to the public image repository
------------------------------------------------------

The following instructions assume that Docker is installed and the current user can run docker commands.  For help with that one-time initial setup, see https://cloud.google.com/container-registry/#install_docker.

(1) Get the latest Dockerfile, etc., from this repository via a `git clone` or `git pull`.

(2) Make sure your build machine has the latest Bioconductor Docker image.
```
docker pull bioconductor/devel_sequencing
```

(3) Build the image.
```
docker build -t gcr.io/bioc_2015/devel_sequencing:0.01 .
```

(4) Push the new version to the public image repository.  *Always specify a tag.*
```
gcloud docker -- push gcr.io/bioc_2015/devel_sequencing:0.01
```

(5) Also tag the new version as 'latest'.  *Always explicity mark as 'latest' a particular tagged version.*
```
docker tag  gcr.io/bioc_2015/devel_sequencing:0.01 gcr.io/bioc_2015/devel_sequencing:latest
```

(6) And push 'latest'. (This will be really quick since its just updating metadata about 'latest'.)
```
gcloud docker -- push gcr.io/bioc_2015/devel_sequencing:latest
```
