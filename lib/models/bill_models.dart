class BillItem {
  final String id;
  final String description;
  final int quantity;
  final double? unitPrice;
  final double totalPrice;
  final int? assignedQuantity; // Quantity assigned to a specific person for this item

  BillItem({
    required this.id,
    required this.description,
    required this.quantity,
    this.unitPrice,
    required this.totalPrice,
    this.assignedQuantity,
  });

  BillItem copyWith({
    String? id,
    String? description,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    int? assignedQuantity,
  }) {
    return BillItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      assignedQuantity: assignedQuantity ?? this.assignedQuantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'assignedQuantity': assignedQuantity,
    };
  }

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] as String,
      description: json['description'] as String,
      quantity: json['quantity'] as int,
      unitPrice: json['unitPrice'] as double?,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      assignedQuantity: json['assignedQuantity'] as int?,
    );
  }
}

class Charge {
  final String description;
  final double amount;

  Charge({
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
    };
  }

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class ParsedBill {
  final List<BillItem> items;
  final double? subtotal;
  final List<Charge> discounts;
  final List<Charge> taxes;
  final List<Charge> serviceCharges;
  final List<Charge> otherCharges;
  final double? grandTotal;
  final String currency;

  ParsedBill({
    required this.items,
    this.subtotal,
    required this.discounts,
    required this.taxes,
    required this.serviceCharges,
    required this.otherCharges,
    this.grandTotal,
    required this.currency,
  });

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discounts': discounts.map((discount) => discount.toJson()).toList(),
      'taxes': taxes.map((tax) => tax.toJson()).toList(),
      'serviceCharges': serviceCharges.map((charge) => charge.toJson()).toList(),
      'otherCharges': otherCharges.map((charge) => charge.toJson()).toList(),
      'grandTotal': grandTotal,
      'currency': currency,
    };
  }

  factory ParsedBill.fromJson(Map<String, dynamic> json) {
    return ParsedBill(
      items: (json['items'] as List)
          .map((item) => BillItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: json['subtotal'] as double?,
      discounts: (json['discounts'] as List)
          .map((discount) => Charge.fromJson(discount as Map<String, dynamic>))
          .toList(),
      taxes: (json['taxes'] as List)
          .map((tax) => Charge.fromJson(tax as Map<String, dynamic>))
          .toList(),
      serviceCharges: (json['serviceCharges'] as List)
          .map((charge) => Charge.fromJson(charge as Map<String, dynamic>))
          .toList(),
      otherCharges: (json['otherCharges'] as List)
          .map((charge) => Charge.fromJson(charge as Map<String, dynamic>))
          .toList(),
      grandTotal: json['grandTotal'] as double?,
      currency: json['currency'] as String,
    );
  }
}

class Person {
  final String id;
  final String name;
  final String color;

  Person({
    required this.id,
    required this.name,
    required this.color,
  });

  Person copyWith({
    String? id,
    String? name,
    String? color,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
    );
  }
}

// Defines an assignment for a single-quantity item, split among person IDs.
typedef SimpleAssignment = List<String>;

// Defines an assignment for a multi-quantity item, mapping person IDs to their assigned quantity.
typedef QuantityAssignment = Map<String, int>;

// The state for all item assignments, where each item can have one of the two assignment types.
typedef ItemAssignments = Map<String, dynamic>;

// Defines the assignment mode for a multi-quantity item.
enum AssignmentMode { quantity, split }

// The state for tracking the assignment mode of each multi-quantity item.
typedef ItemAssignmentModes = Map<String, AssignmentMode>;

class SplitCalculation {
  final String personId;
  final String personName;
  final double itemsValue; // Sum of their items + share of shared items
  final double sharedCostsAndDiscounts; // Their proportional share of (taxes + service + other - discounts)
  final double totalOwed;
  final SplitBreakdown breakdown;

  SplitCalculation({
    required this.personId,
    required this.personName,
    required this.itemsValue,
    required this.sharedCostsAndDiscounts,
    required this.totalOwed,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() {
    return {
      'personId': personId,
      'personName': personName,
      'itemsValue': itemsValue,
      'sharedCostsAndDiscounts': sharedCostsAndDiscounts,
      'totalOwed': totalOwed,
      'breakdown': breakdown.toJson(),
    };
  }

  factory SplitCalculation.fromJson(Map<String, dynamic> json) {
    return SplitCalculation(
      personId: json['personId'] as String,
      personName: json['personName'] as String,
      itemsValue: (json['itemsValue'] as num).toDouble(),
      sharedCostsAndDiscounts: (json['sharedCostsAndDiscounts'] as num).toDouble(),
      totalOwed: (json['totalOwed'] as num).toDouble(),
      breakdown: SplitBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>),
    );
  }
}

class SplitBreakdown {
  final List<BillItem> items; // These items will reflect the person's share of the price if split
  final List<SharedItemContribution> sharedItemContributions;
  final double taxShare;
  final double serviceChargeShare;
  final double otherChargesShare;
  final double discountShare;
  final double proportion; // The person's share of the total assigned value (0 to 1)

  SplitBreakdown({
    required this.items,
    required this.sharedItemContributions,
    required this.taxShare,
    required this.serviceChargeShare,
    required this.otherChargesShare,
    required this.discountShare,
    required this.proportion,
  });

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'sharedItemContributions': sharedItemContributions.map((contribution) => contribution.toJson()).toList(),
      'taxShare': taxShare,
      'serviceChargeShare': serviceChargeShare,
      'otherChargesShare': otherChargesShare,
      'discountShare': discountShare,
      'proportion': proportion,
    };
  }

  factory SplitBreakdown.fromJson(Map<String, dynamic> json) {
    return SplitBreakdown(
      items: (json['items'] as List)
          .map((item) => BillItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      sharedItemContributions: (json['sharedItemContributions'] as List)
          .map((contribution) => SharedItemContribution.fromJson(contribution as Map<String, dynamic>))
          .toList(),
      taxShare: (json['taxShare'] as num).toDouble(),
      serviceChargeShare: (json['serviceChargeShare'] as num).toDouble(),
      otherChargesShare: (json['otherChargesShare'] as num).toDouble(),
      discountShare: (json['discountShare'] as num).toDouble(),
      proportion: (json['proportion'] as num).toDouble(),
    );
  }
}

class SharedItemContribution {
  final String description;
  final double amount;

  SharedItemContribution({
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
    };
  }

  factory SharedItemContribution.fromJson(Map<String, dynamic> json) {
    return SharedItemContribution(
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

// For Gemini response structure
class GeminiBillItem {
  final String description;
  final int quantity;
  final double? unitPrice;
  final double totalPrice;

  GeminiBillItem({
    required this.description,
    required this.quantity,
    this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory GeminiBillItem.fromJson(Map<String, dynamic> json) {
    return GeminiBillItem(
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GeminiCharge {
  final String description;
  final double amount;

  GeminiCharge({
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
    };
  }

  factory GeminiCharge.fromJson(Map<String, dynamic> json) {
    return GeminiCharge(
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GeminiParsedBill {
  final List<GeminiBillItem> items;
  final double? subtotal;
  final List<GeminiCharge> discounts;
  final List<GeminiCharge> taxes;
  final List<GeminiCharge> serviceCharges;
  final List<GeminiCharge> otherCharges;
  final double? grandTotal;
  final String currency;

  GeminiParsedBill({
    required this.items,
    this.subtotal,
    required this.discounts,
    required this.taxes,
    required this.serviceCharges,
    required this.otherCharges,
    this.grandTotal,
    required this.currency,
  });

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discounts': discounts.map((discount) => discount.toJson()).toList(),
      'taxes': taxes.map((tax) => tax.toJson()).toList(),
      'serviceCharges': serviceCharges.map((charge) => charge.toJson()).toList(),
      'otherCharges': otherCharges.map((charge) => charge.toJson()).toList(),
      'grandTotal': grandTotal,
      'currency': currency,
    };
  }

  factory GeminiParsedBill.fromJson(Map<String, dynamic> json) {
    return GeminiParsedBill(
      items: (json['items'] as List? ?? [])
          .map((item) => GeminiBillItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      discounts: (json['discounts'] as List? ?? [])
          .map((discount) => GeminiCharge.fromJson(discount as Map<String, dynamic>))
          .toList(),
      taxes: (json['taxes'] as List? ?? [])
          .map((tax) => GeminiCharge.fromJson(tax as Map<String, dynamic>))
          .toList(),
      serviceCharges: (json['serviceCharges'] as List? ?? [])
          .map((charge) => GeminiCharge.fromJson(charge as Map<String, dynamic>))
          .toList(),
      otherCharges: (json['otherCharges'] as List? ?? [])
          .map((charge) => GeminiCharge.fromJson(charge as Map<String, dynamic>))
          .toList(),
      grandTotal: (json['grandTotal'] as num?)?.toDouble(),
      currency: json['currency']?.toString() ?? 'USD',
    );
  }
}
