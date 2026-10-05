# Guía CLI: Build a Secure Google Cloud Network - Challenge Lab (GSP322)

Esta guía documenta cómo resolver el Challenge Lab de seguridad en redes completamente desde Cloud Shell. Este laboratorio se centra en la aplicación de principios de menor privilegio utilizando reglas de firewall de VPC, Network Tags e Identity-Aware Proxy (IAP).

## 0. Configuración Inicial y Variables Dinámicas

**¡IMPORTANTE!** En este laboratorio, los *Network Tags* y la *Zona* cambian en cada sesión. Debes copiarlos del panel izquierdo de Qwiklabs ("Lab setup and access") y pegarlos en estas variables antes de ejecutar el resto del código.

```
# 1. REEMPLAZA estos valores con los de tu panel lateral de Qwiklabs:
export ZONE="asia-southeast1-b" 
export TAG_IAP="allow-ssh-iap-ingress-ql-269"
export TAG_INTERNAL="allow-ssh-internal-ingress-ql-269"
export TAG_HTTP="allow-http-ingress-ql-269"

# 2. Configurar la zona base
gcloud config set compute/zone $ZONE

# 3. Obtener dinámicamente la Región y la Red de trabajo
export REGION=$(echo $ZONE | sed 's/-[a-z]$//')
export NETWORK=$(gcloud compute instances describe bastion --zone=$ZONE --format="value(networkInterfaces[0].network)")

```

## Task 1: Remove the overly permissive rules

Existe una regla creada por "el hijo del vecino de Jeff" que permite acceso total desde cualquier lugar. Generalmente se llama `open-access`. Debemos eliminarla.

```
# Listar las reglas para verificar (busca la que tiene sourceRanges: 0.0.0.0/0 y allow: all)
gcloud compute firewall-rules list

# Borrar la regla permisiva
gcloud compute firewall-rules delete open-access --quiet

```

*(Haz clic en **Check my progress** para la Tarea 1)*

## Task 2: Start the bastion host instance

El host bastión se encuentra detenido. Debemos iniciarlo para poder usarlo como puente hacia nuestra red interna.

```
gcloud compute instances start bastion --zone=$ZONE

```

*(Haz clic en **Check my progress** para la Tarea 2)*

## Task 3: Create a firewall rule for IAP SSH to Bastion

Para acceder de forma segura sin exponer IPs públicas, permitiremos el tráfico SSH (puerto 22) única y exclusivamente desde el rango de IPs de Google Cloud IAP (`35.235.240.0/20`), aplicándolo solo al Bastión.

```
# 1. Crear la regla de firewall para IAP
gcloud compute firewall-rules create allow-ssh-iap-ingress \
    --network=$NETWORK \
    --allow=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --target-tags=$TAG_IAP

# 2. Aplicar el Tag de red al host bastion
gcloud compute instances add-tags bastion --tags=$TAG_IAP --zone=$ZONE

```

*(Haz clic en **Check my progress** para la Tarea 3)*

## Task 4: Create a firewall rule for HTTP to juice-shop

El servidor web `juice-shop` necesita servir tráfico HTTP (puerto 80) al mundo entero (`0.0.0.0/0`).

```
# Crear la regla de firewall para HTTP
gcloud compute firewall-rules create allow-http-ingress \
    --network=$NETWORK \
    --allow=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=$TAG_HTTP

```

*(No aplicaremos el Tag a juice-shop todavía, lo haremos junto con la Tarea 5 para optimizar)*
*(Haz clic en **Check my progress** para la Tarea 4)*

## Task 5: Create a firewall rule for internal SSH to juice-shop

Solo permitiremos conexiones SSH a `juice-shop` si provienen de la subred de administración (`acme-mgmt-subnet`).

```
# 1. Obtener dinámicamente el rango CIDR (IPs) de la subred acme-mgmt-subnet
export SUBNET_CIDR=$(gcloud compute networks subnets describe acme-mgmt-subnet --region=$REGION --format="value(ipCidrRange)")

# 2. Crear la regla de firewall interna
gcloud compute firewall-rules create allow-ssh-internal-ingress \
    --network=$NETWORK \
    --allow=tcp:22 \
    --source-ranges=$SUBNET_CIDR \
    --target-tags=$TAG_INTERNAL

# 3. Aplicar AMBOS Tags (HTTP y SSH Interno) al servidor juice-shop
gcloud compute instances add-tags juice-shop --tags=$TAG_HTTP,$TAG_INTERNAL --zone=$ZONE

```

*(Haz clic en **Check my progress** para la Tarea 5)*

## Task 6: SSH to bastion host via IAP and juice-shop via bastion

Finalmente, debemos demostrar que la ruta de conexión funciona. Nos conectaremos al bastión a través del túnel IAP y, desde dentro del bastión, saltaremos a `juice-shop`.

```
# Ejecutar un comando anidado: Conecta al bastión por IAP y automáticamente hace SSH a juice-shop
gcloud compute ssh bastion --zone=$ZONE --tunnel-through-iap \
    --command="gcloud compute ssh juice-shop --internal-ip --zone=$ZONE --quiet"

```

> ⚠️ **Troubleshooting Task 6:**
> Si el comando anterior falla por propagación de llaves SSH, puedes hacerlo manualmente en dos pasos:
>
> 1. Obtén la IP interna de juice-shop:
>    `gcloud compute instances describe juice-shop --zone=$ZONE --format="value(networkInterfaces[0].networkIP)"`
>
> 2. Entra al bastion:
>    `gcloud compute ssh bastion --zone=$ZONE --tunnel-through-iap`
>
> 3. Una vez dentro del bastion (la terminal cambiará a `usuario@bastion`), usa la IP obtenida para conectar:
>    `ssh <IP_INTERNA_DE_JUICE_SHOP>`
>
> 4. Escribe `yes` y presiona enter. Luego escribe `exit` dos veces para regresar a Cloud Shell.

*(Haz clic en **Check my progress** para la Tarea 6)*