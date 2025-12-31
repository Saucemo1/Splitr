import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/bill_models.dart';
import '../models/constants.dart';
import '../config/api_config.dart';

class GeminiService {
  static String get _apiKey => ApiConfig.apiKey;
  
  static GenerativeModel? _model;
  
  static GenerativeModel get model {
    if (_model == null) {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
        throw Exception('Gemini API Key is not configured. Please update lib/config/api_config.dart with your API key or set GEMINI_API_KEY environment variable.');
      }
      _model = GenerativeModel(
        model: geminiModelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.2,
        ),
      );
    }
    return _model!;
  }

  static void cleanup() {
    _model = null;
    print('GeminiService: Model instance cleared');
  }

  static Future<ParsedBill> extractBillDetails(String imageBase64) async {
    try {
      // Validate input
      if (imageBase64.isEmpty) {
        throw Exception('No image data provided');
      }
      // print('🔍 Starting Gemini API call...');
      // print('🔑 API Key configured: ${_apiKey.isNotEmpty ? "Yes (${_apiKey.substring(0, 10)}...)" : "No"}');
      
      final imagePart = DataPart('image/jpeg', base64Decode(imageBase64));
      final textPart = TextPart(geminiOcrPrompt);

      // print('📤 Sending request to Gemini API...');
      final response = await model.generateContent([
        Content.multi([imagePart, textPart]),
      ]);

      // print('📥 Received response from Gemini API');
      final responseText = response.text;
      if (responseText == null) {
        // print('❌ No response text received from Gemini API');
        throw Exception('No response received from Gemini API');
      }

      // print('📄 Response text length: ${responseText.length}');
      // print('📄 Response preview: ${responseText.substring(0, responseText.length > 200 ? 200 : responseText.length)}...');

      String jsonString = responseText.trim();
      // print('📄 Full response: $jsonString');
      
      // Try to extract JSON from the response if it's wrapped in markdown or other text
      if (jsonString.contains('```json')) {
        final startIndex = jsonString.indexOf('```json') + 7;
        final endIndex = jsonString.indexOf('```', startIndex);
        if (endIndex != -1) {
          jsonString = jsonString.substring(startIndex, endIndex).trim();
          // print('📄 Extracted JSON from markdown: $jsonString');
        }
      } else if (jsonString.contains('```')) {
        final startIndex = jsonString.indexOf('```') + 3;
        final endIndex = jsonString.indexOf('```', startIndex);
        if (endIndex != -1) {
          jsonString = jsonString.substring(startIndex, endIndex).trim();
          // print('📄 Extracted JSON from code block: $jsonString');
        }
      }
      
      Map<String, dynamic> parsedJson;
      try {
        parsedJson = jsonDecode(jsonString) as Map<String, dynamic>;
        // print('✅ JSON parsed successfully');
      } catch (e) {
        // print('❌ JSON parsing failed: $e');
        // print('📄 Attempted to parse: $jsonString');
        throw Exception('Invalid JSON response from bill scanner: $e');
      }
      
      // print('📋 Parsed JSON keys: ${parsedJson.keys.toList()}');
      
      GeminiParsedBill geminiBill;
      try {
        geminiBill = GeminiParsedBill.fromJson(parsedJson);
        // print('✅ GeminiParsedBill created successfully');
        // print('📊 Items found: ${geminiBill.items.length}');
        // print('💰 Currency: ${geminiBill.currency}');
      } catch (e) {
        // print('❌ GeminiParsedBill parsing failed: $e');
        // print('📋 Available keys in response: ${parsedJson.keys.toList()}');
        // print('📋 Response structure: $parsedJson');
        throw Exception('Failed to parse bill data: $e');
      }

      // Validate and transform to ParsedBill, ensuring all numbers are actual numbers
      // and adding client-side IDs to items.
      final items = geminiBill.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return BillItem(
          id: 'item-${DateTime.now().millisecondsSinceEpoch}-$index',
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
        );
      }).toList();

      final discounts = geminiBill.discounts.map((d) => Charge(
        description: d.description,
        amount: d.amount,
      )).toList();

      final taxes = geminiBill.taxes.map((t) => Charge(
        description: t.description,
        amount: t.amount,
      )).toList();

      final serviceCharges = geminiBill.serviceCharges.map((sc) => Charge(
        description: sc.description,
        amount: sc.amount,
      )).toList();

      final otherCharges = geminiBill.otherCharges.map((oc) => Charge(
        description: oc.description,
        amount: oc.amount,
      )).toList();

      // Calculate subtotal if null
      double? subtotal = geminiBill.subtotal ?? items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);

      // Calculate grandTotal if null
      double? grandTotal = geminiBill.grandTotal;
      if (grandTotal == null) {
        final totalDiscounts = discounts.fold<double>(0.0, (sum, d) => sum + d.amount);
        final totalTaxes = taxes.fold<double>(0.0, (sum, t) => sum + t.amount);
        final totalServiceCharges = serviceCharges.fold<double>(0.0, (sum, sc) => sum + sc.amount);
        final totalOtherCharges = otherCharges.fold<double>(0.0, (sum, oc) => sum + oc.amount);
        grandTotal = subtotal - totalDiscounts + totalTaxes + totalServiceCharges + totalOtherCharges;
      }

      return ParsedBill(
        items: items,
        subtotal: subtotal,
        discounts: discounts,
        taxes: taxes,
        serviceCharges: serviceCharges,
        otherCharges: otherCharges,
        grandTotal: grandTotal,
        currency: geminiBill.currency.isNotEmpty ? geminiBill.currency : 'USD',
      );
    } catch (error) {
      // print('❌ Error calling Gemini API: $error');
      // print('❌ Error type: ${error.runtimeType}');
      
      String userFriendlyMessage = 'An unexpected error occurred while processing the bill. Please try again.';

      if (error.toString().contains('overloaded') || error.toString().contains('UNAVAILABLE')) {
        userFriendlyMessage = 'The bill scanning service is currently busy. Please wait a moment and try again.';
      } else if (error.toString().contains('API key not valid') || error.toString().contains('API_KEY_INVALID')) {
        userFriendlyMessage = 'The bill scanning service is not configured correctly (Invalid API Key).';
      } else if (error.toString().contains('Billing account not found')) {
        userFriendlyMessage = 'The bill scanning service is not configured correctly (Billing issue).';
      } else if (error.toString().contains('permission_denied') || error.toString().contains('PERMISSION_DENIED')) {
        userFriendlyMessage = 'Access to the bill scanning service was denied. Please check configuration.';
      } else if (error.toString().contains('Failed to fetch')) {
        userFriendlyMessage = 'Network error. Please check your internet connection and try again.';
      } else if (error is FormatException) {
        userFriendlyMessage = 'The bill scanner returned an invalid format. This may be a temporary issue, please try again.';
      }

      throw Exception(userFriendlyMessage);
    }
  }
}
