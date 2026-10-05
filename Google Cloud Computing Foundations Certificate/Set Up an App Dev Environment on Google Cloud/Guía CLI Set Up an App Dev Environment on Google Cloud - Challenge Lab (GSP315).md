# Guía CLI: Set Up an App Dev Environment on Google Cloud - Challenge Lab (GSP315)

Esta guía te permitirá resolver el laboratorio completamente desde Cloud Shell. Se incluyen los permisos necesarios para evitar los errores comunes de despliegue con Eventarc (Cloud Run Functions de 2da generación) y la gestión del segundo usuario.

## 0. Configuración Inicial y Variables

Antes de comenzar, identifica el **Username 2** en el panel izquierdo de Qwiklabs ("Lab setup and access"). Es el correo del "ingeniero anterior" al que deberemos quitarle los permisos más adelante.

```bash
# 1. Copia el Username 2 del panel de Qwiklabs y pégalo aquí:
export USERNAME_2="student-01-xxxxxxx@qwiklabs.net" 

# 2. Configurar variables dinámicas del entorno
export PROJECT_ID=$(gcloud config get-value project)
export REGION="asia-east1"
export ZONE="asia-east1-b"
export BUCKET_NAME="${PROJECT_ID}-bucket"
export TOPIC_NAME="topic-memories-920"
export FUNCTION_NAME="memories-thumbnail-maker"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# 3. Habilitar todas las APIs necesarias para Cloud Run Functions y Eventarc
gcloud services enable \
    cloudfunctions.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com \
    eventarc.googleapis.com \
    pubsub.googleapis.com
```

## Task 1: Create a bucket

Creamos el bucket para almacenar las fotografías en la región especificada.

```bash
gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION
```
*(Haz clic en **Check my progress** para la Tarea 1)*

## Task 2: Create a Pub/Sub topic

Creamos el tema de Pub/Sub donde la función enviará los mensajes.

```bash
gcloud pubsub topics create $TOPIC_NAME
```
*(Haz clic en **Check my progress** para la Tarea 2)*

## Task 3: Create the thumbnail Cloud Run Function

Este paso es el más complejo. Para que una función de 2da generación reaccione a eventos de Cloud Storage, requiere que las cuentas de servicio tengan roles específicos de Eventarc y Pub/Sub.

### 3.1. Otorgar permisos de IAM (Pre-requisito crítico)

```bash
# Otorgar rol Event Receiver a la cuenta de servicio de Compute Engine
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/eventarc.eventReceiver"

# Otorgar rol Token Creator a la cuenta de servicio de Pub/Sub
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountTokenCreator"

# Esperar unos segundos para que los permisos se propaguen
sleep 15
```

### 3.2. Crear los archivos de la aplicación

```bash
mkdir ~/thumbnail-app && cd ~/thumbnail-app

# Crear el archivo index.js
cat > index.js << 'EOF'
const functions = require('@google-cloud/functions-framework');
const {Storage} = require('@google-cloud/storage');
const {PubSub} = require('@google-cloud/pubsub');
const sharp = require('sharp');

functions.cloudEvent('memories-thumbnail-maker', async cloudEvent => {
  const event = cloudEvent.data;
  console.log(`Event: ${JSON.stringify(event)}`);
  console.log(`event.bucket: ${event.bucket}`);
  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = new Storage().bucket(bucketName);
  const topicName = 'topic-memories-920';
  const pubsub = new PubSub();
  
  if (fileName.search("64x64_thumbnail") == -1) {
    var filename_split = fileName.split('.');
    var filename_ext = filename_split[filename_split.length - 1].toLowerCase();
    var filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length - 1);
    if (filename_ext == 'png' || filename_ext == 'jpg' || filename_ext == 'jpeg') {
      console.log(`Processing Original: gs://${bucketName}/${fileName}`);
      const gcsObject = bucket.file(fileName);
      const newFilename = `${filename_without_ext}-64x64_thumbnail.${filename_ext}`;
      const gcsNewObject = bucket.file(newFilename);
      try {
        const [buffer] = await gcsObject.download();
        const resizedBuffer = await sharp(buffer)
          .resize(64, 64, { fit: 'inside', withoutEnlargement: true })
          .toFormat(filename_ext == 'jpg' ? 'jpeg' : filename_ext)
          .toBuffer();
        await gcsNewObject.save(resizedBuffer, {
          metadata: { contentType: `image/${filename_ext}` }
        });
        console.log(`Success: gs://${bucketName}/${newFilename}`);
        
        await pubsub.topic(topicName).publishMessage({ data: Buffer.from(newFilename) });
        console.log(`Message published to ${topicName}`);
      } catch (err) {
        console.error(`Error: ${err}`);
      }
    } else {
      console.log(`gs://${bucketName}/${fileName} is not an image I can handle`);
    }
  } else {
    console.log(`gs://${bucketName}/${fileName} already has a thumbnail`);
  }
});
EOF

# Crear el archivo package.json
cat > package.json << 'EOF'
{
  "name": "thumbnails",
  "version": "1.0.0",
  "description": "Create Thumbnail of uploaded image",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0",
    "@google-cloud/pubsub": "^3.0.0",
    "@google-cloud/storage": "^6.0.0",
    "sharp": "^0.32.1"
  },
  "devDependencies": {},
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
```

### 3.3. Desplegar la función (2da Generación)

El despliegue tomará un par de minutos.

```bash
gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=nodejs20 \
    --region=$REGION \
    --source=. \
    --entry-point=memories-thumbnail-maker \
    --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
    --trigger-event-filters="bucket=$BUCKET_NAME" \
    --trigger-location=$REGION
```

### 3.4. Probar la función subiendo una imagen

Descargamos una imagen de prueba proporcionada por Google y la subimos a tu bucket para desencadenar la función.

```bash
curl -o map.jpg https://storage.googleapis.com/cloud-training/gsp315/map.jpg
gcloud storage cp map.jpg gs://$BUCKET_NAME/
```
*(Haz clic en **Check my progress** para la Tarea 3)*

## Task 4: Remove the previous cloud engineer

El antiguo ingeniero de la nube sigue teniendo acceso al proyecto con el rol de Visualizador (`roles/viewer`). Procederemos a revocar su acceso utilizando la variable que configuramos en el paso 0.

```bash
gcloud projects remove-iam-policy-binding $PROJECT_ID \
    --member="user:$USERNAME_2" \
    --role="roles/viewer"
```
*(Haz clic en **Check my progress** para la Tarea 4)*