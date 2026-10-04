import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AIService {
  static const String _apiKey =
      'BURAYA_API_KEY_GELECEK';

  static Future<List<String>?> extractShiftFromImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    final imageBytes = await File(image.path).readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = image.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Sen uzman bir insan kaynakları asistanısın. Bu fotoğraf bir vardiya çizelgesidir.\n"
                    "1. Tablodaki en belirgin veya işaretlenmiş kişinin çalışma döngüsünü tespit et.\n"
                    "2. Yazılı olan çalışma saatlerini analiz et.\n"
                    "3. Eğer gün Gündüz vardiyası ise ve saat varsa: 'Gündüz|08:00-16:00' formatında yaz. Saat yoksa sadece 'Gündüz' yaz.\n"
                    "4. Eğer gün Akşam veya Gece ise ve saat varsa: 'Gece|16:00-00:00' veya 'Gece|00:00-08:00' formatında yaz. Saat yoksa sadece 'Gece' yaz.\n"
                    "5. Eğer gün tatil, off veya izin ise sadece 'Tatil' yaz.\n"
                    "Bana SADECE elde ettiğin bu döngüyü aralarında virgül olacak şekilde liste halinde ver. Başka hiçbir açıklama ekleme.\n"
                    "Örnek Çıktı: Gündüz|08:00-16:00, Gündüz|08:00-16:00, Gece|16:00-00:00, Gece|16:00-00:00, Tatil, Tatil",
              },
              {
                "inline_data": {"mime_type": mimeType, "data": base64Image},
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String aiYaniti = data['candidates'][0]['content']['parts'][0]['text']
          .toString()
          .trim();

      if (aiYaniti.contains("HATA") || aiYaniti.isEmpty) {
        return [];
      }

      // Yapay zekanın bulduğu döngüyü listeye çeviriyoruz
      List<String> cikarilanDongu = aiYaniti
          .split(',')
          .map((e) => e.trim().replaceAll("'", "").replaceAll('"', ''))
          .toList();
      return cikarilanDongu;
    } else {
      throw Exception(
        'Google API Hatası: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
