const cloudinary = require("cloudinary").v2;

let configured = false;

function ensureCloudinary() {
  if (
    !process.env.CLOUDINARY_CLOUD_NAME ||
    !process.env.CLOUDINARY_API_KEY ||
    !process.env.CLOUDINARY_API_SECRET
  ) {
    throw new Error("Cloudinary is not configured");
  }

  if (!configured) {
    cloudinary.config({
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      api_key: process.env.CLOUDINARY_API_KEY,
      api_secret: process.env.CLOUDINARY_API_SECRET,
    });
    configured = true;
  }

  return cloudinary;
}

async function uploadFile(filePath, folder) {
  const client = ensureCloudinary();
  const result = await client.uploader.upload(filePath, {
    folder,
    resource_type: "auto",
  });

  return {
    secure_url: result.secure_url,
    public_id: result.public_id,
  };
}

async function deleteFile(publicId) {
  const client = ensureCloudinary();
  return client.uploader.destroy(publicId, { resource_type: "auto" });
}

module.exports = {
  uploadFile,
  deleteFile,
};
