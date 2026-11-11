import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transfeer/screens/portfolio_screen.dart';
import 'package:transfeer/state/portfolio_store.dart';
import 'package:transfeer/theme.dart';

Future<PortfolioStore> _store(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = PortfolioStore();
  await s.load();
  return s;
}

/// Uses the REAL app theme: its button sizes broke the sheet before.
Widget _app(PortfolioStore s, Widget child) => ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('vi', 'VN'),
        supportedLocales: const [Locale('vi', 'VN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: child),
      ),
    );

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// Several frames (pumpAndSettle never ends: the Lottie animations loop).
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls the page's ListView (it builds lazily) until [f] is on screen.
Future<void> _show(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(t.element(f), alignment: 0.5);
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('first time: enter current total, then edit it', (t) async {
    _phone(t);
    final s = await _store({});
    await t.pumpWidget(_app(s, const PortfolioScreen(livePrice: 23100)));
    await _settle(t);

    await t.tap(find.text('Nhập tài sản hiện có'));
    await _settle(t);
    expect(find.text('Tài sản hiện có'), findsOneWidget); // sheet opened
    await t.enterText(find.widgetWithText(TextField, 'Tổng tiền đã đầu tư'), '10000000');
    await t.enterText(find.widgetWithText(TextField, 'Số CCQ đang có'), '500');
    await t.pump();
    await t.tap(find.text('Lưu'));
    await _settle(t);

    expect(s.holding!.invested, 10e6);
    expect(s.holding!.units, 500);
    expect(find.text('11.550.000 ₫'), findsOneWidget);
    expect(find.textContaining('Lãi 1.550.000 ₫ (+15,50%)'), findsOneWidget);

    // edit the total
    await t.tap(find.byTooltip('Sửa tổng tài sản'));
    await _settle(t);
    expect(find.text('Sửa tổng tài sản'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Số CCQ đang có'), '400');
    await t.pump();
    await t.tap(find.text('Lưu'));
    await _settle(t);
    expect(s.holding!.units, 400);
    expect(find.textContaining('Lỗ 760.000 ₫'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('add DCA buys on top of the total, then delete one', (t) async {
    _phone(t);
    final s = await _store({'pf.invested': 10000000.0, 'pf.units': 500.0});
    await t.pumpWidget(_app(s, const PortfolioScreen(livePrice: 23100)));
    await _settle(t);

    await _show(t, find.text('Thêm lần mua'));
    await t.tap(find.text('Thêm lần mua'));
    await _settle(t);
    expect(find.text('Ghi lại một lần mua thêm (DCA). Số tiền và số CCQ sẽ được cộng vào tổng tài sản.'),
        findsOneWidget);
    // price is prefilled with the live price; buy by money
    await t.enterText(find.widgetWithText(TextField, 'Số tiền mua'), '1000000');
    await t.pump();
    expect(find.textContaining('Mua 43 CCQ · thành tiền 993.300 ₫'), findsOneWidget);
    expect(find.textContaining('Tiền dư: 6.700 ₫'), findsOneWidget);
    await t.tap(find.text('Thêm'));
    await _settle(t);

    expect(s.buys, hasLength(1));
    expect(s.holding!.units, 543);
    expect(s.holding!.invested, 10993300);
    expect(find.textContaining('1 lần mua'), findsOneWidget);
    expect(find.text('+43 CCQ × 23.100'), findsOneWidget);

    // second buy by units
    await _show(t, find.text('Thêm lần mua'));
    await t.tap(find.text('Thêm lần mua'));
    await _settle(t);
    await t.tap(find.text('Theo số CCQ'));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'Số CCQ mua'), '10');
    await t.pump();
    await t.tap(find.text('Thêm'));
    await _settle(t);
    expect(s.holding!.units, 553);

    // delete the first one again
    await _show(t, find.text('+43 CCQ × 23.100'));
    await t.tap(find.byTooltip('Xoá lần mua').last);
    await _settle(t);
    await t.tap(find.text('Xoá'));
    await _settle(t);
    expect(s.buys, hasLength(1));
    expect(s.holding!.units, 510);
    expect(s.holding!.invested, 10000000 + 231000);
    expect(t.takeException(), isNull);
  });

  testWidgets('weekly DCA plan projection', (t) async {
    _phone(t);
    final s = await _store({
      'pf.invested': 10000000.0,
      'pf.units': 500.0,
      'pf.since': DateTime.now().subtract(const Duration(days: 800)).millisecondsSinceEpoch,
      'pf.years': 10,
    });
    await t.pumpWidget(_app(s, const PortfolioScreen(livePrice: 23100)));
    await _settle(t);
    expect(find.textContaining('Tăng trưởng bình quân +'), findsOneWidget);

    await _show(t, find.text('Hàng tuần'));
    await t.tap(find.text('Hàng tuần'));
    await _settle(t);
    expect(s.dcaFreq.name, 'weekly');
    expect(find.text('Số tiền mua mỗi tuần'), findsOneWidget);
    await t.tap(find.text('500 nghìn'));
    await t.enterText(find.widgetWithText(TextField, 'Tăng trưởng mỗi năm'), '0');
    await _show(t, find.text('5 năm'));
    await t.tap(find.text('5 năm'));
    await _settle(t);

    expect(s.dcaAmount, 500e3);
    await _show(t, find.text('Sau 5 năm, tài sản dự kiến'));
    // 11.55tr now + 500k × 52 × 5 at 0%
    expect(find.text('141.550.000 ₫'), findsWidgets);
    expect(find.text('130.000.000 ₫'), findsOneWidget); // "Trong đó mua thêm"
    expect(t.takeException(), isNull);
  });

  testWidgets('first buy without a total', (t) async {
    _phone(t);
    final s = await _store({});
    await t.pumpWidget(_app(s, const PortfolioScreen(livePrice: 23100)));
    await _settle(t);
    await t.tap(find.text('Chưa có? Ghi lại lần mua đầu tiên'));
    await _settle(t);
    await t.enterText(find.widgetWithText(TextField, 'Số tiền mua'), '5000000');
    await t.pump();
    await t.tap(find.text('Thêm'));
    await _settle(t);
    expect(s.holding!.units, 216);
    expect(s.holding!.since, isNotNull);
    expect(find.text('Giá trị hiện tại'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('closed page uses the last saved price', (t) async {
    final s = await _store({
      'pf.invested': 1000000.0,
      'pf.units': 40.0,
      'last.price': 25000.0,
      'last.priceAt': DateTime(2026, 11, 10, 14, 59).millisecondsSinceEpoch,
    });
    await t.pumpWidget(_app(s, const PortfolioScreen()));
    await _settle(t);
    expect(find.text('1.000.000 ₫'), findsOneWidget); // 40 × 25.000
    expect(find.textContaining('Theo giá gần nhất 25.000 ₫ · 14:59, 10/11'), findsOneWidget);
  });

  testWidgets('no price yet', (t) async {
    final s = await _store({'pf.invested': 1000000.0, 'pf.units': 40.0});
    await t.pumpWidget(_app(s, const PortfolioScreen()));
    await _settle(t);
    expect(find.textContaining('Chưa có giá FUESSV30'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
