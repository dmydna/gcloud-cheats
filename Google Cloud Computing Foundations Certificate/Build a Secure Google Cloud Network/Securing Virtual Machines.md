# Securing Virtual Machines using Chrome Enterprise Premium

### Task 2:

instancia `linux-iap`

```bash

NUM=\((gcloud projects describe\)(gcloud config get-value project) --format="value(projectNumber)")

# linux-iap
gcloud compute instances create linux-iap \
    --project=$(gcloud config get-value project) \
    --zone=us-east1-b \
    --machine-type=e2-medium \
    --network-interface=stack-type=IPV4_ONLY,subnet=default,no-address \
    --metadata=enable-osconfig=TRUE \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=($NUM)-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=yes,boot=yes,device-name=linux-iap,image=projects/debian-cloud/global/images/debian-13-trixie-v20260921,mode=rw,size=10,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ops-agent-policy=v2-template-1-7-0,goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
&& \
printf 'agentsRule:\n  packageState: installed\n  version: latest\ninstanceFilter:\n  inclusionLabels:\n  - labels:\n      goog-ops-agent-policy: v2-template-1-7-0\n' > config.yaml \
&& \
gcloud compute instances ops-agents policies create goog-ops-agent-v2-template-1-7-0-us-east1-b \
    --project=$(gcloud config get-value project) \
    --zone=us-east1-b \
    --file=config.yaml \
&& \
gcloud compute resource-policies create snapshot-schedule default-schedule-1 \
    --project=$(gcloud config get-value project) \
    --region=us-east1 \
    --max-retention-days=14 \
    --on-source-disk-delete=keep-auto-snapshots \
    --daily-schedule \
    --start-time=00:00 \
&& \
gcloud compute disks add-resource-policies linux-iap \
    --project=$(gcloud config get-value project) \
    --zone=us-east1-b \
    --resource-policies=projects/$(gcloud config get-value project)/regions/us-east1/resourcePolicies/default-schedule-1
    
```
instancia vm `windows-iap`

```bash    
NUM=\((gcloud projects describe\)(gcloud config get-value project) --format="value(projectNumber)")

# windows-iap
gcloud compute instances create windows-iap \
    --project=$(gcloud config get-value project) \
    --zone=us-east1-b \
    --machine-type=e2-medium \
    --network-interface=stack-type=IPV4_ONLY,subnet=default,no-address \
    --metadata=enable-osconfig=TRUE \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=($NUM)-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=yes,boot=yes,device-name=windows-iap-20261003-200953,disk-resource-policy=projects/$(gcloud config get-value project)/regions/us-east1/resourcePolicies/default-schedule-1,image=projects/windows-cloud/global/images/windows-server-2016-dc-v20260908,mode=rw,size=50,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ops-agent-policy=v2-template-1-7-0,goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
&& \
printf 'agentsRule:\n  packageState: installed\n  version: latest\ninstanceFilter:\n  inclusionLabels:\n  - labels:\n      goog-ops-agent-policy: v2-template-1-7-0\n' > config.yaml \
&& \
gcloud compute instances ops-agents policies create goog-ops-agent-v2-template-1-7-0-us-east1-b \
    --project=$(gcloud config get-value project) \
    --zone=us-east1-b \
    --file=config.yaml
    
```

intancia vm `windows-connectivity`

```bash 

NUM=\((gcloud projects describe\)(gcloud config get-value project) --format="value(projectNumber)")

# windows-connectivity    
gcloud compute instances create windows-connectivity \
    --project=$(gcloud config get-value project) \
    --zone=us-east1-b \
    --machine-type=e2-medium \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --metadata=enable-osconfig=TRUE \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=($NUM)-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --create-disk=auto-delete=yes,boot=yes,device-name=windows-connectivity,disk-resource-policy=projects/$(gcloud config get-value project)/regions/us-east1/resourcePolicies/default-schedule-1,image=projects/qwiklabs-resources/global/images/iap-desktop-v001,mode=rw,size=50,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ops-agent-policy=v2-template-1-7-0,goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
&& \
printf 'agentsRule:\n  packageState: installed\n  version: latest\ninstanceFilter:\n  inclusionLabels:\n  - labels:\n      goog-ops-agent-policy: v2-template-1-7-0\n' > config.yaml \
&& \
gcloud compute instances ops-agents policies create goog-ops-agent-v2-template-1-7-0-us-east1-b \
    --project=$(gcloud config get-value project) \
    --zone=us-east1-b \
    --file=config.yaml
    
``` 

### Task4


```bash
gcloud compute --project=$(gcloud config get-value project) firewall-rules create allow-ingress-from-iap --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:22,tcp:3389 --source-ranges=35.235.240.0/20
```
