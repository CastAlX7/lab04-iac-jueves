import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { v4 as uuidv4 } from 'uuid';
import busboy from 'busboy';

const s3 = new S3Client({});

// saca el archivo de multipart
function parseMultipart(event) {
    return new Promise((resolve, reject) => {
        const bb = busboy({ headers: event.headers });
        let fileBuffer = null;
        let mimeType = 'image/png';

        bb.on('file', (_field, file, info) => {
            mimeType = info.mimeType || 'image/png';
            const chunks = [];
            file.on('data', (chunk) => chunks.push(chunk));
            file.on('end', () => { fileBuffer = Buffer.concat(chunks); });
        });

        bb.on('finish', () => resolve({ fileBuffer, mimeType }));
        bb.on('error', reject);

        const body = event.isBase64Encoded
            ? Buffer.from(event.body, 'base64')
            : Buffer.from(event.body, 'utf8');

        bb.write(body);
        bb.end();
    });
}

export const handler = async (event) => {
    console.log("Evento recibido:", JSON.stringify(event));
    try {
        const bucket = process.env.S3_BUCKET;
        const prefix = process.env.UPLOAD_PREFIX;
        const contentType = event.headers['content-type'] || event.headers['Content-Type'] || '';
        const fileName = `${uuidv4()}.png`;

        let fileBuffer;
        let fileMimeType;

        // detecta si es multipart o json/base64

        if (contentType.startsWith('multipart/form-data')) {
            const parsed = await parseMultipart(event);
            fileBuffer = parsed.fileBuffer;
            fileMimeType = parsed.mimeType;
        } else {
            // asume base64 directo o json
            fileBuffer = event.isBase64Encoded
                ? Buffer.from(event.body, 'base64')
                : Buffer.from(event.body);
            fileMimeType = contentType || 'image/png';
        }

        if (!fileBuffer || fileBuffer.length === 0) {
            return { statusCode: 400, body: JSON.stringify({ error: "El cuerpo de la imagen está vacío" }) };
        }

        const MAX_SIZE = 10 * 1024 * 1024; // 10MB
        if (fileBuffer.length > MAX_SIZE) {
            return { statusCode: 400, body: JSON.stringify({ error: "La imagen excede el límite de 10MB" }) };
        }

        const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/jpg', 'image/gif', 'image/webp'];
        if (!allowedMimeTypes.includes(fileMimeType)) {
            return { statusCode: 400, body: JSON.stringify({ error: "Formato no válido. Solo se permite jpg, png, gif y webp" }) };
        }

        const extMap = { 'image/jpeg': 'jpeg', 'image/jpg': 'jpeg', 'image/gif': 'gif', 'image/webp': 'webp' };
        const extension = extMap[fileMimeType] ?? 'png';
        const finalFileName = `${fileName.split('.')[0]}.${extension}`;

        // sube a s3
        await s3.send(new PutObjectCommand({
            Bucket: bucket,
            Key: `${prefix}${finalFileName}`,
            Body: fileBuffer,
            ContentType: fileMimeType
        }));

        return {
            statusCode: 201,
            body: JSON.stringify({ message: "Imagen recibida", file: finalFileName })
        };
    } catch (err) {
        console.error("ERROR CRITICO:", err.message);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: err.message, stack: err.stack })
        };
    }
};