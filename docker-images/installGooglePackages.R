# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Modelled after https://github.com/Bioconductor/bioc_docker/blob/master/out/devel_sequencing/installFromBiocViews.R

library(BiocInstaller)

pkgs_to_install <- c("bigrquery", "GoogleGenomics")
github_pkgs_to_install <- c("googlegenomics/bioconductor-workshop-r")

cores <- max(2, parallel::detectCores()-2)
if (parallel::detectCores() == 1)
    cores <- 1
options(list("Ncpus"=cores))

tryCatch({
  biocLite(pkgs_to_install)
  biocLite(github_pkgs_to_install, build_vignettes=TRUE, dependencies=TRUE)
},
warning=function(w){
    if(length(grep("is not available|had non-zero exit status|installation of one or more packages failed", w$message)))
        stop(sprintf("got a fatal warning: %s", w$message))
})

warnings()

if (!is.null(warnings()))
{
    w <- capture.output(warnings())
    if (length(grep(
     "is not available|had non-zero exit status|installation of one or more packages failed", w)))
        quit("no", 1L)
}
