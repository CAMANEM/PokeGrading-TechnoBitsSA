const { MongoClient, GridFSBucket } = require("mongodb");
const fs = require("fs");
const path = require("path");

const MONGO_URL = process.env.MONGO_URL || "mongodb://mongodb:27017";
const DB_NAME = process.env.MONGO_DB_NAME || "pokegrading_images";
const IMAGES_DIR = process.env.IMAGES_DIR || "/app/images";

const CARDS = [
  { id: 1,  name: "Applin",     file: "Applin_Reference.png" },
  { id: 2,  name: "Arcanine",   file: "Arcanine_Reference.png" },
  { id: 3,  name: "Chingling",  file: "Chingling_Reference.png" },
  { id: 4,  name: "Combusken",  file: "Combusken_Reference.png" },
  { id: 5,  name: "Dipplin",    file: "Dipplin_Reference.png" },
  { id: 6,  name: "Dwebble",    file: "Dwebble_Reference.png" },
  { id: 7,  name: "Electric",   file: "Electric_Reference.png" },
  { id: 8,  name: "Growlithe",  file: "Growlithe_Reference.png" },
  { id: 9,  name: "Houdoom",    file: "Houdoom_Reference.png" },
  { id: 10, name: "Lapras",     file: "Lapras_Reference.png" },
  { id: 11, name: "Magcargo",   file: "Mackargo_Reference.png" },
  { id: 12, name: "Mimikyu",    file: "Mimilyu_Reference.png" },
  { id: 13, name: "Primeape",   file: "Primeape_Reference.png" },
  { id: 14, name: "Psyduck",    file: "Pysduck_Reference.png" },
  { id: 15, name: "Typhlosion", file: "Typhlosion_Reference.png" },
  { id: 16, name: "Wobbuffet",  file: "Wubbofet_Reference.png" },
];

const BACK_FILE = "Card_Back_Reference.png";

async function uploadFile(bucket, filePath, gridfsFilename) {
  const fileBuffer = fs.readFileSync(filePath);
  const uploadStream = bucket.openUploadStream(gridfsFilename, {
    contentType: "image/png",
    metadata: {},
  });

  return new Promise((resolve, reject) => {
    const readStream = require("stream").Readable.from(fileBuffer);
    readStream.pipe(uploadStream);
    uploadStream.on("finish", () => resolve(uploadStream.id));
    uploadStream.on("error", reject);
  });
}

async function main() {
  console.log("=== PokeGrading: upload_references starting ===");

  const client = new MongoClient(MONGO_URL);
  await client.connect();
  const db = client.db(DB_NAME);

  const refImages = db.collection("reference_images");
  const bucket = new GridFSBucket(db, { bucketName: "reference_fs" });

  await refImages.deleteMany({});
  console.log("  Cleared existing reference_images");

  let inserted = 0;

  // Upload the shared back image once
  const backPath = path.join(IMAGES_DIR, BACK_FILE);
  if (!fs.existsSync(backPath)) {
    console.error("  ERROR: Back image not found:", backPath);
    process.exit(1);
  }
  const backFileId = await uploadFile(bucket, backPath, BACK_FILE);
  console.log("  Uploaded back image:", BACK_FILE, "->", backFileId);

  for (const card of CARDS) {
    const frontPath = path.join(IMAGES_DIR, card.file);
    if (!fs.existsSync(frontPath)) {
      console.error("  WARNING: Front image not found:", frontPath, "- skipping card", card.id);
      continue;
    }

    const gridfsFilename = `reference_${card.id}_front_${Date.now()}`;
    const frontFileId = await uploadFile(bucket, frontPath, gridfsFilename);
    console.log("  Uploaded front:", card.name, "->", frontFileId);

    await refImages.insertOne({
      card_reference_id: card.id,
      side: "front",
      file_id: frontFileId,
      content_type: "image/png",
      uploaded_at: new Date(),
    });

    const backGridfsName = `reference_${card.id}_back_${Date.now()}`;
    const backRefId = await uploadFile(bucket, backPath, backGridfsName);
    console.log("  Uploaded back:", card.name, "->", backRefId);

    await refImages.insertOne({
      card_reference_id: card.id,
      side: "back",
      file_id: backRefId,
      content_type: "image/png",
      uploaded_at: new Date(),
    });

    inserted += 2;
  }

  console.log("=== PokeGrading: upload_references done — inserted:", inserted, "reference_images ===");
  await client.close();
}

main().catch((err) => {
  console.error("=== PokeGrading: upload_references FAILED ===", err);
  process.exit(1);
});
