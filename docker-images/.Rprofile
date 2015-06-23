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

###### Configure bigrquery via httr.

# Use and out-of-band OAuth flow since the redirect will not work in this environment.
options("httr_oauth_cache"="~/.httr-oauth")

# Store oauth in one place.
options(httr_oob_default = TRUE)

# Place the Google Cloud Platform projectId in a variable so that we can pass it to bigrquery via our helper code.
require(stringr)
project <- str_trim(system("gcloud -q config list project --format yaml | grep project | cut -d : -f 2", intern=TRUE))

###### Configure GoogleGenomics.

# Assume a default location for client secrets.
clientSecretsFilepath <- "~/client_secrets.json"

# Authenticate out-of-band upon package load.
gg <- function() {
  if(file.exists(clientSecretsFilepath)) {
    GoogleGenomics::authenticate(file=clientSecretsFilepath,
                              invokeBrowser=FALSE)
  } else {
    message(paste("Authenticate to GoogleGenomics via:",
           "authenticate(file='/YOUR/PATH/TO/client_secrets.json',",
                 "invokeBrowser=FALSE)"))
  }
}
setHook(packageEvent("GoogleGenomics", "attach"), function(...) { gg() })
