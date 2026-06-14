/* =====================================================================
   PokeGrading - Image database creation script
   Engine: MongoDB 6.x / 7.x
   Run with: mongosh "mongodb://localhost:27017/pokegrading_images" create_pokegrading_images.js
   ===================================================================== */

const database = db.getSiblingDB("pokegrading_images");

/* ---------------------------------------------------------------------
   1. SUBMITTER: metadata for user-uploaded card images (front/back)
      Links to card_submitter.id (PostgreSQL) via card_submitter_id
   --------------------------------------------------------------------- */
database.createCollection("submitter_images", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["card_submitter_id", "side", "file_id", "content_type", "uploaded_at"],
      properties: {
        card_submitter_id: {
          bsonType: ["long", "int"],
          description: "FK -> card_submitter.id in PostgreSQL"
        },
        side: {
          enum: ["front", "back"],
          description: "Card face"
        },
        file_id: {
          bsonType: "objectId",
          description: "Points to submitter_fs.files._id (GridFS)"
        },
        content_type: { bsonType: "string" },
        width: { bsonType: "int" },
        height: { bsonType: "int" },
        size_bytes: { bsonType: "long" },
        perceptual_hash: {
          bsonType: "string",
          description: "Quick hash copy for filtering without touching Postgres"
        },
        uploaded_at: { bsonType: "date" }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

database.submitter_images.createIndex(
  { card_submitter_id: 1, side: 1 },
  { unique: true, name: "ux_submitter_card_side" }
);
database.submitter_images.createIndex({ file_id: 1 }, { name: "ix_submitter_file" });
database.submitter_images.createIndex({ perceptual_hash: 1 }, { name: "ix_submitter_phash" });

/* ---------------------------------------------------------------------
   2. REFERENCE: metadata for admin reference pattern images
      Links to card_reference.id (PostgreSQL) via card_reference_id
   --------------------------------------------------------------------- */
database.createCollection("reference_images", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["card_reference_id", "side", "file_id", "content_type", "uploaded_at"],
      properties: {
        card_reference_id: {
          bsonType: ["long", "int"],
          description: "FK -> card_reference.id in PostgreSQL"
        },
        side: { enum: ["front", "back"] },
        file_id: {
          bsonType: "objectId",
          description: "Points to reference_fs.files._id (GridFS)"
        },
        content_type: { bsonType: "string" },
        width: { bsonType: "int" },
        height: { bsonType: "int" },
        size_bytes: { bsonType: "long" },
        perceptual_hash: { bsonType: "string" },
        uploaded_at: { bsonType: "date" }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

database.reference_images.createIndex(
  { card_reference_id: 1, side: 1 },
  { unique: true, name: "ux_reference_card_side" }
);
database.reference_images.createIndex({ file_id: 1 }, { name: "ix_reference_file" });
database.reference_images.createIndex({ perceptual_hash: 1 }, { name: "ix_reference_phash" });

/* ---------------------------------------------------------------------
   3. GridFS: two independent buckets for binary storage
      (submitter_fs.* and reference_fs.*)
   --------------------------------------------------------------------- */

database.createCollection("submitter_fs.files");
database.createCollection("submitter_fs.chunks");
database["submitter_fs.chunks"].createIndex(
  { files_id: 1, n: 1 },
  { unique: true, name: "ux_submitter_chunks" }
);
database["submitter_fs.files"].createIndex(
  { "metadata.card_submitter_id": 1, "metadata.side": 1 },
  { name: "ix_submitter_files_meta" }
);

database.createCollection("reference_fs.files");
database.createCollection("reference_fs.chunks");
database["reference_fs.chunks"].createIndex(
  { files_id: 1, n: 1 },
  { unique: true, name: "ux_reference_chunks" }
);
database["reference_fs.files"].createIndex(
  { "metadata.card_reference_id": 1, "metadata.side": 1 },
  { name: "ix_reference_files_meta" }
);

print("Database 'pokegrading_images' created: collections, validators and indexes ready.");
