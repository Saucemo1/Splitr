import 'package:intl/intl.dart';
import '../models/bill_models.dart';

class BillProcessor {
  static List<SplitCalculation> calculateSplits(
    ParsedBill? bill,
    List<Person> people,
    ItemAssignments assignments,
  ) {
    if (bill == null || people.isEmpty) {
      return [];
    }

    final results = people.map((person) => SplitCalculation(
      personId: person.id,
      personName: person.name,
      itemsValue: 0.0,
      sharedCostsAndDiscounts: 0.0,
      totalOwed: 0.0,
      breakdown: SplitBreakdown(
        items: [],
        sharedItemContributions: [],
        taxShare: 0.0,
        serviceChargeShare: 0.0,
        otherChargesShare: 0.0,
        discountShare: 0.0,
        proportion: 0.0,
      ),
    )).toList();

    // 1. Assign item costs based on assignment type (simple or quantity-based)
    for (final item in bill.items) {
      final owner = assignments[item.id];

      if (owner is List && owner.isNotEmpty) {
        // Simple assignment (for single quantity items or cost-split)
        final simpleAssignment = owner.cast<String>();
        final numAssignees = simpleAssignment.length;
        final pricePerAssignee = item.totalPrice / numAssignees;
        
        // Create shared item contribution if multiple people are sharing
        final sharedContribution = numAssignees > 1 
            ? SharedItemContribution(
                description: item.description,
                amount: pricePerAssignee,
              )
            : null;
        
        for (final personId in simpleAssignment) {
          final personResult = results.firstWhere(
            (p) => p.personId == personId,
            orElse: () => throw Exception('Person not found: $personId'),
          );
          
          // Add shared contribution to the person's breakdown
          final updatedSharedContributions = sharedContribution != null
              ? [...personResult.breakdown.sharedItemContributions, sharedContribution]
              : personResult.breakdown.sharedItemContributions;
          
          final newPersonResult = SplitCalculation(
            personId: personResult.personId,
            personName: personResult.personName,
            itemsValue: personResult.itemsValue + pricePerAssignee,
            sharedCostsAndDiscounts: personResult.sharedCostsAndDiscounts,
            totalOwed: personResult.totalOwed,
            breakdown: SplitBreakdown(
              items: [
                ...personResult.breakdown.items,
                BillItem(
                  id: item.id,
                  description: '${item.description}', 
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  totalPrice: pricePerAssignee,
                ),
              ],
              sharedItemContributions: updatedSharedContributions,
              taxShare: personResult.breakdown.taxShare,
              serviceChargeShare: personResult.breakdown.serviceChargeShare,
              otherChargesShare: personResult.breakdown.otherChargesShare,
              discountShare: personResult.breakdown.discountShare,
              proportion: personResult.breakdown.proportion,
            ),
          );
          final index = results.indexWhere((p) => p.personId == personId);
          results[index] = newPersonResult;
        }
      } else if (owner is Map && owner.isNotEmpty) {
        // Quantity assignment
        final quantityAssignment = owner.cast<String, int>();
        final unitPrice = item.quantity > 0 ? item.totalPrice / item.quantity : 0.0;

        for (final entry in quantityAssignment.entries) {
          final personId = entry.key;
          final quantity = entry.value;
          
          if (quantity > 0) {
            final personResult = results.firstWhere(
              (p) => p.personId == personId,
              orElse: () => throw Exception('Person not found: $personId'),
            );
            final valueForPerson = unitPrice * quantity;
            final newPersonResult = SplitCalculation(
              personId: personResult.personId,
              personName: personResult.personName,
              itemsValue: personResult.itemsValue + valueForPerson,
              sharedCostsAndDiscounts: personResult.sharedCostsAndDiscounts,
              totalOwed: personResult.totalOwed,
              breakdown: SplitBreakdown(
                items: [
                  ...personResult.breakdown.items,
                  BillItem(
                    id: item.id,
                    description: item.description,
                    quantity: item.quantity,
                    unitPrice: unitPrice,
                    totalPrice: valueForPerson,
                    assignedQuantity: quantity,
                  ),
                ],
                sharedItemContributions: personResult.breakdown.sharedItemContributions,
                taxShare: personResult.breakdown.taxShare,
                serviceChargeShare: personResult.breakdown.serviceChargeShare,
                otherChargesShare: personResult.breakdown.otherChargesShare,
                discountShare: personResult.breakdown.discountShare,
                proportion: personResult.breakdown.proportion,
              ),
            );
            final index = results.indexWhere((p) => p.personId == personId);
            results[index] = newPersonResult;
          }
        }
      }
    }
    
    // 2. Calculate total base value (sum of all assigned item values)
    final totalBaseValueForAll = results.fold<double>(0.0, (sum, p) => sum + p.itemsValue);

    // 3. Distribute overall discounts, taxes, service charges, other charges proportionally
    final totalDiscounts = bill.discounts.fold<double>(0.0, (sum, d) => sum + d.amount);
    final totalTaxes = bill.taxes.fold<double>(0.0, (sum, t) => sum + t.amount);
    final totalServiceCharges = bill.serviceCharges.fold<double>(0.0, (sum, sc) => sum + sc.amount);
    final totalOtherCharges = bill.otherCharges.fold<double>(0.0, (sum, oc) => sum + oc.amount);

    for (int i = 0; i < results.length; i++) {
      final personResult = results[i];
      final proportion = totalBaseValueForAll > 0 
          ? (personResult.itemsValue / totalBaseValueForAll) 
          : (1 / people.length); // Equal distribution if no items were assigned to anyone
      
      final taxShare = totalTaxes * proportion;
      final serviceChargeShare = totalServiceCharges * proportion;
      final otherChargesShare = totalOtherCharges * proportion;
      final discountShare = totalDiscounts * proportion;

      final sharedCostsAndDiscounts = 
          (taxShare + serviceChargeShare + otherChargesShare) - discountShare;
      
      final totalOwed = personResult.itemsValue + sharedCostsAndDiscounts;

      results[i] = SplitCalculation(
        personId: personResult.personId,
        personName: personResult.personName,
        itemsValue: personResult.itemsValue,
        sharedCostsAndDiscounts: sharedCostsAndDiscounts,
        totalOwed: totalOwed,
        breakdown: SplitBreakdown(
          items: personResult.breakdown.items,
          sharedItemContributions: personResult.breakdown.sharedItemContributions,
          taxShare: taxShare,
          serviceChargeShare: serviceChargeShare,
          otherChargesShare: otherChargesShare,
          discountShare: discountShare,
          proportion: proportion,
        ),
      );
    }

    // 4. Adjust individual totals so their sum matches the bill's grandTotal
    final currentCalculatedGrandTotal = results.fold<double>(0.0, (sum, r) => sum + r.totalOwed);

    if (bill.grandTotal != null && bill.grandTotal != null) {
      final differenceToAdjust = bill.grandTotal! - currentCalculatedGrandTotal;

      if (differenceToAdjust.abs() > 1e-9 && results.isNotEmpty) { 
        if (currentCalculatedGrandTotal != 0) {
          final initialOwedAmounts = results.map((r) => r.totalOwed).toList();
          for (int i = 0; i < results.length; i++) {
            final personResult = results[i];
            final proportionOfTotal = initialOwedAmounts[i] == 0 && currentCalculatedGrandTotal == 0 
                ? (1 / results.length) 
                : (initialOwedAmounts[i] / currentCalculatedGrandTotal);
            final newTotalOwed = personResult.totalOwed + proportionOfTotal * differenceToAdjust;
            
            results[i] = SplitCalculation(
              personId: personResult.personId,
              personName: personResult.personName,
              itemsValue: personResult.itemsValue,
              sharedCostsAndDiscounts: personResult.sharedCostsAndDiscounts,
              totalOwed: newTotalOwed,
              breakdown: personResult.breakdown,
            );
          }
        } else {
          final adjustmentPerPerson = differenceToAdjust / results.length;
          for (int i = 0; i < results.length; i++) {
            final personResult = results[i];
            results[i] = SplitCalculation(
              personId: personResult.personId,
              personName: personResult.personName,
              itemsValue: personResult.itemsValue,
              sharedCostsAndDiscounts: personResult.sharedCostsAndDiscounts,
              totalOwed: personResult.totalOwed + adjustmentPerPerson,
              breakdown: personResult.breakdown,
            );
          }
        }
      }
    }
    
    // 5. Final precision check and negative amount prevention
    double finalSumOfSplits = results.fold<double>(0.0, (sum, r) => sum + r.totalOwed);
    if (bill.grandTotal != null && bill.grandTotal != null && results.isNotEmpty) {
        for (int i = 0; i < results.length; i++) {
          final personResult = results[i];
          if (personResult.totalOwed < 0 && bill.grandTotal! >= 0) {
            results[i] = SplitCalculation(
              personId: personResult.personId,
              personName: personResult.personName,
              itemsValue: personResult.itemsValue,
              sharedCostsAndDiscounts: personResult.sharedCostsAndDiscounts,
              totalOwed: 0.0,
              breakdown: personResult.breakdown,
            );
          }
        }
        
        finalSumOfSplits = results.fold<double>(0.0, (sum, r) => sum + r.totalOwed);
        final tinyRemainder = bill.grandTotal! - finalSumOfSplits;

        if (tinyRemainder.abs() > 1e-9) { 
            var personToAdjust = results.firstWhere(
              (r) => r.totalOwed > 0,
              orElse: () => results.first,
            );

            final index = results.indexWhere((r) => r.personId == personToAdjust.personId);
            results[index] = SplitCalculation(
              personId: personToAdjust.personId,
              personName: personToAdjust.personName,
              itemsValue: personToAdjust.itemsValue,
              sharedCostsAndDiscounts: personToAdjust.sharedCostsAndDiscounts,
              totalOwed: personToAdjust.totalOwed + tinyRemainder,
              breakdown: personToAdjust.breakdown,
            );
        }
    }

    return results;
  }

  static String formatCurrency(double? amount, String currency) {
    if (amount == null) return 'N/A';
    
    try {
      final formatter = NumberFormat.currency(symbol: _getCurrencySymbol(currency));
      return formatter.format(amount);
    } catch (error) {
      // print('Invalid currency code \'$currency\' provided. Using fallback formatting.');
      final formatter = NumberFormat('#,##0.00');
      return '${_getCurrencySymbol(currency)} ${formatter.format(amount)}';
    }
  }

  static String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      default:
        return currency;
    }
  }
}
