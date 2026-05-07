import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import sharp from 'sharp';

const s3 = new S3Client({});

export const handler = async (event) => {
    for (const record of event.Records) {
        // saca info de sqs
        const body = JSON.parse(record.body);
        
        if (body.Event === "s3:TestEvent") {
            console.log("evento de prueba ignorado");
            continue;
        }
        
        const s3Event = body.Records[0].s3;
        const bucket = s3Event.bucket.name;
        const key = decodeURIComponent(s3Event.object.key.replace(/\+/g, ' '));

        try {
            // baja la foto original
            const response = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
            const chunks = [];
            for await (const chunk of response.Body) chunks.push(chunk);
            const buffer = Buffer.concat(chunks);

            // mascara redonda en svg
            const circleShape = Buffer.from(
                '<svg><circle cx="20" cy="20" r="20" /></svg>'
            );

            // procesa con sharp: 40x40 y mascara
            const processed = await sharp(buffer)
                .resize(40, 40, { fit: 'cover' })
                .composite([{
                    input: circleShape,
                    blend: 'dest-in'
                }])
                .png()
                .toBuffer();

            // ruta de salida: de uploads/ a processed/
            const newKey = key.replace('uploads/', 'processed/').replace(/\.[^.]+$/, '.png');

            // sube la foto final
            await s3.send(new PutObjectCommand({
                Bucket: bucket,
                Key: newKey,
                Body: processed,
                ContentType: 'image/png'
            }));

            console.log(`listo: ${newKey}`);
        } catch (error) {
            console.error(`fallo en ${key}:`, error);
            throw error;
        }
    }
};