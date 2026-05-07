 Lab-04-iac-jueves: Procesamiento de Imágenes Serverless en AWS

Este proyecto implementa una arquitectura automatizada para la carga y procesamiento de imágenes en AWS utilizando Terraform. El sistema permite subir imágenes a través de un API, las cuales son redimensionadas automáticamente a un formato circular de 40x40 píxeles mediante un flujo basado en eventos.

## Estructura del Proyecto

```text
Lab-04-iac-jueves/
├── src/
│   ├── lambdas/
│   │   ├── upload/          # Lambda para recepción y carga en S3
│   │   └── crop/            # Lambda para procesamiento (Sharp)
│   └── images/              # Recursos de prueba
├── iac/
│   ├── modules/             # Módulos de infraestructura
│   │   ├── network/         # VPC, Subnets y Gateways
│   │   ├── storage/         # S3 y SQS
│   │   ├── compute/         # Lambdas y API Gateway
│   │   └── iam/             # Roles y Permisos
│   ├── main.tf              # Orquestación de módulos
│   ├── providers.tf         # Configuración de AWS
│   └── variables.tf         # Definiciones globales
└── README.md
```

## Componentes Técnicos

### Infraestructura de Red
*   **VPC Aislada**: Red segmentada con subredes públicas para los Gateways y subredes privadas para las funciones Lambda.
*   **Seguridad**: Reglas de Security Groups que restringen el tráfico solo a lo necesario (puerto 443).
*   **VPC Endpoints**: Conexión privada hacia S3 y SQS para evitar que el tráfico de datos salga a internet.

### Flujo de Datos
1.  **API Gateway**: Punto de entrada HTTP que recibe la imagen original.
2.  **Upload Lambda**: Valida el contenido y almacena la imagen en el prefijo `uploads/` de S3.
3.  **Notificación SQS**: S3 notifica a la cola cuando un objeto es creado.
4.  **Crop Lambda**: Escucha la cola SQS, procesa la imagen a 40x40px (formato circular) y la guarda en el prefijo `processed/`.

### Almacenamiento y Resiliencia
*   **S3 Bucket**: Versionado habilitado y políticas de ciclo de vida para limpieza automática.
*   **Dead Letter Queue (DLQ)**: Cola de mensajes fallidos para capturar errores de procesamiento.

---

## Guía de Despliegue

### 1. Preparación del Entorno
Es necesario tener instalado Terraform, AWS CLI y Node.js. Asegúrate de configurar tus credenciales de AWS:
```bash
aws configure
```

### 2. Instalación de Dependencias
Antes de desplegar, instala las librerías necesarias en las funciones Lambda:
```bash
# Para la función de carga
cd src/lambdas/upload && npm install

# Para la función de recorte
cd ../crop && npm install
```

### 3. Ejecución de Terraform
Navega a la carpeta de infraestructura y utiliza workspaces para gestionar tus entornos (DEV, PROD, etc.):

```bash
cd iac/

# Inicializar el proyecto
terraform init

# Seleccionar o crear un entorno
terraform workspace select DEV || terraform workspace new DEV

# Aplicar los cambios
terraform apply
```

### 4. Pruebas de Funcionamiento
Puedes probar el despliegue enviando una imagen al endpoint generado:
```bash
curl -X POST -H "Content-Type: image/jpeg" --data-binary "@src/images/test.jpg" [URL_DEL_API]/upload
```

Luego, verifica en la consola de S3 que el archivo aparezca procesado en la carpeta `processed/`.
