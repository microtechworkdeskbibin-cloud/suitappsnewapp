import 'package:flutter/material.dart';

/// How a line-item discount value should be interpreted.
enum DiscountType { percent, amount }

/// A single line item on a bill.
///
/// IMPORTANT â€” tax handling:
/// `rate` can be either a TAX-INCLUSIVE or TAX-EXCLUSIVE unit price,
/// depending on [taxMode] (mirrors the TAX_MODE permission and the
/// Include/Exclude selector on SelectItemPage â€” see
/// _SelectItemPageState._taxMode / _LineDraft.taxAmountFor/netAmountFor):
///
/// - taxMode = 'INCLUDE' (default): `rate` already has GST baked in.
///   e.g. rate=100, qty=1, taxPercent=5 -> customer pays â‚¹100 total for
///   that line, NOT â‚¹100 + 5% tax. The pre-tax base is *extracted* from
///   the tax-inclusive rate:
///     grossAmount = (rate * qty) / (1 + taxPercent / 100)
///
/// - taxMode = 'EXCLUDE': `rate` is tax-free. Tax is calculated ON TOP
///   of it instead of being extracted:
///     grossAmount = rate * qty
///
/// From there on the two modes are identical â€” discount is applied to
/// [grossAmount] to get [taxableAmount] (the post-discount, pre-tax
/// base), tax is recomputed on THAT ([taxAmount]), and [netAmount] is
/// their sum. This is what makes
///   Sub Total (Î£ taxableAmount) + Tax (Î£ taxAmount)
/// equal the correct final total in either mode. [grossAmount] here is
/// still the PRE-discount base, kept purely so the discount % display
/// and rupee value are computed consistently â€” the bill-level "Sub
/// Total" shown in DirectSaleOfCustomer should sum [taxableAmount]
/// (post-discount), not [grossAmount] (pre-discount).
class BillItem {
  final String productId;
  final String name;
  final IconData icon;
  final Color iconColor;

  /// Which price column this line was taken from (MRP / DP / SP / WP / CCP...).
  final String rateType;

  /// Unit price for the selected [rateType]. Whether this is tax-inclusive
  /// or tax-exclusive depends on [taxMode].
  final double rate;

  final int qty;
  final int freeQty;

  /// The unit of measure this item was sold in (e.g. "PCS", "BOX", "KG"),
  /// as an ID from the server's unit master. Must be captured on
  /// SelectItemPage (from the product's UnitID) and carried through
  /// unchanged so it can be saved locally and sent to the API â€” the
  /// server's BillingDetails.UnitID column depends on it.
  final String unitId;

  final DiscountType discountType;

  /// Meaning depends on [discountType]:
  /// - [DiscountType.percent]: a percentage (e.g. 10 for 10%)
  /// - [DiscountType.amount]: a flat currency amount
  final double discountValue;

  /// GST/tax percentage applicable to this item (e.g. 5 for 5%).
  final double taxPercent;

  /// 'INCLUDE' or 'EXCLUDE' â€” which tax calculation to apply to [rate].
  /// Set from the Include/Exclude selection made on SelectItemPage (see
  /// _LineDraft.toBillItem), which in turn comes from the TAX_MODE
  /// permission. Defaults to 'INCLUDE' so any other/older caller that
  /// doesn't pass this keeps the original tax-inclusive behavior.
  final String taxMode;

  const BillItem({
    required this.productId,
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.rateType,
    required this.rate,
    required this.qty,
    this.freeQty = 0,
    required this.unitId,
    required this.discountType,
    required this.discountValue,
    required this.taxPercent,
    this.taxMode = 'INCLUDE',
  });

  // ------------------------------------------------------------
  // Internal helpers
  // ------------------------------------------------------------

  /// Line total before any discount, at [rate] * [qty] â€” tax-inclusive or
  /// tax-exclusive depending on [taxMode] (see [grossAmount]).
  double get _lineTotal => rate * qty;

  // ------------------------------------------------------------
  // Public amounts
  // ------------------------------------------------------------

  /// Pre-tax (base) amount for the full line, BEFORE discount.
  ///
  /// - taxMode = 'INCLUDE': extracted from the tax-inclusive [_lineTotal].
  ///   e.g. rate=100, qty=1, taxPercent=5 -> 95.24
  /// - taxMode = 'EXCLUDE': [_lineTotal] IS the pre-tax base already â€”
  ///   nothing to extract. e.g. rate=100, qty=1 -> 100.00
  ///
  /// NOTE: this is the pre-discount base â€” used internally to compute
  /// [discountAmount] and [discountPercentDisplay] consistently. Do NOT
  /// sum this for a bill's "Sub Total"; use [taxableAmount] instead,
  /// which already has the discount applied.
  double get grossAmount {
    if (taxMode == 'EXCLUDE') return _lineTotal;
    if (taxPercent <= 0) return _lineTotal;
    final divisor = 1 + (taxPercent / 100);
    return divisor == 0 ? _lineTotal : _lineTotal / divisor;
  }

  /// Discount amount in currency, applied to the pre-tax base
  /// ([grossAmount]). A percentage discount gives the same rupee result
  /// whether it's computed on the tax-inclusive total or the pre-tax
  /// base â€” tax extraction is just a linear scale â€” so this stays
  /// consistent with the discount preview shown on the item-select page,
  /// in either tax mode.
  double get discountAmount {
    double amount;
    if (discountType == DiscountType.percent) {
      amount = grossAmount * discountValue / 100;
    } else {
      amount = discountValue;
    }
    if (amount < 0) return 0;
    if (amount > grossAmount) return grossAmount;
    return amount;
  }

  /// Discount expressed as a percentage, for display purposes
  /// (e.g. "10% off"), regardless of how it was entered.
  double get discountPercentDisplay {
    if (discountType == DiscountType.percent) return discountValue;
    return grossAmount > 0 ? (discountAmount / grossAmount * 100) : 0;
  }

  /// Pre-tax base amount AFTER discount â€” this is what tax is charged on,
  /// and this is what a bill's "Sub Total" should sum across items.
  /// - INCLUDE example: rate=100, qty=1, taxPercent=5, disc=20% -> 76.19
  /// - EXCLUDE example: rate=100, qty=1, taxPercent=5, disc=20% -> 80.00
  double get taxableAmount {
    final value = grossAmount - discountAmount;
    return value < 0 ? 0 : value;
  }

  /// Tax charged on the discounted base amount â€” same formula in both
  /// modes; only [grossAmount] (and therefore [taxableAmount]) differs.
  double get taxAmount => taxableAmount * taxPercent / 100;

  /// Final payable amount for this line, post-discount.
  /// - INCLUDE: tax is already inside [taxableAmount]'s underlying rate,
  ///   so this recomputes it on the discounted base â€” e.g. rate=100,
  ///   qty=1, taxPercent=5, no discount: 95.24 + 4.76 = 100.00.
  /// - EXCLUDE: tax is added on top of the discounted base â€” e.g.
  ///   rate=100, qty=1, taxPercent=5, no discount: 100.00 + 5.00 = 105.00.
  double get netAmount => taxableAmount + taxAmount;
}
