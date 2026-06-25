import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;

import '../lib/domain/image_services/preprocessing/card_contour_detector.dart';
import '../lib/domain/image_services/preprocessing/perspective_transform.dart';
import '../lib/domain/image_services/preprocessing/color_normalizer.dart';
import '../lib/domain/image_services/preprocessing/roi_segmenter.dart';

void main() {
  final base64Str = File('${Directory.current.parent.path}${Platform.pathSeparator}preprocess_output${Platform.pathSeparator}Imagen.txt').readAsBytesSync();
  final src = img.decodeImage(Uint8List.fromList(base64Decode(String.fromCharCodes(base64Str))))!;
  print('Source: ${src.width}x${src.height}');

  final contourResult = CardContourDetector.detect(src);
  final corrResult = PerspectiveTransformer.correct(src, contourResult.corners!);
  final cardImage = img.decodeImage(Uint8List.fromList(base64Decode(corrResult.correctedImageData!)))!;
  final normalized = ColorNormalizer.normalize(cardImage);

  File('${Directory.current.parent.path}${Platform.pathSeparator}preprocess_output${Platform.pathSeparator}preprocessed.jpg')
    .writeAsBytesSync(img.encodeJpg(normalized, quality: 95));

  final rois = RoiSegmenter.extract(normalized);
  final outDir = '${Directory.current.parent.path}${Platform.pathSeparator}preprocess_output';

  File('$outDir${Platform.pathSeparator}roi_centering.jpg').writeAsBytesSync(img.encodeJpg(rois.centering, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_corner_tl.jpg').writeAsBytesSync(img.encodeJpg(rois.cornerTopLeft, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_corner_tr.jpg').writeAsBytesSync(img.encodeJpg(rois.cornerTopRight, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_corner_bl.jpg').writeAsBytesSync(img.encodeJpg(rois.cornerBottomLeft, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_corner_br.jpg').writeAsBytesSync(img.encodeJpg(rois.cornerBottomRight, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_edge_top.jpg').writeAsBytesSync(img.encodeJpg(rois.edgeTop, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_edge_bottom.jpg').writeAsBytesSync(img.encodeJpg(rois.edgeBottom, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_edge_left.jpg').writeAsBytesSync(img.encodeJpg(rois.edgeLeft, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_edge_right.jpg').writeAsBytesSync(img.encodeJpg(rois.edgeRight, quality: 95));
  File('$outDir${Platform.pathSeparator}roi_surface.jpg').writeAsBytesSync(img.encodeJpg(rois.surface, quality: 95));

  print('\n--- ROI dimensions ---');
  print('Centering:  ${rois.centering.width}x${rois.centering.height}');
  print('Corner TL:  ${rois.cornerTopLeft.width}x${rois.cornerTopLeft.height}');
  print('Corner TR:  ${rois.cornerTopRight.width}x${rois.cornerTopRight.height}');
  print('Corner BL:  ${rois.cornerBottomLeft.width}x${rois.cornerBottomLeft.height}');
  print('Corner BR:  ${rois.cornerBottomRight.width}x${rois.cornerBottomRight.height}');
  print('Edge Top:   ${rois.edgeTop.width}x${rois.edgeTop.height}');
  print('Edge Bot:   ${rois.edgeBottom.width}x${rois.edgeBottom.height}');
  print('Edge Left:  ${rois.edgeLeft.width}x${rois.edgeLeft.height}');
  print('Edge Right: ${rois.edgeRight.width}x${rois.edgeRight.height}');
  print('Surface:    ${rois.surface.width}x${rois.surface.height}');
}
