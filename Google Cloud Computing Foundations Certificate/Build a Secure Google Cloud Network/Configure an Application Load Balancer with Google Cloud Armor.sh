# ------------------------------------------------------------------------------
# 1. Obtención de datos del proyecto actual
# ------------------------------------------------------------------------------
export MY_PROJECT=$(gcloud config get-value project)
export MY_PROJECT_NUM=$(gcloud projects describe "$MY_PROJECT" --format="value(projectNumber)")

# ------------------------------------------------------------------------------
# Task 1: Reglas de Firewall
# ------------------------------------------------------------------------------
gcloud compute firewall-rules create default-allow-http \
    --project="$MY_PROJECT" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

gcloud compute firewall-rules create default-allow-health-check \
    --project="$MY_PROJECT" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=http-server

# ------------------------------------------------------------------------------
# Task 2: Plantillas de Instancia (Instance Templates)
# ------------------------------------------------------------------------------
gcloud compute instance-templates create us-east1-template \
    --project="$MY_PROJECT" \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --metadata=startup-script-url=gs://spls/gsp215/gcpnet/httplb/startup.sh \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account="${MY_PROJECT_NUM}-compute@developer.gserviceaccount.com" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --region=us-east1 \
    --tags=http-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=us-east1-template,image=projects/debian-cloud/global/images/debian-13-trixie-v20260921,mode=rw,size=10,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --reservation-affinity=any

gcloud compute instance-templates create europe-west1-template \
    --project="$MY_PROJECT" \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --metadata=startup-script-url=gs://spls/gsp215/gcpnet/httplb/startup.sh \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account="${MY_PROJECT_NUM}-compute@developer.gserviceaccount.com" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --region=europe-west1 \
    --tags=http-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=europe-west1-template,image=projects/debian-cloud/global/images/debian-13-trixie-v20260921,mode=rw,size=10,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --reservation-affinity=any

# ------------------------------------------------------------------------------
# Task 2: Grupos de Instancias Administrados (MIGs) y Autoscaling
# ------------------------------------------------------------------------------
# MIG: us-east1
gcloud beta compute instance-groups managed create us-east1-mig \
    --project="$MY_PROJECT" \
    --base-instance-name=us-east1-mig \
    --template="projects/${MY_PROJECT}/global/instanceTemplates/us-east1-template" \
    --size=1 \
    --zones=us-east1-b,us-east1-c,us-east1-d \
    --target-distribution-shape=BALANCED \
    --instance-redistribution-type=none \
    --default-action-on-vm-failure=repair \
    --action-on-vm-failed-health-check=default-action \
    --on-repair-allow-changing-zone=yes \
    --force-update-on-repair \
    --standby-policy-mode=manual \
    --list-managed-instances-results=paginated \
    --target-size-policy-mode=individual \
&& \
gcloud beta compute instance-groups managed set-autoscaling us-east1-mig \
    --project="$MY_PROJECT" \
    --region=us-east1 \
    --mode=on \
    --min-num-replicas=1 \
    --max-num-replicas=2 \
    --target-cpu-utilization=0.8 \
    --cpu-utilization-predictive-method=none \
    --cool-down-period=45 \
    --stabilization-period=600

# MIG: europe-west1
gcloud beta compute instance-groups managed create europe-west1-mig \
    --project="$MY_PROJECT" \
    --base-instance-name=europe-west1-mig \
    --template="projects/${MY_PROJECT}/global/instanceTemplates/europe-west1-template" \
    --size=1 \
    --zones=europe-west1-b,europe-west1-d,europe-west1-c \
    --target-distribution-shape=BALANCED \
    --instance-redistribution-type=none \
    --default-action-on-vm-failure=repair \
    --action-on-vm-failed-health-check=default-action \
    --on-repair-allow-changing-zone=yes \
    --force-update-on-repair \
    --standby-policy-mode=manual \
    --list-managed-instances-results=paginated \
    --target-size-policy-mode=individual \
&& \
gcloud beta compute instance-groups managed set-autoscaling europe-west1-mig \
    --project="$MY_PROJECT" \
    --region=europe-west1 \
    --mode=on \
    --min-num-replicas=1 \
    --max-num-replicas=2 \
    --target-cpu-utilization=0.8 \
    --cpu-utilization-predictive-method=none \
    --cool-down-period=45 \
    --stabilization-period=600
