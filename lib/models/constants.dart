import 'package:flutter/material.dart';

const String geminiModelName = "gemini-2.5-flash";

const String geminiOcrPrompt = """You are an expert bill parsing assistant. Analyze the provided bill image.
Your goal is to extract all relevant financial information and structure it as a VALID JSON object that conforms to the provided schema.
Pay EXTREME attention to the data types and structure defined in the schema.

The JSON object should follow this schema:
{
  "items": [
    {
      "description": "Spaghetti Carbonara",
      "quantity": 1,
      "unitPrice": 15.00,
      "totalPrice": 15.00
    },
    {
      "description": "Coke Zero",
      "quantity": 2,
      "unitPrice": null,
      "totalPrice": 5.00
    }
  ],
  "subtotal": 20.00,
  "discounts": [
    {
      "description": "Happy Hour Discount",
      "amount": 2.00
    }
  ],
  "taxes": [
    {
      "description": "VAT (10%)",
      "amount": 1.80
    }
  ],
  "serviceCharges": [],
  "otherCharges": [],
  "grandTotal": 20.00,
  "currency": "USD"
}

Important considerations for filling the JSON:
- Item "description": Full item name or description (MUST be a string).
- Item "quantity": Number of units (MUST be a number, default to 1 if not specified).
- Item "unitPrice": Price per unit (MUST be a number, or the literal 'null' if not available/applicable).
- Item "totalPrice": Total price for this line item (MUST be a number).
- "subtotal": Calculated sum of all item totalPrices if not explicitly stated on the bill. If stated, use that value (MUST be a number, or null).
- "discounts": Array of discount objects. "description" (string), "amount" (positive number).
- "taxes": Array of tax objects. "description" (string), "amount" (number).
- "serviceCharges": Array of service charge objects. "description" (string), "amount" (number).
- "otherCharges": Array of other charge objects. "description" (string), "amount" (number).
- "grandTotal": The final amount due on the bill (MUST be a number, or null).
- "currency": The ISO 4217 currency code (e.g., "USD", "EUR", "GBP") from the bill. If you can only identify a symbol (e.g., \$, €), infer the most likely code. If no currency is identifiable, default to "USD". (MUST be a string).

General rules:
- Ensure all monetary values are numbers (e.g., 12.50, not "\$12.50" or "12,50").
- If quantity is not explicitly mentioned for an item, assume 1.
- If any section (e.g., discounts, taxes, serviceCharges, otherCharges) is empty, provide an empty array [], NOT null. The "items" array should also be an empty array if no items are found.
- If a value is clearly zero, represent it as 0.
- For optional numeric fields (subtotal, unitPrice, grandTotal), use null if not present or not determinable.
""";

// Color Palette for People Chips
const Map<String, Map<String, Color>> personColors = {
  'Denim': {
    'selected': Color(0xFF395789),
    'unselected': Color(0xFF2E3A52),
  },
  'Teal-Slate': {
    'selected': Color(0xFF2F7D83),
    'unselected': Color(0xFF253A45),
  },
  'Cobalt-Slate': {
    'selected': Color(0xFF36637A),
    'unselected': Color(0xFF263D4A),
  },
  'Pine': {
    'selected': Color(0xFF2E5F45),
    'unselected': Color(0xFF23383A),
  },
  'Dusty-Indigo': {
    'selected': Color(0xFF5D6389),
    'unselected': Color(0xFF2F3246),
  },
  'Sea-Sage': {
    'selected': Color(0xFF3E6E5A),
    'unselected': Color(0xFF2C3F38),
  },
  'Muted-Sea': {
    'selected': Color(0xFF4B6E6A),
    'unselected': Color(0xFF2A3C4A),
  },
  'Denim-Grey': {
    'selected': Color(0xFF556B8E),
    'unselected': Color(0xFF303A4A),
  },
};

final List<String> colorNames = personColors.keys.toList();
