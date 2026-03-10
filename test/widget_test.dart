import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_quantum_one/main.dart';

void main() {
  testWidgets('SaaSLand dashboard renders core sections', (
    WidgetTester tester,
  ) async {
    // Desktop-class viewport
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const QuantumOneApp());

    // Pump enough time to resolve all FadeSlide Future.delayed timers
    // (max delay 500ms + animation 600ms ≈ 1.2s) and HTTP futures
    await tester.pump(const Duration(seconds: 2));

    // ── Top bar ──
    expect(find.text('The Quantum One'), findsOneWidget);
    expect(find.text('9 MARCH 2026'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);

    // ── Stats ribbon ──
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Ethereum'), findsOneWidget);
    expect(find.text('Solana'), findsOneWidget);

    // ── Section headers ──
    expect(find.text('Intelligence Ledger'), findsOneWidget);

    // ── Scroll to reveal more ──
    final listFinder = find.byType(ListView).first;
    await tester.drag(listFinder, const Offset(0, -600));
    // Pump to render scrolled content and resolve new FadeSlide timers
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Health Prescription'), findsOneWidget);

    // Final pump to clear any remaining timers from scrolled-in widgets
    await tester.pump(const Duration(seconds: 2));
  });
}
