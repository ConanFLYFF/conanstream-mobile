import 'dart:convert';
import 'package:http/http.dart' as http;

class SheetService {
  // 🔗 URL mise à jour avec le nouveau déploiement
  static const String _url = 'https://script.google.com/macros/s/AKfycbwPbzSRc60Wj0VAYOrZC4LSZZyx6TnRwHEMo0-alVJ_LKc5yXyAlSNDEQPItJCy0HH4A/exec';

  static Future<List<dynamic>> fetchSheetData() async {
    try {
      final response = await http.get(Uri.parse(_url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']; // Retourne la liste des lignes de ton Google Sheet
        }
      }
      return [];
    } catch (e) {
      print('Erreur lors de la lecture du Google Sheet : $e');
      return [];
    }
  }
}