Docker Image Scripts
=============================================

[Bioconductor](http://www.bioconductor.org/) provides an excellent set of [docker images](http://www.bioconductor.org/help/docker/) containing R, RStudioServer, and the sets of Bioconductor packages appropriate for certain use cases.

Here we have a version of the Bioconductor [Sequencing View](http://www.bioconductor.org/packages/release/BiocViews.html#___Sequencing) which adds on [GoogleGenomics](http://bioconductor.org/packages/release/bioc/html/GoogleGenomics.html), [bigrquery](http://cran.r-project.org/web/packages/bigrquery/index.html), [gcloud](https://cloud.google.com/sdk/gcloud/), and some configuration to .Rprofile.

Deploying a new version to the public image repository
------------------------------------------------------
Get the latest Dockerfile, etc., from this repository via a git clone or pull and then:

(1) Build the image.
```
sudo docker build -t b.gcr.io/bioctest/devel_sequencing:0.03 .
```

(2) Push the new version to the public image repository.  *Always specify a tag.*
```
sudo gcloud  docker push b.gcr.io/bioctest/devel_sequencing:0.03
```

(3) Also tag the new version as 'latest'.  *Always explicity mark as 'latest' a particular tagged version.*
```
sudo docker tag  b.gcr.io/bioctest/devel_sequencing:0.03 b.gcr.io/bioctest/devel_sequencing:latest
```

(4) And push 'latest'. (This will be really quick since its just updating metadata about 'latest'.)
```
sudo gcloud docker push b.gcr.io/bioctest/devel_sequencing:latest 
```
