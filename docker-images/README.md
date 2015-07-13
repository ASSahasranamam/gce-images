Docker Image Scripts
=============================================

[Bioconductor](http://www.bioconductor.org/) provides an excellent set of [docker images](http://www.bioconductor.org/help/docker/) containing R, RStudioServer, and the sets of Bioconductor packages appropriate for certain use cases.

Here we have a version of the Bioconductor [Sequencing View](http://www.bioconductor.org/packages/release/BiocViews.html#___Sequencing) which adds on [GoogleGenomics](http://bioconductor.org/packages/release/bioc/html/GoogleGenomics.html), [bigrquery](http://cran.r-project.org/web/packages/bigrquery/index.html), [gcloud](https://cloud.google.com/sdk/gcloud/), and some configuration to .Rprofile.

Deploying a new version to the public image repository
------------------------------------------------------
Get the latest Dockerfile, etc., from this repository via a `git clone` or `git pull` and then:

(1) Build the image.
```
sudo docker build -t gcr.io/bioc_2015/devel_sequencing:0.01 .
```

(2) Push the new version to the public image repository.  *Always specify a tag.*
```
sudo gcloud docker push gcr.io/bioc_2015/devel_sequencing:0.01
```

(3) Also tag the new version as 'latest'.  *Always explicity mark as 'latest' a particular tagged version.*
```
sudo docker tag  gcr.io/bioc_2015/devel_sequencing:0.01 gcr.io/bioc_2015/devel_sequencing:latest
```

(4) And push 'latest'. (This will be really quick since its just updating metadata about 'latest'.)
```
sudo gcloud docker push gcr.io/bioc_2015/devel_sequencing:latest 
```
