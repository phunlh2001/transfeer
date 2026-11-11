import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/portfolio.dart';

/// The user's holding, DCA purchases, DCA plan, and the last known price,
/// saved on the device (shared_preferences works on Android and Web).
///
/// [holding] is always the CURRENT total. Recording a DCA purchase adds it to
/// the total; deleting one subtracts it. The total can also be edited directly.
class PortfolioStore extends ChangeNotifier {
  static const _kInvested = 'pf.invested';
  static const _kUnits = 'pf.units';
  static const _kSince = 'pf.since';
  static const _kBuys = 'pf.buys';
  static const _kDcaAmount = 'pf.dcaAmount';
  static const _kDcaFreq = 'pf.dcaFreq';
  static const _kRate = 'pf.ratePct'; // manual override, % per year
  static const _kYears = 'pf.years';
  static const _kPrice = 'last.price';
  static const _kPriceAt = 'last.priceAt';

  SharedPreferences? _prefs;
  bool loaded = false;

  Holding? holding;
  List<Purchase> buys = []; // newest first
  double dcaAmount = 0;
  DcaFrequency dcaFreq = DcaFrequency.monthly;
  double? rateOverridePct; // null = use the user's own yearly growth
  int years = 10;
  double? lastPrice;
  DateTime? lastPriceAt;
  DateTime? _lastPersist;

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      final inv = p.getDouble(_kInvested);
      final units = p.getDouble(_kUnits);
      final since = p.getInt(_kSince);
      if (inv != null && units != null) {
        holding = Holding(
          invested: inv,
          units: units,
          since: since == null ? null : DateTime.fromMillisecondsSinceEpoch(since),
        );
      }
      final raw = p.getString(_kBuys);
      if (raw != null) {
        buys = [
          for (final j in jsonDecode(raw) as List) Purchase.fromJson((j as Map).cast<String, dynamic>())
        ]..sort((a, b) => b.date.compareTo(a.date));
      }
      dcaAmount = p.getDouble(_kDcaAmount) ?? 0;
      dcaFreq = DcaFrequency.parse(p.getString(_kDcaFreq));
      rateOverridePct = p.getDouble(_kRate);
      years = (p.getInt(_kYears) ?? 10).clamp(5, 10);
      lastPrice = p.getDouble(_kPrice);
      final at = p.getInt(_kPriceAt);
      lastPriceAt = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    } catch (e) {
      debugPrint('PortfolioStore.load failed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  // ------------------------------------------------------------- holding
  /// Sets the current totals (first-time entry or a manual correction).
  Future<void> setHolding(Holding h) async {
    holding = h;
    notifyListeners();
    await _saveHolding();
  }

  /// Removes everything (totals and purchase log).
  Future<void> clear() async {
    holding = null;
    buys = [];
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    for (final k in [_kInvested, _kUnits, _kSince, _kBuys]) {
      await p.remove(k);
    }
  }

  /// Records a DCA buy and adds it to the totals.
  Future<void> addPurchase(Purchase b) async {
    final h = holding;
    holding = Holding(
      invested: (h?.invested ?? 0) + b.cost,
      units: (h?.units ?? 0) + b.units,
      since: _sinceAfterBuy(h, b.date),
    );
    buys = [b, ...buys]..sort((a, c) => c.date.compareTo(a.date));
    notifyListeners();
    await _saveHolding();
    await _saveBuys();
  }

  /// Deletes a DCA buy and subtracts it from the totals.
  Future<void> removePurchase(Purchase b) async {
    final h = holding;
    buys = buys.where((x) => x.id != b.id).toList();
    if (h != null) {
      holding = Holding(
        invested: (h.invested - b.cost).clamp(0, double.infinity),
        units: (h.units - b.units).clamp(0, double.infinity),
        since: h.since,
      );
    }
    notifyListeners();
    await _saveHolding();
    await _saveBuys();
  }

  /// First buy ever -> its date. Existing total with an unknown start date ->
  /// stays unknown. Otherwise the earlier of the two.
  static DateTime? _sinceAfterBuy(Holding? h, DateTime date) {
    if (h == null || !h.isValid) return date;
    final s = h.since;
    if (s == null) return null;
    return date.isBefore(s) ? date : s;
  }

  Future<void> _saveHolding() async {
    final p = _prefs, h = holding;
    if (p == null) return;
    if (h == null) {
      await p.remove(_kInvested);
      await p.remove(_kUnits);
      await p.remove(_kSince);
      return;
    }
    await p.setDouble(_kInvested, h.invested);
    await p.setDouble(_kUnits, h.units);
    if (h.since == null) {
      await p.remove(_kSince);
    } else {
      await p.setInt(_kSince, h.since!.millisecondsSinceEpoch);
    }
  }

  Future<void> _saveBuys() async {
    await _prefs?.setString(_kBuys, jsonEncode([for (final b in buys) b.toJson()]));
  }

  // ---------------------------------------------------------- projection
  void setDcaAmount(double v) {
    if (v == dcaAmount) return;
    dcaAmount = v;
    notifyListeners();
    _prefs?.setDouble(_kDcaAmount, v);
  }

  void setDcaFreq(DcaFrequency f) {
    if (f == dcaFreq) return;
    dcaFreq = f;
    notifyListeners();
    _prefs?.setString(_kDcaFreq, f.name);
  }

  void setRateOverride(double? pct) {
    if (pct == rateOverridePct) return;
    rateOverridePct = pct;
    notifyListeners();
    if (pct == null) {
      _prefs?.remove(_kRate);
    } else {
      _prefs?.setDouble(_kRate, pct);
    }
  }

  void setYears(int v) {
    if (v == years) return;
    years = v;
    notifyListeners();
    _prefs?.setInt(_kYears, v);
  }

  // --------------------------------------------------------------- price
  /// Called on every successful poll. Saves to disk when the price changes,
  /// otherwise at most once a minute, so the closed screen can use it.
  void recordPrice(double price, DateTime at) {
    final changed = price != lastPrice;
    lastPrice = price;
    lastPriceAt = at;
    if (changed) notifyListeners();
    final p = _prefs;
    if (p == null) return;
    if (changed || _lastPersist == null || at.difference(_lastPersist!).inSeconds >= 60) {
      _lastPersist = at;
      p.setDouble(_kPrice, price);
      p.setInt(_kPriceAt, at.millisecondsSinceEpoch);
    }
  }
}
