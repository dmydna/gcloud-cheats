# Guía CLI: Prepare Data for ML APIs on Google Cloud - Challenge Lab (GSP323)

Esta guía documenta cómo resolver el Challenge Lab íntegramente desde la terminal de Cloud Shell, sorteando los errores comunes de políticas de región, redes no listas y restricciones de API Keys en Qwiklabs.

## 0. Configuración Inicial y Exploración

Antes de empezar, debes configurar las variables de entorno. Qwiklabs restringe las regiones donde puedes crear recursos. Revisa el panel de instrucciones de tu laboratorio para ver qué región te fue asignada (ej. `us-east1`, `us-central1`, etc.).

```bash
# 1. Definir Project ID y Bucket Name dinámicamente
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME="${PROJECT_ID}-marking"

# 2. Configurar la Región (REEMPLAZA con tu región asignada en el lab)
export REGION="us-east1" 
gcloud config set compute/region $REGION

# 3. Listar las zonas disponibles para tu región asignada
gcloud compute zones list --filter="region:($REGION)"

# 4. Elegir una zona de la lista anterior (que tenga status UP) y configurarla
export ZONE="us-east1-b" # Reemplaza según corresponda
gcloud config set compute/zone $ZONE

# 5. Habilitar las APIs necesarias para todo el laboratorio
gcloud services enable \
    speech.googleapis.com \
    language.googleapis.com \
    apikeys.googleapis.com
```

---

## Task 1: Run a simple Dataflow job

Creamos el dataset en BigQuery, el bucket en Cloud Storage y lanzamos el trabajo batch usando un template predefinido.

```bash
# Crear dataset en BigQuery
bq mk lab_448

# Crear bucket en GCS asegurando que esté en la región permitida
gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION

# Ejecutar el trabajo en Dataflow
gcloud dataflow jobs run dataflow-batch-job \
    --gcs-location=gs://dataflow-templates/latest/GCS_Text_to_BigQuery \
    --region=$REGION \
    --worker-machine-type=e2-standard-2 \
    --staging-location=gs://$BUCKET_NAME/temp \
    --parameters \
javascriptTextTransformGcsPath=gs://spls/gsp323/lab.js,\
JSONPath=gs://spls/gsp323/lab.schema,\
javascriptTextTransformFunctionName=transform,\
outputTable=$PROJECT_ID:lab_448.customers_401,\
inputFilePattern=gs://spls/gsp323/lab.csv,\
bigQueryLoadingTemporaryDirectory=gs://$BUCKET_NAME/bigquery_temp
```
*Nota: No es necesario esperar a que termine el job en la terminal para lanzar los siguientes comandos, Dataflow corre en segundo plano.*

---

## Task 2: Run a simple Managed Apache Spark job

> ⚠️ **ATENCIÓN: Posible error de Subred y ALREADY_EXISTS** 
> Si al ejecutar el comando de creación del clúster recibes un error indicando que la subred `default` no está lista, **espera 1 a 2 minutos**. 
> Si al reintentar te aparece un error `ALREADY_EXISTS` y el paso SSH falla indicando `resource not found`, el clúster quedó en estado fallido (fantasma). 
> **Solución:** Elimina el clúster atascado ejecutando: 
> `gcloud dataproc clusters delete spark-cluster --region=$REGION --quiet` 
> Una vez borrado, vuelve a ejecutar el comando de creación.

```bash
# 1. Crear el clúster de Dataproc
gcloud dataproc clusters create spark-cluster \
    --region=$REGION \
    --zone=$ZONE \
    --master-machine-type=n2d-standard-2 \
    --master-boot-disk-size=100GB \
    --master-boot-disk-type=pd-standard \
    --num-workers=2 \
    --worker-machine-type=n2d-standard-2 \
    --worker-boot-disk-size=100GB \
    --worker-boot-disk-type=pd-standard

# 2. Copiar el dataset al HDFS del nodo maestro
gcloud compute ssh spark-cluster-m --zone=$ZONE \
    --command="hdfs dfs -cp gs://spls/gsp323/data.txt /data.txt"

# 3. Enviar el trabajo Spark
gcloud dataproc jobs submit spark \
    --cluster=spark-cluster \
    --region=$REGION \
    --class=org.apache.spark.examples.SparkPageRank \
    --jars=file:///usr/lib/spark/examples/jars/spark-examples.jar \
    --max-failures-per-hour=1 \
    -- /data.txt
```

---

## Preparación para Tasks 3 y 4: Autenticación con API Key

Debido a que el laboratorio restringe las credenciales OAuth para peticiones directas, debemos generar una API Key restringida estrictamente a los servicios solicitados para evitar errores `403 Forbidden` y bloqueos de seguridad de Qwiklabs.

```bash
# 1. Crear la API Key con restricciones de destino (target)
gcloud services api-keys create --display-name="ml-key" \
    --api-target=service=speech.googleapis.com \
    --api-target=service=language.googleapis.com

# 2. Dar tiempo a que las políticas se propaguen (esperar 5-10 segs)
sleep 10

# 3. Extraer el valor de la API Key a una variable
KEY_RESOURCE=$(gcloud services api-keys list --filter="displayName=ml-key" --format="value(name)" --limit=1)
export API_KEY=$(gcloud services api-keys get-key-string $KEY_RESOURCE --format="value(keyString)")
```

---

## Task 3: Use the Google Cloud Speech-to-Text API

```bash
# 1. Crear el payload JSON
cat > speech_req.json <<EOF
{
  "config": {"encoding": "FLAC", "languageCode": "en-US"},
  "audio": {"uri": "gs://spls/gsp323/task3.flac"}
}
EOF

# 2. Ejecutar petición usando la API Key
curl -s -X POST -H "Content-Type: application/json" \
    "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
    -d @speech_req.json > task3-gcs-989.result

# 3. Subir al bucket forzando el Content-Type requerido
gsutil -h "Content-Type: application/json" cp task3-gcs-989.result gs://$BUCKET_NAME/task3-gcs-989.result
```

---

## Task 4: Use the Cloud Natural Language API

```bash
# 1. Crear el payload JSON con la cadena de texto exacta
cat > nlp_req.json <<EOF
{
  "document": {
    "type": "PLAIN_TEXT",
    "content": "Old Norse texts portray Odin as one-eyed and long-bearded frequently wielding a spear named Gungnir and wearing a cloak and a broad hat."
  },
  "encodingType": "UTF8"
}
EOF

# 2. Ejecutar petición usando la API Key
curl -s -X POST -H "Content-Type: application/json" \
    "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
    -d @nlp_req.json > task4-cnl-382.result

# 3. Subir al bucket forzando el Content-Type requerido
gsutil -h "Content-Type: application/json" cp task4-cnl-382.result gs://$BUCKET_NAME/task4-cnl-382.result
```

Una vez finalizado, presiona **"Check my progress"** en la interfaz gráfica para validar los puntos.