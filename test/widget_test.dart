// Reemplaza test/widget_test.dart por este archivo.
// Ejecutar con: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartdispatch_ucb/main.dart';

void main() {
  testWidgets('La app muestra el título y la navegación', (tester) async {
    await tester.pumpWidget(const SmartDispatchApp());
    expect(find.text('SmartDispatch UCB'), findsWidgets);
    expect(find.text('Introducción'), findsWidgets);

    // Detiene las animaciones infinitas del hero para cerrar el test limpiamente.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('El Método Húngaro encuentra el costo mínimo', () {
    final cost = [
      [4, 1, 3],
      [2, 0, 5],
      [3, 2, 2],
    ];
    final result = HungarianSolver.solve(cost);
    expect(result.totalCost, 5);
    expect(result.assignment, [1, 0, 2]);
  });

  test('El Método Húngaro en maximización encuentra el valor máximo', () {
    final cost = [
      [4, 1, 3],
      [2, 0, 5],
      [3, 2, 2],
    ];
    final result = HungarianSolver.solve(cost, maximize: true);
    expect(result.totalCost, 11);
  });

  test('El caso precargado: húngaro 67 min frente a voraz 94 min', () {
    final cost = CampusPreset.costs;
    final opt = HungarianSolver.solve(cost);
    final greedy = GreedySolver.solve(cost);
    expect(opt.totalCost, 67);
    expect(greedy.totalCost, 94);
    expect(opt.assignment, CampusPreset.optimal);
  });
}