import 'package:cloud_firestore/cloud_firestore.dart';

class ApiKeys {
  static Future<String> getGeminiKey() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('gemini')
        .get();

    return doc['apiKey'];
  }

  static Future<String> getGroqKey() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('grok')
        .get();

    return doc['apiKey'];
  }
}