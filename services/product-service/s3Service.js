const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

// Configure S3 Client using environment variables with ap-south-1 default
const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'ap-south-1',
  endpoint: process.env.AWS_ENDPOINT_URL || undefined, // Enabled for LocalStack / local emulation
  forcePathStyle: !!process.env.AWS_ENDPOINT_URL,
});

const BUCKET_NAME = process.env.PRODUCT_IMAGES_BUCKET || 'smartretailx-product-images-production';

/**
 * Uploads a product catalogue image file to Amazon S3.
 *
 * @param {string} fileName - Target object key name inside the S3 bucket path prefix.
 * @param {Buffer|Blob|string} fileBody - Content body of the image file to upload.
 * @param {string} contentType - MIME content-type of the product image (e.g., 'image/jpeg', 'image/png').
 * @returns {Promise<string>} - Returns the URL endpoint of the uploaded image file.
 */
async function uploadProductImage(fileName, fileBody, contentType) {
  const uploadParams = {
    Bucket: BUCKET_NAME,
    Key: `products/${fileName}`,
    Body: fileBody,
    ContentType: contentType,
  };

  try {
    const command = new PutObjectCommand(uploadParams);
    await s3Client.send(command);
    console.log(`[S3 UPLOAD] Successfully uploaded ${fileName} to bucket ${BUCKET_NAME}`);
    
    // Construct public S3 Object URL (standard regional endpoint structure)
    if (process.env.AWS_ENDPOINT_URL) {
      return `${process.env.AWS_ENDPOINT_URL}/${BUCKET_NAME}/products/${fileName}`;
    }
    return `https://${BUCKET_NAME}.s3.${process.env.AWS_REGION || 'ap-south-1'}.amazonaws.com/products/${fileName}`;
  } catch (error) {
    console.error(`[S3 ERROR] Failed uploading ${fileName} to S3:`, error.message);
    throw new Error(`S3 Object upload failed: ${error.message}`);
  }
}

module.exports = {
  s3Client,
  uploadProductImage,
};
