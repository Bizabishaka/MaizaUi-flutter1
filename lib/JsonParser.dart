import 'dart:convert';

class JsonParser {
  static String parseCropName(String jsonResult) {
    Map<String, dynamic> decodedJson = json.decode(jsonResult);
    String cropName = decodedJson['alt'];
    return cropName.isNotEmpty ? 'Detected crop: $cropName' : 'Crop detection failed';
  }
}
