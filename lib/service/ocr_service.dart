import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for extracting text from images using Google ML Kit
class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extract text from an image file
  /// Returns the recognized text as a single string
  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Combine all text blocks into a single string
      final StringBuffer buffer = StringBuffer();

      for (var block in recognizedText.blocks) {
        buffer.writeln(block.text);
      }

      final extractedText = buffer.toString().trim();
      print('✅ Extracted ${extractedText.length} characters from image');

      return extractedText;
    } catch (e) {
      print('❌ Error extracting text from image: $e');
      rethrow;
    }
  }

  /// Extract text with more detailed structure
  /// Returns blocks, lines, and elements separately
  Future<Map<String, dynamic>> extractStructuredText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final List<Map<String, dynamic>> blocks = [];

      for (var block in recognizedText.blocks) {
        final List<String> lines = [];

        for (var line in block.lines) {
          lines.add(line.text);
        }

        blocks.add({
          'text': block.text,
          'lines': lines,
          'boundingBox': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'width': block.boundingBox.width,
            'height': block.boundingBox.height,
          },
        });
      }

      print('✅ Extracted ${blocks.length} text blocks from image');

      return {
        'fullText': recognizedText.text,
        'blocks': blocks,
        'blockCount': blocks.length,
      };
    } catch (e) {
      print('❌ Error extracting structured text: $e');
      rethrow;
    }
  }

  /// Check if image contains readable text
  /// Returns true if text was found, false otherwise
  Future<bool> hasReadableText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      return recognizedText.text.trim().isNotEmpty;
    } catch (e) {
      print('❌ Error checking for readable text: $e');
      return false;
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

/// Global singleton instance
final ocrService = OcrService();
