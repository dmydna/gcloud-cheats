```markdown
# Guía de Solución: Implement Load Balancing on Compute Engine (GSP313)

Esta guía consolida la configuración de los balanceadores de red (Capa 4) y HTTP (Capa 7) en un solo flujo continuo. Incluye las correcciones necesarias para superar las validaciones de regex de Qwiklabs (`\$HOSTNAME`) y la exigencia de IP estática global para la Tarea 3.

## 1. Configuración Inicial
Define tu región y zona basándote en el panel de instrucciones de Qwiklabs.

```bash
# REEMPLAZA ESTOS VALORES CON LOS DE TU LABORATORIO
export REGION="us-central1"
export ZONE="us-central1-b"

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

```

## 2. Task 1: Create multiple web server instances

Se crea la regla de firewall y las tres instancias simultáneamente. El script de inicio utiliza un formato específico (`\$HOSTNAME`) para evadir la expansión de variables en Cloud Shell y coincidir exactamente con el regex del evaluador de Qwiklabs.

```bash
# Crear regla de firewall
gcloud compute firewall-rules create www-firewall-network-lb \
    --network=default \
    --allow=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=network-lb-tag

# Crear las 3 VMs simultáneamente con la metadata estricta
gcloud compute instances create web1 web2 web3 \
    --zone=$ZONE \
    --machine-type=e2-small \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --tags=network-lb-tag \
    --metadata startup-script="#! /bin/bash
apt-get update
apt-get install apache2 -y
service apache2 restart
echo '<!doctype html><html><body><h1>'\$HOSTNAME'</h1></body></html>' | tee /var/www/html/index.html"

```

*Espera aproximadamente 60 segundos para que se instale Apache antes de verificar el progreso en la interfaz.*

## 3. Task 2: Configure the load balancing service

Creación del balanceador de red regional, asociando las tres instancias creadas en el paso anterior.

```bash
# Crear la IP estática regional
gcloud compute addresses create network-lb-ip-1 --region=$REGION

# Crear el health check básico
gcloud compute http-health-checks create basic-check

# Crear el target pool y añadir las instancias
gcloud compute target-pools create www-pool \
    --region=$REGION \
    --http-health-check=basic-check

gcloud compute target-pools add-instances www-pool \
    --instances=web1,web2,web3 \
    --instances-zone=$ZONE

# Crear la regla de reenvío
gcloud compute forwarding-rules create www-rule \
    --region=$REGION \
    --ports=80 \
    --address=network-lb-ip-1 \
    --target-pool=www-pool

```

*Verifica el progreso en la interfaz.*

## 4. Task 3: Create an HTTP load balancer

Creación del balanceador HTTP global utilizando grupos de instancias administrados (MIG). Se incluye la creación de una IP estática global para evitar el error de validación de IP efímera.

```bash
# 1. Crear la plantilla de instancias (Instance Template)
gcloud compute instance-templates create lb-backend-template \
    --region=$REGION \
    --network=default \
    --machine-type=e2-medium \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --tags=network-lb-tag \
    --metadata startup-script="#! /bin/bash
apt-get update
apt-get install apache2 -y
service apache2 restart
echo '<!doctype html><html><body><h1>'\$HOSTNAME'</h1></body></html>' | tee /var/www/html/index.html"

# 2. Crear el Managed Instance Group (MIG)
gcloud compute instance-groups managed create lb-backend-group \
    --zone=$ZONE \
    --size=2 \
    --template=lb-backend-template

# 3. Crear la regla de firewall para los health checks de Google
gcloud compute firewall-rules create fw-allow-health-check \
    --network=default \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=network-lb-tag \
    --rules=tcp:80

# 4. Configurar la IP GLOBAL y el Backend Service
gcloud compute addresses create lb-ipv4-1 --global
gcloud compute health-checks create http http-basic-check --port 80

gcloud compute backend-services create web-backend-service \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-basic-check \
    --global

gcloud compute backend-services add-backend web-backend-service \
    --instance-group=lb-backend-group \
    --instance-group-zone=$ZONE \
    --global

# 5. Configurar el Frontend (URL Map, Proxy y Regla de Reenvío Global)
gcloud compute url-maps create web-map-http \
    --default-service=web-backend-service

gcloud compute target-http-proxies create http-lb-proxy \
    --url-map=web-map-http

export GLOBAL_IP=$(gcloud compute addresses describe lb-ipv4-1 --global --format="value(address)")

gcloud compute forwarding-rules create http-content-rule \
    --address=$GLOBAL_IP \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80

```

*Los balanceadores globales tardan entre 3 y 5 minutos en propagar su configuración. Espera este tiempo antes de presionar el último "Check my progress".*

```

```