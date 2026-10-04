import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VardiyaSistemi {
  sistem12_24, // 1 Gündüz, 1 Gece, 1 Tatil
  sistem12_36, // 1 Gündüz, 1 Gece, 2 Tatil
  sistem24_48, // 24 Saat Nöbet, 2 Tatil
  ikiGunduz_ikiGece_ikiTatil, // 2 Gündüz, 2 Gece, 2 Tatil
  ozelDuzen // ÖZEL SİSTEM (Saat destekli)
}

class ShiftCalculator {
  DateTime initialDayShift;
  VardiyaSistemi sistem;
  List<String> ozelDongu;

  ShiftCalculator(this.initialDayShift, this.sistem, {this.ozelDongu = const []});

  String getShiftType(DateTime targetDate) {
    DateTime start = DateTime(initialDayShift.year, initialDayShift.month, initialDayShift.day);
    DateTime target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    int difference = target.difference(start).inDays;

    if (sistem == VardiyaSistemi.ozelDuzen) {
      if (ozelDongu.isEmpty) return "Tatil\n(İstirahat)";

      int cycleLength = ozelDongu.length;
      int cycle = (difference % cycleLength + cycleLength) % cycleLength;
      String shiftData = ozelDongu[cycle];

      if (shiftData.contains('|')) {
        List<String> parts = shiftData.split('|');
        return "${parts[0]}\n(${parts[1]})"; // E.g., Gündüz\n(08:00 - 16:00)
      } else {
        if (shiftData == "Gündüz") return "Gündüz\n(08:00 - 16:00)";
        if (shiftData == "Akşam") return "Akşam\n(16:00 - 00:00)";
        if (shiftData == "Gece") return "Gece\n(00:00 - 08:00)";
        if (shiftData == "Nöbet") return "24 Saat\nNöbet";
        return "Tatil\n(İstirahat)";
      }
    }

    switch (sistem) {
      case VardiyaSistemi.sistem12_24:
        int cycle = (difference % 3 + 3) % 3;
        if (cycle == 0) return "Gündüz\n(08:00 - 20:00)";
        if (cycle == 1) return "Gece\n(20:00 - 08:00)";
        return "Tatil\n(İstirahat)";

      case VardiyaSistemi.sistem12_36:
        int cycle = (difference % 4 + 4) % 4;
        if (cycle == 0) return "Gündüz\n(08:00 - 20:00)";
        if (cycle == 1) return "Gece\n(20:00 - 08:00)";
        return "Tatil\n(İstirahat)";

      case VardiyaSistemi.sistem24_48:
        int cycle = (difference % 3 + 3) % 3;
        if (cycle == 0) return "24 Saat\nNöbet";
        return "Tatil\n(İstirahat)";

      case VardiyaSistemi.ikiGunduz_ikiGece_ikiTatil:
        int cycle = (difference % 6 + 6) % 6;
        if (cycle == 0 || cycle == 1) return "Gündüz\n(08:00 - 20:00)";
        if (cycle == 2 || cycle == 3) return "Gece\n(20:00 - 08:00)";
        return "Tatil\n(İstirahat)";

      default:
        return "Tatil\n(İstirahat)";
    }
  }

  String getShiftNameOnly(DateTime targetDate) {
    String fullShift = getShiftType(targetDate);
    return fullShift.split('\n')[0];
  }
}
