### Alteryx Designer Cloud: Qwik Start



```bash

BUCKET=qwiklabs-gcp-02-0e0cd9798e39-bucket0
gcloud storage buckets create gs://$(BUCKET) \
    --default-storage-class=STANDARD \
    --location=US \
    --uniform-bucket-level-access \
    --public-access-prevention

``` 


