import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mongo_dart/mongo_dart.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import 'image_storage_repository.dart';

/// MongoDB GridFS implementation for card images (submitter and reference).
class MongoImageRepository implements ImageStorageRepository {
  final Db _db;

  MongoImageRepository._(this._db);

  static Future<MongoImageRepository> connect(MongoConfig config) async {
    AppLogger.info(
      'PokéGrading.Persistence.MongoImageRepository',
      'Connecting to MongoDB image storage',
      context: {'db': config.dbName},
    );
    try {
      final db = Db(config.uri);
      await db.open();
      AppLogger.info(
        'PokéGrading.Persistence.MongoImageRepository',
        'MongoDB image repository connected',
      );
      return MongoImageRepository._(db);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.MongoImageRepository',
        'Failed to connect to MongoDB',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  DbCollection get _metadata => _db.collection('submitter_images');
  DbCollection get _referenceMetadata => _db.collection('reference_images');

  GridFS get _gridFs => GridFS(_db, 'submitter_fs');
  GridFS get _referenceGridFs => GridFS(_db, 'reference_fs');

  @override
  Future<void> saveSubmitterImages({
    required int cardSubmitterId,
    required String frontBase64,
    required String backBase64,
    String? perceptualHash,
  }) async {
    AppLogger.info(
      'PokéGrading.Persistence.MongoImageRepository',
      'Saving submitter images',
      context: {'card_submitter_id': cardSubmitterId},
    );

    try {
      await _saveSide(
        cardSubmitterId: cardSubmitterId,
        side: 'front',
        imageBase64: frontBase64,
        perceptualHash: perceptualHash,
      );
      await _saveSide(
        cardSubmitterId: cardSubmitterId,
        side: 'back',
        imageBase64: backBase64,
        perceptualHash: null,
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.MongoImageRepository',
        'Failed to save submitter images',
        context: {'card_submitter_id': cardSubmitterId},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> _saveSide({
    required int cardSubmitterId,
    required String side,
    required String imageBase64,
    String? perceptualHash,
  }) async {
    final decoded = _decodeImage(imageBase64);
    if (decoded == null) {
      AppLogger.warning(
        'PokéGrading.Persistence.MongoImageRepository',
        'Invalid image data for $side side',
        context: {'card_submitter_id': cardSubmitterId},
      );
      throw ArgumentError('Invalid image data for $side side');
    }

    final existing = await _metadata.findOne(where
        .eq('card_submitter_id', cardSubmitterId)
        .eq('side', side));

    if (existing != null) {
      AppLogger.info(
        'PokéGrading.Persistence.MongoImageRepository',
        'Replacing existing image',
        context: {
          'card_submitter_id': cardSubmitterId,
          'side': side,
        },
      );
      final oldFileId = existing['file_id'];
      if (oldFileId is ObjectId) {
        final oldFile = await _gridFs.findOne(where.id(oldFileId));
        if (oldFile != null) {
          await oldFile.delete();
        }
      }
      await _metadata.deleteOne(where
          .eq('card_submitter_id', cardSubmitterId)
          .eq('side', side));
    }

    final filename =
        'submitter_${cardSubmitterId}_${side}_${DateTime.now().millisecondsSinceEpoch}';
    final gridIn = _gridFs.createFile(
      Stream.value(decoded.bytes),
      filename,
      {
        'card_submitter_id': cardSubmitterId,
        'side': side,
      },
    );
    gridIn.contentType = decoded.contentType;
    await gridIn.save();

    await _metadata.insert({
      'card_submitter_id': cardSubmitterId,
      'side': side,
      'file_id': gridIn.id,
      'content_type': decoded.contentType,
      'width': decoded.width,
      'height': decoded.height,
      'size_bytes': decoded.bytes.length,
      if (perceptualHash != null) 'perceptual_hash': perceptualHash,
      'uploaded_at': DateTime.now().toUtc(),
    });
  }

  @override
  Future<({String front, String back})?> loadSubmitterImages(
    int cardSubmitterId,
  ) async {
    try {
      final docs = await _metadata
          .find(where.eq('card_submitter_id', cardSubmitterId))
          .toList();

      if (docs.isEmpty) {
        AppLogger.info(
          'PokéGrading.Persistence.MongoImageRepository',
          'No images found for submitter',
          context: {'card_submitter_id': cardSubmitterId},
        );
        return null;
      }

      String? front;
      String? back;

      for (final doc in docs) {
        final side = doc['side']?.toString();
        final fileId = doc['file_id'];
        if (side == null || fileId is! ObjectId) continue;

        final gridOut = await _gridFs.findOne(where.id(fileId));
        if (gridOut == null) continue;

        final chunks = <int>[];
        await for (final chunk in _gridFs.chunks
            .find(where.eq('files_id', fileId).sortBy('n'))) {
          final data = chunk['data'] as BsonBinary;
          chunks.addAll(data.byteList);
        }

        final contentType = doc['content_type']?.toString() ??
            gridOut.contentType ??
            'image/jpeg';
        final mime = contentType.split(';').first;
        final base64Payload = base64Encode(Uint8List.fromList(chunks));
        final dataUrl = 'data:$mime;base64,$base64Payload';

        if (side == 'front') {
          front = dataUrl;
        } else if (side == 'back') {
          back = dataUrl;
        }
      }

      if (front == null || back == null) {
        AppLogger.warning(
          'PokéGrading.Persistence.MongoImageRepository',
          'Incomplete image set loaded',
          context: {
            'card_submitter_id': cardSubmitterId,
            'has_front': front != null,
            'has_back': back != null,
          },
        );
        return null;
      }
      return (front: front, back: back);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.MongoImageRepository',
        'Failed to load submitter images',
        context: {'card_submitter_id': cardSubmitterId},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<void> saveReferenceImages({
    required int cardReferenceId,
    required String frontBase64,
    required String backBase64,
    String? perceptualHash,
  }) async {
    AppLogger.info(
      'PokéGrading.Persistence.MongoImageRepository',
      'Saving reference images',
      context: {'card_reference_id': cardReferenceId},
    );

    try {
      await _saveReferenceSide(
        cardReferenceId: cardReferenceId,
        side: 'front',
        imageBase64: frontBase64,
        perceptualHash: perceptualHash,
      );
      await _saveReferenceSide(
        cardReferenceId: cardReferenceId,
        side: 'back',
        imageBase64: backBase64,
        perceptualHash: null,
      );
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.MongoImageRepository',
        'Failed to save reference images',
        context: {'card_reference_id': cardReferenceId},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> _saveReferenceSide({
    required int cardReferenceId,
    required String side,
    required String imageBase64,
    String? perceptualHash,
  }) async {
    final decoded = _decodeImage(imageBase64);
    if (decoded == null) {
      AppLogger.warning(
        'PokéGrading.Persistence.MongoImageRepository',
        'Invalid image data for $side side',
        context: {'card_reference_id': cardReferenceId},
      );
      throw ArgumentError('Invalid image data for $side side');
    }

    final existing = await _referenceMetadata.findOne(where
        .eq('card_reference_id', cardReferenceId)
        .eq('side', side));

    if (existing != null) {
      AppLogger.info(
        'PokéGrading.Persistence.MongoImageRepository',
        'Replacing existing reference image',
        context: {
          'card_reference_id': cardReferenceId,
          'side': side,
        },
      );
      final oldFileId = existing['file_id'];
      if (oldFileId is ObjectId) {
        final oldFile = await _referenceGridFs.findOne(where.id(oldFileId));
        if (oldFile != null) {
          await oldFile.delete();
        }
      }
      await _referenceMetadata.deleteOne(where
          .eq('card_reference_id', cardReferenceId)
          .eq('side', side));
    }

    final filename =
        'reference_${cardReferenceId}_${side}_${DateTime.now().millisecondsSinceEpoch}';
    final gridIn = _referenceGridFs.createFile(
      Stream.value(decoded.bytes),
      filename,
      {
        'card_reference_id': cardReferenceId,
        'side': side,
      },
    );
    gridIn.contentType = decoded.contentType;
    await gridIn.save();

    await _referenceMetadata.insert({
      'card_reference_id': cardReferenceId,
      'side': side,
      'file_id': gridIn.id,
      'content_type': decoded.contentType,
      'width': decoded.width,
      'height': decoded.height,
      'size_bytes': decoded.bytes.length,
      if (perceptualHash != null) 'perceptual_hash': perceptualHash,
      'uploaded_at': DateTime.now().toUtc(),
    });
  }

  @override
  Future<({String front, String back})?> loadReferenceImages(
    int cardReferenceId,
  ) async {
    try {
      final docs = await _referenceMetadata
          .find(where.eq('card_reference_id', cardReferenceId))
          .toList();

      if (docs.isEmpty) {
        AppLogger.info(
          'PokéGrading.Persistence.MongoImageRepository',
          'No images found for reference',
          context: {'card_reference_id': cardReferenceId},
        );
        return null;
      }

      String? front;
      String? back;

      for (final doc in docs) {
        final side = doc['side']?.toString();
        final fileId = doc['file_id'];
        if (side == null || fileId is! ObjectId) continue;

        final gridOut = await _referenceGridFs.findOne(where.id(fileId));
        if (gridOut == null) continue;

        final chunks = <int>[];
        await for (final chunk in _referenceGridFs.chunks
            .find(where.eq('files_id', fileId).sortBy('n'))) {
          final data = chunk['data'] as BsonBinary;
          chunks.addAll(data.byteList);
        }

        final contentType = doc['content_type']?.toString() ??
            gridOut.contentType ??
            'image/jpeg';
        final mime = contentType.split(';').first;
        final base64Payload = base64Encode(Uint8List.fromList(chunks));
        final dataUrl = 'data:$mime;base64,$base64Payload';

        if (side == 'front') {
          front = dataUrl;
        } else if (side == 'back') {
          back = dataUrl;
        }
      }

      if (front == null || back == null) {
        AppLogger.warning(
          'PokéGrading.Persistence.MongoImageRepository',
          'Incomplete reference image set loaded',
          context: {
            'card_reference_id': cardReferenceId,
            'has_front': front != null,
            'has_back': back != null,
          },
        );
        return null;
      }
      return (front: front, back: back);
    } catch (error, stack) {
      AppLogger.error(
        'PokéGrading.Persistence.MongoImageRepository',
        'Failed to load reference images',
        context: {'card_reference_id': cardReferenceId},
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  _DecodedImage? _decodeImage(String imageData) {
    try {
      final trimmed = imageData.trim();
      final base64Part =
          trimmed.contains(',') ? trimmed.split(',').last : trimmed;
      final bytes = base64Decode(base64Part);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      String contentType = 'image/jpeg';
      if (trimmed.startsWith('data:image/png')) {
        contentType = 'image/png';
      } else if (trimmed.startsWith('data:image/jpeg') ||
          trimmed.startsWith('data:image/jpg')) {
        contentType = 'image/jpeg';
      }

      return _DecodedImage(
        bytes: bytes,
        contentType: contentType,
        width: decoded.width,
        height: decoded.height,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _db.close();
  }
}

class _DecodedImage {
  final List<int> bytes;
  final String contentType;
  final int width;
  final int height;

  const _DecodedImage({
    required this.bytes,
    required this.contentType,
    required this.width,
    required this.height,
  });
}
