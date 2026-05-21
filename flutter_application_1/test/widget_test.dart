// Vardiya Takip - Temel Widget Testi
// Not: Uygulama Firebase gerektirdiğinden tam entegrasyon testleri
// ayrı bir ortamda yapılmalıdır.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('ShiftCalculator - 12/24 sistemi doğru hesaplıyor', () {
    final calc = ShiftCalculator(
      DateTime(2024, 1, 1),
      VardiyaSistemi.sistem12_24,
    );

    // Gün 0 → Gündüz
    expect(calc.getShiftType(DateTime(2024, 1, 1)), contains('Gündüz'));
    // Gün 1 → Gece
    expect(calc.getShiftType(DateTime(2024, 1, 2)), contains('Gece'));
    // Gün 2 → Tatil
    expect(calc.getShiftType(DateTime(2024, 1, 3)), contains('Tatil'));
    // Gün 3 → tekrar Gündüz (döngü)
    expect(calc.getShiftType(DateTime(2024, 1, 4)), contains('Gündüz'));
  });

  test('ShiftCalculator - 24/48 sistemi doğru hesaplıyor', () {
    final calc = ShiftCalculator(
      DateTime(2024, 1, 1),
      VardiyaSistemi.sistem24_48,
    );

    expect(calc.getShiftType(DateTime(2024, 1, 1)), contains('Nöbet'));
    expect(calc.getShiftType(DateTime(2024, 1, 2)), contains('Tatil'));
    expect(calc.getShiftType(DateTime(2024, 1, 3)), contains('Tatil'));
    expect(calc.getShiftType(DateTime(2024, 1, 4)), contains('Nöbet'));
  });

  test('ShiftCalculator - özel döngü doğru çalışıyor', () {
    final calc = ShiftCalculator(
      DateTime(2024, 1, 1),
      VardiyaSistemi.ozelDuzen,
      ozelDongu: ['Gündüz', 'Gece', 'Tatil', 'Tatil'],
    );

    expect(calc.getShiftType(DateTime(2024, 1, 1)), contains('Gündüz'));
    expect(calc.getShiftType(DateTime(2024, 1, 2)), contains('Gece'));
    expect(calc.getShiftType(DateTime(2024, 1, 3)), contains('Tatil'));
    expect(calc.getShiftType(DateTime(2024, 1, 4)), contains('Tatil'));
    expect(calc.getShiftType(DateTime(2024, 1, 5)), contains('Gündüz')); // döngü
  });
}
