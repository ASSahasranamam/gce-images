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

# Turn off caching of credentials in this docker image.
options("google_auth_cache_httr"=FALSE)
options("httr_oauth_cache"=FALSE)

# Use an out-of-band OAuth flow since the redirect will not work in this dockerized environment.
options(httr_oob_default = TRUE)

# Remind users about the API_KEY option for accessing public data.
setHook(packageEvent("GoogleGenomics", "attach"),
        function(...) {
          if(!GoogleGenomics:::authenticated()) {
            message(paste("\nIf you are only accessing public data, you can",
                          "authenticate to GoogleGenomics via:",
                          "authenticate(apiKey='YOUR_PUBLIC_API_KEY')", sep="\n"))
          }
        })

# Place the Google Cloud Platform projectId in a variable so that we can pass it to bigrquery via our helper code.
require(stringr)
project <- str_trim(system("gcloud -q config list project --format yaml | grep project | cut -d : -f 2", intern=TRUE))
