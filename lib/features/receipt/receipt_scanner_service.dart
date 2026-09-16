import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'receipt_parser.dart';

/// Service responsible for capturing receipt images and processing them via
/// on-device Google ML Kit Text Recognition.
class ReceiptScannerService {
  ReceiptScannerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Prompts the user to pick an image from [source] (camera or gallery),
  /// extracts the raw text with ML Kit OCR, and parses the fields.
  ///
  /// Returns null if the user cancelled the picker or if no text was found.
  Future<ReceiptData?> scanReceipt({required ImageSource source}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (file == null) {
        return null; // User cancelled
      }

      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        return ReceiptParser.parse(recognizedText.text);
      } finally {
        await textRecognizer.close();
      }
    } catch (e, stack) {
      debugPrint('ReceiptScannerService error: $e\n$stack');
      rethrow;
    }
  }
}
