// =====================================================================
// SmartDispatch UCB · Asignación óptima de soporte técnico (v3)
// Método Húngaro implementado desde cero en Dart puro.
//
// Uso: reemplaza lib/main.dart por este archivo (renómbralo a main.dart).
//   flutter run -d chrome
// Sin paquetes externos: sólo Flutter SDK.
// =====================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final math.Random _rng = math.Random();

void main() => runApp(const SmartDispatchApp());

// =====================================================================
// 1. PALETA Y TEMA
// =====================================================================
class Brand {
  static const navy = Color(0xFF0B2545);
  static const navyLight = Color(0xFF1B4079);
  static const ink = Color(0xFF071A30);
  static const cyan = Color(0xFF00B4D8);
  static const cyanSoft = Color(0xFFCAF0F8);
  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF7C3AED);
  static const coral = Color(0xFFF9735B);
  static const white = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF4F6FA);
  static const grayLight = Color(0xFFE6EAF0);
  static const grayDark = Color(0xFF1F2933);
  static const grayMid = Color(0xFF5F6B7A);
  static const success = Color(0xFF2A9D8F);
  static const amber = Color(0xFFFFE8A3);
}

class SmartDispatchApp extends StatelessWidget {
  const SmartDispatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Brand.navy).copyWith(
      primary: Brand.navy,
      secondary: Brand.cyan,
      surface: Brand.white,
    );
    return MaterialApp(
      title: 'SmartDispatch UCB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Brand.canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: Brand.navy,
          foregroundColor: Brand.white,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// =====================================================================
// 2. ALGORITMO HÚNGARO (minimización; maximización por transformación)
// =====================================================================
class HungarianStep {
  HungarianStep({
    required this.title,
    required this.description,
    required this.matrix,
    this.coveredRows,
    this.coveredCols,
  });

  final String title;
  final String description;
  final List<List<int>> matrix;
  final List<bool>? coveredRows;
  final List<bool>? coveredCols;
}

class HungarianResult {
  HungarianResult({
    required this.assignment,
    required this.totalCost,
    required this.steps,
    required this.iterations,
  });

  /// assignment[i] = índice de la columna (técnico) asignada a la fila i.
  final List<int> assignment;
  final int totalCost;
  final List<HungarianStep> steps;
  final int iterations;
}

class HungarianSolver {
  /// Resuelve el problema de asignación de costo mínimo (o máximo si
  /// [maximize] es true) sobre una matriz cuadrada de enteros no negativos.
  /// Complejidad temporal: O(n^3).
  static HungarianResult solve(List<List<int>> cost, {bool maximize = false}) {
    final n = cost.length;
    final steps = <HungarianStep>[];

    // Maximización: C' = max - C convierte el problema en minimización.
    final maxVal = maximize
        ? cost.expand((r) => r).reduce((a, b) => math.max(a, b))
        : 0;
    final m = List<List<int>>.generate(
      n,
      (i) => List<int>.generate(
        n,
        (j) => maximize ? maxVal - cost[i][j] : cost[i][j],
      ),
    );

    steps.add(
      HungarianStep(
        title: 'Matriz inicial',
        description: maximize
            ? 'Modo maximización: se transforma C′ = max − C para convertirlo en un problema de minimización.'
            : 'Matriz de costos original (minutos estimados).',
        matrix: _copy(m),
      ),
    );

    // Paso 1: reducción por filas.
    for (var i = 0; i < n; i++) {
      final rowMin = m[i].reduce((a, b) => math.min(a, b));
      for (var j = 0; j < n; j++) {
        m[i][j] -= rowMin;
      }
    }
    steps.add(
      HungarianStep(
        title: 'Reducción de filas',
        description: 'Se resta el mínimo de cada fila. Ahora cada fila contiene al menos un cero.',
        matrix: _copy(m),
      ),
    );

    // Paso 2: reducción por columnas.
    for (var j = 0; j < n; j++) {
      var colMin = m[0][j];
      for (var i = 1; i < n; i++) {
        colMin = math.min(colMin, m[i][j]);
      }
      for (var i = 0; i < n; i++) {
        m[i][j] -= colMin;
      }
    }
    steps.add(
      HungarianStep(
        title: 'Reducción de columnas',
        description: 'Se resta el mínimo de cada columna. Ahora cada columna también tiene al menos un cero.',
        matrix: _copy(m),
      ),
    );

    // Pasos 3 y 4: iterar hasta encontrar n ceros independientes.
    var rowAssign = List<int>.filled(n, -1);
    var iteration = 0;

    while (true) {
      iteration++;
      rowAssign = List<int>.filled(n, -1);
      final colAssign = List<int>.filled(n, -1);

      // Emparejamiento máximo sobre los ceros (caminos aumentantes).
      var matched = 0;
      for (var i = 0; i < n; i++) {
        if (_augment(i, m, rowAssign, colAssign, List<bool>.filled(n, false))) {
          matched++;
        }
      }
      if (matched == n) break;

      // Recubrimiento mínimo de ceros (teorema de König): se marcan las filas
      // y columnas alcanzables desde filas libres por caminos alternantes.
      final rowReach = List<bool>.filled(n, false);
      final colReach = List<bool>.filled(n, false);
      final queue = <int>[];
      for (var i = 0; i < n; i++) {
        if (rowAssign[i] == -1) {
          rowReach[i] = true;
          queue.add(i);
        }
      }
      while (queue.isNotEmpty) {
        final r = queue.removeLast();
        for (var c = 0; c < n; c++) {
          if (m[r][c] == 0 && !colReach[c]) {
            colReach[c] = true;
            final r2 = colAssign[c];
            if (r2 != -1 && !rowReach[r2]) {
              rowReach[r2] = true;
              queue.add(r2);
            }
          }
        }
      }

      // Líneas: filas NO alcanzadas + columnas alcanzadas.
      final coveredRows = [for (final r in rowReach) !r];
      final coveredCols = List<bool>.from(colReach);
      final lines =
          coveredRows.where((e) => e).length +
          coveredCols.where((e) => e).length;

      steps.add(
        HungarianStep(
          title: 'Iteración $iteration · recubrimiento de ceros',
          description:
              'Se logran $matched de $n asignaciones independientes con ceros. '
              'Se trazan $lines líneas que cubren todos los ceros; como $lines < $n, hay que ajustar la matriz.',
          matrix: _copy(m),
          coveredRows: coveredRows,
          coveredCols: coveredCols,
        ),
      );

      // Ajuste: mínimo valor no cubierto.
      var minUncovered = 1 << 30;
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          if (rowReach[i] && !colReach[j]) {
            minUncovered = math.min(minUncovered, m[i][j]);
          }
        }
      }
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          if (rowReach[i] && !colReach[j]) {
            m[i][j] -= minUncovered;
          } else if (!rowReach[i] && colReach[j]) {
            m[i][j] += minUncovered;
          }
        }
      }

      steps.add(
        HungarianStep(
          title: 'Ajuste de la matriz',
          description:
              'Mínimo no cubierto = $minUncovered. Se resta a los elementos no cubiertos '
              'y se suma a los que quedan cubiertos por dos líneas.',
          matrix: _copy(m),
        ),
      );
    }

    var total = 0;
    for (var i = 0; i < n; i++) {
      total += cost[i][rowAssign[i]];
    }

    steps.add(
      HungarianStep(
        title: 'Asignación óptima',
        description:
            'Se obtienen $n ceros independientes: cada solicitud queda asignada a un único técnico '
            'y cada técnico atiende una sola solicitud.',
        matrix: _copy(m),
      ),
    );

    return HungarianResult(
      assignment: rowAssign,
      totalCost: total,
      steps: steps,
      iterations: iteration,
    );
  }

  /// Búsqueda de camino aumentante (Kuhn) sobre las aristas de costo cero.
  static bool _augment(
    int r,
    List<List<int>> m,
    List<int> rowAssign,
    List<int> colAssign,
    List<bool> visited,
  ) {
    for (var c = 0; c < m.length; c++) {
      if (m[r][c] == 0 && !visited[c]) {
        visited[c] = true;
        if (colAssign[c] == -1 ||
            _augment(colAssign[c], m, rowAssign, colAssign, visited)) {
          rowAssign[r] = c;
          colAssign[c] = r;
          return true;
        }
      }
    }
    return false;
  }

  static List<List<int>> _copy(List<List<int>> m) => [
    for (final r in m) List<int>.from(r),
  ];
}

// =====================================================================
// 3. ASIGNACIÓN VORAZ (ingenua) PARA COMPARACIÓN
// =====================================================================
class GreedyResult {
  GreedyResult({required this.assignment, required this.totalCost});
  final List<int> assignment;
  final int totalCost;
}

class GreedySolver {
  /// Atiende las solicitudes en orden de llegada; cada una toma el técnico
  /// disponible con menor costo (o mayor puntaje en modo maximización).
  static GreedyResult solve(List<List<int>> cost, {bool maximize = false}) {
    final n = cost.length;
    final used = List<bool>.filled(n, false);
    final assignment = List<int>.filled(n, -1);
    var total = 0;

    for (var i = 0; i < n; i++) {
      var best = -1;
      for (var j = 0; j < n; j++) {
        if (used[j]) continue;
        if (best == -1 ||
            (maximize
                ? cost[i][j] > cost[i][best]
                : cost[i][j] < cost[i][best])) {
          best = j;
        }
      }
      used[best] = true;
      assignment[i] = best;
      total += cost[i][best];
    }
    return GreedyResult(assignment: assignment, totalCost: total);
  }
}

double _gainPercent(int greedy, int optimal, bool maximize) {
  if (greedy == 0) return 0;
  return maximize
      ? ((optimal - greedy) * 100.0) / greedy
      : ((greedy - optimal) * 100.0) / greedy;
}

double _log10Factorial(int n) {
  var s = 0.0;
  for (var k = 2; k <= n; k++) {
    s += math.log(k) / math.ln10;
  }
  return s;
}

// =====================================================================
// 4. DATOS PRECARGADOS (contexto UCB La Paz)
// =====================================================================
enum DispatchPriority { critical, high, medium, low }

class DispatchTicket {
  const DispatchTicket(this.id, this.title, this.location, this.priority);

  final String id;
  final String title;
  final String location;
  final DispatchPriority priority;

  String get label => '$id · $location';
}

Color _priorityColor(DispatchPriority priority) {
  switch (priority) {
    case DispatchPriority.critical:
      return Brand.coral;
    case DispatchPriority.high:
      return Brand.violet;
    case DispatchPriority.medium:
      return Brand.blue;
    case DispatchPriority.low:
      return Brand.success;
  }
}

String _priorityLabel(DispatchPriority priority) {
  switch (priority) {
    case DispatchPriority.critical:
      return 'Crítica';
    case DispatchPriority.high:
      return 'Alta';
    case DispatchPriority.medium:
      return 'Media';
    case DispatchPriority.low:
      return 'Baja';
  }
}

class CampusPreset {
  static const requests = [
    'Aula D-203 · Proyector',
    'Biblioteca · Red Wi-Fi',
    'Lab. Cómputo 1 · PC',
    'Auditorio · Sonido',
    'Bloque B · Impresora',
    'Lab. Redes · Switch',
  ];

  static const technicians = [
    'Carlos · Redes',
    'Lucía · Hardware',
    'Marco · Audiovisual',
    'Sofía · Generalista',
    'Pablo · Software',
    'Diego · Auxiliar',
  ];

  static const shortTechnicians = [
    'Carlos',
    'Lucía',
    'Marco',
    'Sofía',
    'Pablo',
    'Diego',
  ];

  /// Contexto operativo que convierte la matriz en una orden de trabajo legible.
  static const tickets = <DispatchTicket>[
    DispatchTicket(
      'SD-204',
      'Proyector sin señal',
      'Aula D-203',
      DispatchPriority.high,
    ),
    DispatchTicket(
      'SD-205',
      'Wi-Fi intermitente',
      'Biblioteca',
      DispatchPriority.critical,
    ),
    DispatchTicket(
      'SD-206',
      'Equipo bloqueado',
      'Lab. Cómputo 1',
      DispatchPriority.medium,
    ),
    DispatchTicket(
      'SD-207',
      'Audio para evento',
      'Auditorio',
      DispatchPriority.critical,
    ),
    DispatchTicket(
      'SD-208',
      'Impresora detenida',
      'Bloque B',
      DispatchPriority.low,
    ),
    DispatchTicket(
      'SD-209',
      'Switch sin enlace',
      'Lab. Redes',
      DispatchPriority.high,
    ),
  ];

  /// Minutos estimados (desplazamiento + diagnóstico) de cada técnico a cada solicitud.
  static const costs = <List<int>>[
    [38, 22, 9, 30, 35, 18],
    [10, 27, 34, 21, 16, 29],
    [24, 8, 40, 14, 19, 26],
    [46, 39, 6, 33, 41, 25],
    [28, 15, 31, 12, 22, 9],
    [7, 33, 37, 27, 30, 35],
  ];

  /// Asignación óptima conocida para el caso precargado: fila i -> columna.
  static const optimal = [5, 4, 1, 2, 3, 0];
}

// =====================================================================
// 5. WIDGETS BASE Y ANIMACIONES REUTILIZABLES
// =====================================================================
Widget softCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(22),
}) {
  return Container(
    decoration: BoxDecoration(
      color: Brand.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Brand.grayLight),
      boxShadow: [
        BoxShadow(
          color: Brand.navy.withValues(alpha: 0.07),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    padding: padding,
    child: child,
  );
}

Widget bodyText(String text) => Text(
  text,
  style: const TextStyle(fontSize: 15.5, height: 1.65, color: Brand.grayDark),
);

Widget cardTitle(String text, {IconData? icon}) {
  return Row(
    children: [
      if (icon != null) ...[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Brand.cyanSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Brand.navy, size: 20),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Brand.navy,
          ),
        ),
      ),
    ],
  );
}

/// Eleva ligeramente el contenido al pasar el cursor (escritorio).
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child});
  final Widget child;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

/// Aparece con fundido y desplazamiento la primera vez que entra en pantalla.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child});
  final Widget child;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _shown = false;
  bool _initialized = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_shown || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.92) {
      _position?.removeListener(_check);
      setState(() => _shown = true);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.05),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Contador que sube desde 0 hasta [value].
class _CountUp extends StatelessWidget {
  const _CountUp({
    super.key,
    required this.value,
    this.decimals = 0,
    this.suffix = '',
    this.style,
  });

  final double value;
  final int decimals;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = v.toStringAsFixed(decimals).replaceAll('.', ',');
        return Text('$text$suffix', style: style);
      },
    );
  }
}

class SectionShell extends StatelessWidget {
  const SectionShell({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final int number;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Brand.navy, Brand.navyLight],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Brand.cyan,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: t.headlineMedium?.copyWith(
                    color: Brand.navy,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Text(
              subtitle,
              style: t.bodyLarge?.copyWith(color: Brand.grayMid, height: 1.5),
            ),
          ),
          const SizedBox(height: 30),
          ...children.expand(
            (w) => [Reveal(child: w), const SizedBox(height: 20)],
          ),
        ],
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.width = 250,
  });

  final IconData icon;
  final String title;
  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: HoverLift(
        child: softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Brand.navy, Brand.navyLight],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Brand.cyan),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Brand.navy,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Brand.grayMid,
                  height: 1.55,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.valueWidget,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget valueWidget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: HoverLift(
        child: softCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Brand.grayMid,
                      ),
                    ),
                    const SizedBox(height: 2),
                    valueWidget,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _metricStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w800,
  color: Brand.navy,
);

/// Resumen accionable del resultado: traduce una matriz a una orden de despacho.
class DispatchCommandCenter extends StatelessWidget {
  const DispatchCommandCenter({
    super.key,
    required this.cost,
    required this.hungarian,
    required this.greedy,
    required this.maximize,
  });

  final List<List<int>> cost;
  final HungarianResult hungarian;
  final GreedyResult greedy;
  final bool maximize;

  String get _unit => maximize ? 'pts' : 'min';

  List<DispatchTicket> get _tickets => [
    for (var i = 0; i < cost.length; i++)
      if (i < CampusPreset.tickets.length)
        CampusPreset.tickets[i]
      else
        DispatchTicket(
          'SD-${210 + i}',
          'Solicitud ${i + 1}',
          'Campus UCB',
          DispatchPriority.medium,
        ),
  ];

  String _planText() => [
    'SMARTDISPATCH UCB · PLAN DE DESPACHO',
    'Resultado: ${maximize ? 'máxima idoneidad' : 'mínimo tiempo total'} · ${hungarian.totalCost} $_unit',
    '',
    for (var i = 0; i < cost.length; i++)
      '${_tickets[i].id} | ${_tickets[i].location} → ${CampusPreset.technicians[hungarian.assignment[i]]} · ${cost[i][hungarian.assignment[i]]} $_unit',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final difference = maximize
        ? hungarian.totalCost - greedy.totalCost
        : greedy.totalCost - hungarian.totalCost;
    final critical = _tickets
        .where((ticket) => ticket.priority == DispatchPriority.critical)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.ink, Brand.navy, Brand.navyLight],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Brand.navy.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 600;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar_rounded, color: Brand.cyan, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'CENTRO DE DESPACHO',
                        style: TextStyle(
                          color: Brand.cyanSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Plan de atención listo para ejecutar',
                    style: TextStyle(
                      color: Brand.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$critical ticket${critical == 1 ? '' : 's'} crítico${critical == 1 ? '' : 's'} priorizados · una asignación por técnico',
                    style: const TextStyle(color: Brand.cyanSoft, height: 1.4),
                  ),
                ],
              );
              final action = OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _planText()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Plan de despacho copiado al portapapeles.',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Brand.white,
                  side: const BorderSide(color: Brand.cyan),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: const Text('Copiar plan'),
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [heading, const SizedBox(height: 18), action],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: heading),
                        action,
                      ],
                    );
            },
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                icon: Icons.verified_rounded,
                label: 'Óptimo global',
                value: '${hungarian.totalCost} $_unit',
                color: Brand.success,
              ),
              _StatusPill(
                icon: maximize
                    ? Icons.trending_up_rounded
                    : Icons.timer_outlined,
                label: maximize ? 'Ventaja vs. voraz' : 'Tiempo recuperado',
                value: '${difference.abs()} $_unit',
                color: Brand.cyan,
              ),
              _StatusPill(
                icon: Icons.route_rounded,
                label: 'Decisiones evaluadas',
                value:
                    '${hungarian.iterations} vuelta${hungarian.iterations == 1 ? '' : 's'}',
                color: Brand.violet,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'ORDEN RECOMENDADA',
            style: TextStyle(
              color: Brand.cyanSoft,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < cost.length; i++) ...[
            _DispatchRow(
              ticket: _tickets[i],
              technician: CampusPreset.technicians[hungarian.assignment[i]],
              value: cost[i][hungarian.assignment[i]],
              unit: _unit,
            ),
            if (i != cost.length - 1)
              const Divider(color: Color(0x227DE9F7), height: 1),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Brand.white.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.55)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Brand.cyanSoft, fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Brand.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DispatchRow extends StatelessWidget {
  const _DispatchRow({
    required this.ticket,
    required this.technician,
    required this.value,
    required this.unit,
  });
  final DispatchTicket ticket;
  final String technician;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(ticket.priority);
    final ticketInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ticket.title,
          style: const TextStyle(
            color: Brand.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${ticket.id} · ${ticket.location} · ${_priorityLabel(ticket.priority)}',
          style: const TextStyle(color: Brand.cyanSoft, fontSize: 12),
        ),
      ],
    );
    final technicianInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          technician,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Brand.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '$value $unit',
          style: TextStyle(
            color: Brand.cyan,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final accent = Container(
            width: 4,
            height: constraints.maxWidth < 460 ? 66 : 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
          if (constraints.maxWidth < 460) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                accent,
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ticketInfo,
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Brand.cyan,
                            size: 18,
                          ),
                          const SizedBox(width: 9),
                          Expanded(child: technicianInfo),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              accent,
              const SizedBox(width: 11),
              Expanded(child: ticketInfo),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Brand.cyan,
                size: 18,
              ),
              const SizedBox(width: 10),
              SizedBox(width: 124, child: technicianInfo),
            ],
          );
        },
      ),
    );
  }
}

class MatrixView extends StatelessWidget {
  const MatrixView({
    super.key,
    required this.matrix,
    this.coveredRows,
    this.coveredCols,
  });

  final List<List<int>> matrix;
  final List<bool>? coveredRows;
  final List<bool>? coveredCols;

  @override
  Widget build(BuildContext context) {
    final n = matrix.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (var j = 0; j < n; j++) _cell(i, j)],
          ),
      ],
    );
  }

  Widget _cell(int i, int j) {
    final v = matrix[i][j];
    final rowLine = coveredRows?[i] ?? false;
    final colLine = coveredCols?[j] ?? false;
    Color bg;
    Color fg = Brand.grayDark;
    FontWeight fw = FontWeight.w500;

    if (rowLine && colLine) {
      bg = Brand.cyan;
      fg = Brand.white;
      fw = FontWeight.w800;
    } else if (rowLine || colLine) {
      bg = Brand.amber;
    } else if (v == 0) {
      bg = Brand.cyanSoft;
      fg = Brand.navy;
      fw = FontWeight.w800;
    } else {
      bg = Brand.white;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 42,
      height: 32,
      margin: const EdgeInsets.all(1.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Brand.grayLight),
      ),
      child: Text(
        '$v',
        style: TextStyle(fontSize: 12.5, color: fg, fontWeight: fw),
      ),
    );
  }
}

// =====================================================================
// 6. PINTORES Y FONDOS (CustomPainter)
// =====================================================================

/// Patrón de puntos sutil para dar textura a las secciones.
class DotGridPainter extends CustomPainter {
  DotGridPainter({this.color = Brand.navy});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: 0.07);
    for (var x = 12.0; x < size.width; x += 26) {
      for (var y = 12.0; y < size.height; y += 26) {
        canvas.drawCircle(Offset(x, y), 1.3, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Manchas de color difuminadas que se mueven en el hero.
class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    _blob(
      canvas,
      size,
      0.18 + 0.06 * math.sin(a),
      0.30 + 0.08 * math.cos(a),
      0.30,
      Brand.cyan,
    );
    _blob(
      canvas,
      size,
      0.82 + 0.05 * math.cos(a + 1.3),
      0.65 + 0.08 * math.sin(a + 1.3),
      0.34,
      Brand.blue,
    );
    _blob(
      canvas,
      size,
      0.55 + 0.08 * math.sin(a * 0.7 + 2),
      1.05 - 0.05 * math.cos(a * 0.7),
      0.26,
      Brand.cyanSoft,
    );
  }

  void _blob(Canvas c, Size s, double fx, double fy, double fr, Color color) {
    c.drawCircle(
      Offset(fx * s.width, fy * s.height),
      fr * s.width,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 60),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.t != t;
}

/// Ilustración vectorial del campus: bloques, ventanas y red de conexiones.
class CampusPainter extends CustomPainter {
  CampusPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.navy, Brand.navyLight],
        ).createShader(bounds),
    );

    final rects = [
      Rect.fromLTWH(w * 0.07, h * 0.40, w * 0.16, h * 0.42),
      Rect.fromLTWH(w * 0.28, h * 0.22, w * 0.20, h * 0.60),
      Rect.fromLTWH(w * 0.54, h * 0.46, w * 0.14, h * 0.36),
      Rect.fromLTWH(w * 0.74, h * 0.30, w * 0.19, h * 0.52),
    ];

    final bodyPaint = Paint()..color = const Color(0xFF2A5FA8);
    final windowPaint = Paint()..color = Brand.cyan.withValues(alpha: 0.85);

    for (final r in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        bodyPaint,
      );
      const cols = 3;
      final rows = math.max(2, (r.height / 26).floor());
      final ww = r.width * 0.16;
      const wh = 9.0;
      final gapX = (r.width - cols * ww) / (cols + 1);
      final gapY = (r.height - rows * wh) / (rows + 1);
      for (var c = 0; c < cols; c++) {
        for (var k = 0; k < rows; k++) {
          final x = r.left + gapX * (c + 1) + ww * c;
          final y = r.top + gapY * (k + 1) + wh * k;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, ww, wh),
              const Radius.circular(2),
            ),
            windowPaint,
          );
        }
      }
    }

    canvas.drawLine(
      Offset(w * 0.03, h * 0.84),
      Offset(w * 0.97, h * 0.84),
      Paint()
        ..color = Brand.cyan
        ..strokeWidth = 2,
    );

    final hub = Offset(w * 0.5, h * 0.12);
    final nodes = [for (final r in rects) Offset(r.center.dx, r.top)];
    final linkPaint = Paint()
      ..color = Brand.cyanSoft.withValues(alpha: 0.45)
      ..strokeWidth = 1.4;
    for (final p in nodes) {
      canvas.drawLine(hub, p, linkPaint);
    }

    // Pulso animado en el centro de la red.
    final pulseR = 22 + 10 * math.sin(progress * 2 * math.pi).abs();
    canvas.drawCircle(
      hub,
      pulseR,
      Paint()..color = Brand.cyan.withValues(alpha: 0.18),
    );
    canvas.drawCircle(hub, 9, Paint()..color = Brand.cyan);
    final ring = Paint()
      ..color = Brand.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(hub, 9, ring);
    for (final p in nodes) {
      canvas.drawCircle(p, 6, Paint()..color = Brand.cyan);
      canvas.drawCircle(p, 6, ring);
    }

    final techPaint = Paint()..color = Brand.amber;
    for (final fx in [0.20, 0.45, 0.66, 0.88]) {
      canvas.drawCircle(Offset(w * fx, h * 0.84 - 8), 5, techPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CampusPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Grafo bipartito: solicitudes (izquierda) ↔ técnicos (derecha).
/// [progress] (0..1) dibuja las aristas óptimas de forma escalonada.
class BipartiteGraphPainter extends CustomPainter {
  BipartiteGraphPainter({
    required this.leftLabels,
    required this.rightLabels,
    required this.cost,
    this.assignment,
    this.unit = 'min',
    this.progress = 1,
  });

  final List<String> leftLabels;
  final List<String> rightLabels;
  final List<List<int>> cost;
  final List<int>? assignment;
  final String unit;
  final double progress;

  static const double _boxW = 150;
  static const double _boxH = 42;
  static const double _pad = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final n = leftLabels.length;
    final spacing = n <= 1 ? 0.0 : (size.height - 2 * _pad - _boxH) / (n - 1);
    double topOf(int i) => _pad + i * spacing;

    const leftX = 6.0;
    final rightX = size.width - 6 - _boxW;
    Offset leftAnchor(int i) => Offset(leftX + _boxW, topOf(i) + _boxH / 2);
    Offset rightAnchor(int j) => Offset(rightX, topOf(j) + _boxH / 2);

    Path edgePath(Offset a, Offset b) {
      final mx = (a.dx + b.dx) / 2;
      return Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }

    final faint = Paint()
      ..color = Brand.grayMid.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final active = Paint()
      ..color = Brand.cyan
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (assignment != null && assignment![i] == j) continue;
        canvas.drawPath(edgePath(leftAnchor(i), rightAnchor(j)), faint);
      }
    }

    if (assignment != null) {
      for (var i = 0; i < n; i++) {
        final j = assignment![i];
        final a = leftAnchor(i);
        final b = rightAnchor(j);
        final path = edgePath(a, b);
        final p = (((progress - i * 0.08) / 0.6).clamp(0.0, 1.0)).toDouble();
        if (p <= 0) continue;
        if (p >= 1) {
          canvas.drawPath(path, active);
        } else {
          final metric = path.computeMetrics().first;
          canvas.drawPath(metric.extractPath(0, metric.length * p), active);
        }
        if (p >= 1) {
          final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          _drawLabel(canvas, mid, '${cost[i][j]} $unit');
        }
      }
    }

    for (var i = 0; i < n; i++) {
      _drawBox(
        canvas,
        Rect.fromLTWH(leftX, topOf(i), _boxW, _boxH),
        leftLabels[i],
        Brand.navy,
        Brand.white,
        null,
      );
    }
    for (var j = 0; j < n; j++) {
      _drawBox(
        canvas,
        Rect.fromLTWH(rightX, topOf(j), _boxW, _boxH),
        rightLabels[j],
        Brand.cyanSoft,
        Brand.navy,
        Brand.cyan,
      );
    }
  }

  void _drawBox(
    Canvas canvas,
    Rect rect,
    String text,
    Color fill,
    Color textColor,
    Color? border,
  ) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = fill);
    if (border != null) {
      canvas.drawRRect(
        rr,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 12);
    tp.paint(canvas, Offset(rect.left + 6, rect.center.dy - tp.height / 2));
  }

  void _drawLabel(Canvas canvas, Offset center, String label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Brand.navy,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 12,
        height: tp.height + 6,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(rr, Paint()..color = Brand.white);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Brand.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BipartiteGraphPainter oldDelegate) => true;
}

// =====================================================================
// 7. PÁGINA PRINCIPAL, NAVEGACIÓN Y SCROLL
// =====================================================================
class NavItem {
  NavItem(this.title, this.icon) : key = GlobalKey();
  final String title;
  final IconData icon;
  final GlobalKey key;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();
  final List<NavItem> _sections = [
    NavItem('Introducción', Icons.apartment_rounded),
    NavItem('Problema', Icons.psychology_alt_rounded),
    NavItem('Objetivo', Icons.flag_rounded),
    NavItem('Marco teórico', Icons.menu_book_rounded),
    NavItem('Simulador', Icons.hub_rounded),
    NavItem('Conclusión', Icons.emoji_events_rounded),
  ];

  int _active = 0;
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Determina qué sección está activa según la posición de su encabezado.
  void _onScroll() {
    var idx = 0;
    for (var i = 0; i < _sections.length; i++) {
      final box = _sections[i].key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= 180) idx = i;
    }
    final show = _scroll.hasClients && _scroll.offset > 600;
    if (idx != _active || show != _showTop) {
      setState(() {
        _active = idx;
        _showTop = show;
      });
    }
  }

  void _goTo(NavItem item) {
    final ctx = item.key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 960;
    final contentWidth = math.min(1120.0, size.width);

    final pages = <Widget>[
      IntroSection(
        onExplore: () => _goTo(_sections[4]),
        onProblem: () => _goTo(_sections[1]),
      ),
      const ProblemSection(),
      const ObjectiveSection(),
      const TheorySection(),
      const SimulatorSection(),
      const ConclusionSection(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            Icon(Icons.hub_rounded, color: Brand.cyan),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'SmartDispatch UCB',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        actions: wide
            ? [
                for (var i = 0; i < _sections.length; i++)
                  _NavButton(
                    label: _sections[i].title,
                    active: i == _active,
                    onTap: () => _goTo(_sections[i]),
                  ),
                const SizedBox(width: 12),
              ]
            : null,
      ),
      drawer: wide
          ? null
          : Drawer(
              child: ListView(
                children: [
                  const DrawerHeader(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Brand.navy, Brand.navyLight],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'SmartDispatch UCB',
                        style: TextStyle(
                          color: Brand.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < _sections.length; i++)
                    ListTile(
                      selected: i == _active,
                      selectedColor: Brand.navy,
                      leading: Icon(_sections[i].icon, color: Brand.navy),
                      title: Text(_sections[i].title),
                      onTap: () {
                        Navigator.of(context).pop();
                        _goTo(_sections[i]);
                      },
                    ),
                ],
              ),
            ),
      floatingActionButton: AnimatedScale(
        scale: _showTop ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: FloatingActionButton.small(
          backgroundColor: Brand.navy,
          foregroundColor: Brand.cyan,
          tooltip: 'Volver arriba',
          onPressed: () => _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
          ),
          child: const Icon(Icons.arrow_upward_rounded),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: [
            for (var i = 0; i < pages.length; i++)
              Container(
                key: _sections[i].key,
                width: double.infinity,
                color: i.isEven ? Brand.canvas : Brand.white,
                child: i == 0
                    ? pages[0]
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(painter: DotGridPainter()),
                            ),
                          ),
                          Center(
                            child: SizedBox(
                              width: contentWidth,
                              child: pages[i],
                            ),
                          ),
                        ],
                      ),
              ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? Brand.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Brand.cyan : Brand.white.withValues(alpha: 0.85),
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Brand.navy,
      padding: const EdgeInsets.all(28),
      child: const Column(
        children: [
          Text(
            'SmartDispatch UCB · Universidad Católica Boliviana, Sede La Paz',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.white, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Investigación de Operaciones · Método Húngaro (Problema de Asignación)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.cyanSoft, fontSize: 12.5),
          ),
          SizedBox(height: 14),
          Divider(color: Color(0x33CAF0F8), height: 1),
          SizedBox(height: 14),
          Text(
            'Desarrollado por Jesus Ademar Canqui Tintaya',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Brand.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 8. SECCIÓN 1: INTRODUCCIÓN (hero animado)
// =====================================================================
class IntroSection extends StatelessWidget {
  const IntroSection({
    super.key,
    required this.onExplore,
    required this.onProblem,
  });
  final VoidCallback onExplore;
  final VoidCallback onProblem;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(onExplore: onExplore, onProblem: onProblem),
        Center(
          child: SizedBox(
            width: math.min(1120.0, w),
            child: SectionShell(
              number: 1,
              title: 'Introducción',
              subtitle: 'Contexto operativo del soporte técnico y de los laboratorios en la UCB La Paz',
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(seconds: 4),
                      curve: Curves.easeInOut,
                      builder: (context, p, _) =>
                          CustomPaint(painter: CampusPainter(p)),
                      onEnd: () {},
                    ),
                  ),
                ),
                bodyText(
                  'La Universidad Católica Boliviana (UCB), Sede La Paz, opera múltiples bloques, aulas, '
                  'laboratorios de cómputo, la biblioteca y el auditorio. Cada día, el área de soporte técnico '
                  'recibe incidencias al mismo tiempo: un proyector que no enciende en el Bloque D, una red Wi-Fi '
                  'caída en la biblioteca, equipos bloqueados en un laboratorio o un sistema de sonido que falla '
                  'antes de un evento.',
                ),
                bodyText(
                  'La asignación de técnicos a estas incidencias suele hacerse a mano, por intuición o por orden '
                  'de llegada. Eso genera cuellos de botella: el técnico más cercano queda ocupado con una tarea '
                  'menor mientras una urgencia espera, los desplazamientos se repiten entre bloques y la carga de '
                  'trabajo queda desbalanceada.',
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: const [
                    FeatureTile(
                      icon: Icons.schedule_rounded,
                      title: 'Decisiones lentas',
                      text: 'Asignar a ojo consume tiempo en horas pico, justo cuando más incidencias llegan.',
                    ),
                    FeatureTile(
                      icon: Icons.visibility_off_rounded,
                      title: 'Visión parcial',
                      text: 'Nadie ve a la vez la ubicación, la carga y la especialidad de todos los técnicos.',
                    ),
                    FeatureTile(
                      icon: Icons.route_rounded,
                      title: 'Desplazamientos extra',
                      text: 'Cruzar el campus varias veces reduce la productividad de cada técnico.',
                    ),
                    FeatureTile(
                      icon: Icons.balance_rounded,
                      title: 'Carga desbalanceada',
                      text: 'Unos técnicos se saturan mientras otros esperan sin atender solicitudes.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.onExplore, required this.onProblem});
  final VoidCallback onExplore;
  final VoidCallback onProblem;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with TickerProviderStateMixin {
  late final AnimationController _blob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _blob.dispose();
    _enter.dispose();
    super.dispose();
  }

  /// Entrada escalonada: fundido + desplazamiento en un intervalo de la animación.
  Widget _rise(double start, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final titleSize = w < 600 ? 38.0 : 58.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.navy, Brand.navyLight],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _blob,
              builder: (context, child) =>
                  CustomPaint(painter: _BlobPainter(_blob.value)),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: DotGridPainter(color: Brand.white)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 88, 24, 88),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rise(
                      0.0,
                      0.4,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Brand.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Brand.cyan.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'UNIVERSIDAD CATÓLICA BOLIVIANA · SEDE LA PAZ',
                          style: TextStyle(
                            color: Brand.cyanSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _rise(
                      0.1,
                      0.55,
                      ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          colors: [Brand.white, Brand.cyanSoft, Brand.cyan],
                        ).createShader(rect),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          'SmartDispatch UCB',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                            height: 1.02,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _rise(
                      0.2,
                      0.65,
                      const Text(
                        'Asignación óptima de soporte técnico y recursos con el Método Húngaro, '
                        'para atender cada incidencia del campus en el menor tiempo posible.',
                        style: TextStyle(
                          color: Brand.cyanSoft,
                          fontSize: 19,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _rise(
                      0.3,
                      0.75,
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: widget.onExplore,
                            style: FilledButton.styleFrom(
                              backgroundColor: Brand.cyan,
                              foregroundColor: Brand.navy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text(
                              'Explorar el simulador',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onProblem,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Brand.white,
                              side: BorderSide(
                                color: Brand.white.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                            ),
                            icon: const Icon(Icons.help_outline_rounded),
                            label: const Text('Entender el problema'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    _rise(
                      0.45,
                      1.0,
                      Wrap(
                        spacing: 40,
                        runSpacing: 22,
                        children: const [
                          _Kpi(
                            value: 6,
                            label: 'técnicos y solicitudes en la matriz',
                          ),
                          _Kpi(
                            value: 720,
                            label: 'combinaciones de fuerza bruta (n = 6)',
                          ),
                          _Kpi(
                            value: 28.7,
                            decimals: 1,
                            suffix: ' %',
                            label: 'ahorro en el caso precargado',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.value,
    required this.label,
    this.decimals = 0,
    this.suffix = '',
  });

  final double value;
  final String label;
  final int decimals;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountUp(
          value: value,
          decimals: decimals,
          suffix: suffix,
          style: const TextStyle(
            color: Brand.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Brand.cyanSoft, fontSize: 13),
        ),
      ],
    );
  }
}

// =====================================================================
// 9. SECCIÓN 2: DEFINICIÓN DEL PROBLEMA (con explorador de matriz)
// =====================================================================
class ProblemSection extends StatelessWidget {
  const ProblemSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      number: 2,
      title: 'Definición del problema',
      subtitle: 'Varias incidencias a la vez en distintos bloques, y técnicos con ubicación, carga y especialidad distintas',
      children: [
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle('1. El escenario', icon: Icons.location_city_rounded),
              const SizedBox(height: 14),
              bodyText(
                'Imagine una mañana de semana. En pocos minutos llegan seis solicitudes de soporte: un proyector '
                'en el Aula D-203, la red Wi-Fi de la Biblioteca, un equipo bloqueado en el Laboratorio de '
                'Cómputo 1, el sonido del Auditorio, una impresora en el Bloque B y un switch caído en el '
                'Laboratorio de Redes.',
              ),
              const SizedBox(height: 10),
              bodyText(
                'En ese mismo momento hay seis técnicos disponibles. Cada uno está en un punto distinto del campus, '
                'tiene una especialidad diferente y una carga de trabajo propia. Ninguno puede atender dos '
                'solicitudes a la vez.',
              ),
            ],
          ),
        ),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle(
                '2. ¿Qué problema hay que resolver?',
                icon: Icons.help_outline_rounded,
              ),
              const SizedBox(height: 14),
              bodyText(
                'La pregunta es: ¿qué técnico debe atender cada solicitud para que el tiempo total de atención '
                'sea el menor posible? Para responderla hay tres reglas:',
              ),
              const SizedBox(height: 12),
              const _Rule(
                n: '1',
                text: 'Cada solicitud se asigna a exactamente un técnico.',
              ),
              const _Rule(
                n: '2',
                text: 'Cada técnico atiende exactamente una solicitud en este ciclo.',
              ),
              const _Rule(
                n: '3',
                text: 'El objetivo es minimizar la suma de los tiempos de todas las asignaciones.',
              ),
              const SizedBox(height: 10),
              bodyText(
                'Esto es un problema de asignación: hay dos conjuntos (solicitudes y técnicos) y un costo asociado '
                'a cada pareja solicitud–técnico. Cuando el número de solicitudes y de técnicos es igual, '
                'cada técnico queda emparejado con una única solicitud.',
              ),
            ],
          ),
        ),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle(
                '3. De la realidad a una matriz de costos',
                icon: Icons.grid_on_rounded,
              ),
              const SizedBox(height: 14),
              bodyText(
                'Cada celda de la matriz responde una pregunta concreta: ¿cuántos minutos tardaría ese técnico en '
                'resolver esa solicitud? El valor incluye el desplazamiento hasta el bloque y el tiempo estimado de '
                'diagnóstico, que depende de la especialidad.',
              ),
              const SizedBox(height: 10),
              bodyText(
                'Por ejemplo, Lucía (Hardware) necesita 8 minutos para el Laboratorio de Cómputo 1: está cerca y su '
                'especialidad coincide con la falla. En cambio, Diego (Auxiliar) necesita 40 minutos para la misma '
                'solicitud, porque debe escalar el caso y recorrer más distancia.',
              ),
              const SizedBox(height: 16),
              const _MatrixExplorer(),
            ],
          ),
        ),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle(
                '4. Formulación matemática',
                icon: Icons.functions_rounded,
              ),
              const SizedBox(height: 14),
              bodyText(
                'Sea C = [cᵢⱼ] la matriz n × n, donde cᵢⱼ son los minutos que tardaría el técnico j en atender la '
                'solicitud i. Se define una variable de decisión binaria xᵢⱼ: vale 1 si el técnico j atiende la '
                'solicitud i, y 0 en otro caso.',
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Brand.navy, Brand.navyLight],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SelectableText(
                  'min  Z = Σᵢ Σⱼ cᵢⱼ · xᵢⱼ\n'
                  '\n'
                  'sujeto a:\n'
                  '  Σⱼ xᵢⱼ = 1      ∀ i   (cada solicitud se atiende una vez)\n'
                  '  Σᵢ xᵢⱼ = 1      ∀ j   (cada técnico atiende una sola solicitud)\n'
                  '  xᵢⱼ ∈ {0, 1}',
                  style: TextStyle(
                    color: Brand.cyanSoft,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              bodyText(
                'Leído en palabras: Z es el tiempo total del conjunto de atenciones. Cada suma de filas igual a 1 '
                'garantiza que ninguna solicitud quede sin atender ni repetida; cada suma de columnas igual a 1 '
                'garantiza que ningún técnico tenga dos tareas a la vez.',
              ),
              const SizedBox(height: 10),
              bodyText(
                'La dificultad está en la cantidad de combinaciones. Con 6 técnicos hay 6! = 720 formas posibles de '
                'asignar; con 20 solicitudes hay más de 2 × 10¹⁸. Revisarlas todas no es viable, y por eso se '
                'necesita un algoritmo eficiente.',
              ),
            ],
          ),
        ),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle(
                '5. ¿Por qué no basta asignar al técnico más cercano?',
                icon: Icons.lightbulb_outline_rounded,
              ),
              const SizedBox(height: 14),
              bodyText(
                'La estrategia voraz (greedy) atiende las solicitudes en orden y, para cada una, toma el técnico más '
                'barato que quede libre. Parece razonable, pero cada decisión local ignora cómo afecta a las demás. '
                'Con los datos del caso precargado:',
              ),
              const SizedBox(height: 14),
              const _GreedyVsOptimalTable(),
              const SizedBox(height: 14),
              bodyText(
                'La voraz asigna primero a Marco al Aula D-203 (9 min), que es lo mejor para esa solicitud. Pero '
                'Marco era también la opción más barata para el Auditorio (6 min), y al quitarlo de ahí, el Auditorio '
                'termina con Diego (25 min). El método húngaro considera el conjunto completo y reorganiza las '
                'asignaciones: el total baja de 94 a 67 minutos, un ahorro de 27 minutos (≈ 28,7 %).',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Matriz interactiva: toca un técnico, una solicitud o una celda para explorar.
class _MatrixExplorer extends StatefulWidget {
  const _MatrixExplorer();

  @override
  State<_MatrixExplorer> createState() => _MatrixExplorerState();
}

class _MatrixExplorerState extends State<_MatrixExplorer> {
  int? _r;
  int? _c;

  void _tapRow(int i) => setState(() => _r = _r == i ? null : i);
  void _tapCol(int j) => setState(() => _c = _c == j ? null : j);
  void _tapCell(int i, int j) => setState(() {
    _r = i;
    _c = j;
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 190,
                    height: 52,
                    child: Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Solicitud ↓   Técnico →',
                          style: TextStyle(fontSize: 12, color: Brand.grayMid),
                        ),
                      ),
                    ),
                  ),
                  for (var j = 0; j < 6; j++) _headerCell(j),
                ],
              ),
              for (var i = 0; i < 6; i++)
                Row(
                  children: [
                    _rowHeader(i),
                    for (var j = 0; j < 6; j++) _cell(i, j),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _infoPanel(),
      ],
    );
  }

  Widget _headerCell(int j) {
    final sel = _c == j;
    return GestureDetector(
      onTap: () => _tapCol(j),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 74,
        height: 52,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? Brand.navy : Brand.cyanSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          CampusPreset.shortTechnicians[j],
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: sel ? Brand.white : Brand.navy,
          ),
        ),
      ),
    );
  }

  Widget _rowHeader(int i) {
    final sel = _r == i;
    return GestureDetector(
      onTap: () => _tapRow(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 190,
        height: 52,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: sel ? Brand.navy : Brand.grayLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          CampusPreset.requests[i],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: sel ? Brand.white : Brand.grayDark,
          ),
        ),
      ),
    );
  }

  Widget _cell(int i, int j) {
    final v = CampusPreset.costs[i][j];
    final isOpt = CampusPreset.optimal[i] == j;
    final inLine = _r == i || _c == j;
    final picked = _r == i && _c == j;

    Color bg = isOpt
        ? Brand.cyan
        : (inLine ? Brand.cyanSoft.withValues(alpha: 0.7) : Brand.white);
    if (picked) bg = Brand.navy;
    final fg = (isOpt || picked) ? Brand.white : Brand.grayDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _tapCell(i, j),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 74,
          height: 52,
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Brand.grayLight),
          ),
          child: Text(
            '$v',
            style: TextStyle(
              fontWeight: (isOpt || picked) ? FontWeight.w800 : FontWeight.w500,
              color: fg,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPanel() {
    final cost = CampusPreset.costs;
    final shortT = CampusPreset.shortTechnicians;
    final reqs = CampusPreset.requests;
    String text;
    IconData icon;

    if (_r != null && _c != null) {
      final i = _r!;
      final j = _c!;
      final v = cost[i][j];
      final rank = 1 + cost[i].where((x) => x < v).length;
      final isOpt = CampusPreset.optimal[i] == j;
      text =
          '${shortT[j]} atiende «${reqs[i]}» en $v min. Es la opción #$rank de 6 más rápidas para esta '
          'solicitud. ${isOpt ? 'Esta pareja forma parte de la asignación óptima.' : 'No es la pareja óptima: el método húngaro la descarta al evaluar el conjunto completo.'}';
      icon = isOpt ? Icons.check_circle_rounded : Icons.info_outline_rounded;
    } else if (_r != null) {
      final i = _r!;
      final row = cost[i];
      final best = row.reduce((a, b) => math.min(a, b));
      final bj = row.indexOf(best);
      text =
          'Para «${reqs[i]}», el técnico más rápido es ${shortT[bj]} ($best min). '
          'Pero ese técnico podría estar ocupado con otra solicitud: por eso hay que mirar el conjunto.';
      icon = Icons.touch_app_rounded;
    } else if (_c != null) {
      final j = _c!;
      final col = [for (var i = 0; i < 6; i++) cost[i][j]];
      final best = col.reduce((a, b) => math.min(a, b));
      final bi = col.indexOf(best);
      text =
          '${shortT[j]} es más rápido en «${reqs[bi]}» ($best min). Toca una solicitud para comparar.';
      icon = Icons.touch_app_rounded;
    } else {
      text =
          'Toca un técnico, una solicitud o una celda para explorar los costos. '
          'Las celdas cian son la asignación óptima.';
      icon = Icons.touch_app_rounded;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(text),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Brand.cyanSoft.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Brand.cyan.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Brand.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Brand.grayDark,
                  height: 1.55,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Brand.cyan,
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                color: Brand.navy,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: bodyText(text)),
        ],
      ),
    );
  }
}

/// Comparación concreta: asignación voraz frente a la óptima.
class _GreedyVsOptimalTable extends StatelessWidget {
  const _GreedyVsOptimalTable();

  static const _rows = <List<String>>[
    ['Aula D-203 · Proyector', 'Marco · 9 min', 'Diego · 18 min'],
    ['Biblioteca · Red Wi-Fi', 'Carlos · 10 min', 'Pablo · 16 min'],
    ['Lab. Cómputo 1 · PC', 'Lucía · 8 min', 'Lucía · 8 min'],
    ['Auditorio · Sonido', 'Diego · 25 min', 'Marco · 6 min'],
    ['Bloque B · Impresora', 'Sofía · 12 min', 'Sofía · 12 min'],
    ['Lab. Redes · Switch', 'Pablo · 30 min', 'Carlos · 7 min'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 42,
            columnSpacing: 26,
            columns: const [
              DataColumn(label: Text('Solicitud')),
              DataColumn(label: Text('Voraz (orden de llegada)')),
              DataColumn(label: Text('Óptimo (húngaro)')),
            ],
            rows: [
              for (final r in _rows)
                DataRow(
                  cells: [
                    DataCell(Text(r[0])),
                    DataCell(
                      Text(r[1], style: const TextStyle(color: Brand.grayMid)),
                    ),
                    DataCell(
                      Text(
                        r[2],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Brand.success,
                        ),
                      ),
                    ),
                  ],
                ),
              const DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  DataCell(
                    Text(
                      '94 min',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  DataCell(
                    Text(
                      '67 min',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Brand.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _MiniStat(
              label: 'Voraz',
              value: 94,
              suffix: ' min',
              color: Brand.grayMid,
              icon: Icons.swap_horiz_rounded,
            ),
            _MiniStat(
              label: 'Húngaro',
              value: 67,
              suffix: ' min',
              color: Brand.success,
              icon: Icons.verified_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final String suffix;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Brand.grayMid, fontSize: 13),
                ),
                _CountUp(
                  key: ValueKey('$label-$value'),
                  value: value,
                  suffix: suffix,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 10. SECCIÓN 3: OBJETIVO GENERAL
// =====================================================================
class ObjectiveSection extends StatelessWidget {
  const ObjectiveSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      number: 3,
      title: 'Objetivo general',
      subtitle: 'Optimizar la asignación global de recursos en tiempo real',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Brand.navy, Brand.navyLight],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'Optimizar, en tiempo real, la asignación global de los técnicos de soporte a las solicitudes del '
            'campus de la UCB La Paz, mediante el algoritmo de asignación (Método Húngaro), con el fin de '
            'minimizar el tiempo total de atención y balancear la carga del equipo, frente al enfoque manual o '
            'voraz que decide solicitud por solicitud sin considerar el conjunto.',
            style: TextStyle(fontSize: 17, height: 1.7, color: Brand.white),
          ),
        ),
        softCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CheckItem(
                text: 'Minimizar el tiempo total de atención de todas las solicitudes simultáneas.',
              ),
              SizedBox(height: 12),
              _CheckItem(
                text: 'Garantizar una asignación uno a uno: ningún técnico queda con dos tareas a la vez.',
              ),
              SizedBox(height: 12),
              _CheckItem(
                text: 'Ofrecer una herramienta visual que sustente la decisión del coordinador.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, color: Brand.success),
        const SizedBox(width: 10),
        Expanded(child: bodyText(text)),
      ],
    );
  }
}

// =====================================================================
// 11. SECCIÓN 4: MARCO TEÓRICO
// =====================================================================
class TheorySection extends StatelessWidget {
  const TheorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      number: 4,
      title: 'Marco teórico',
      subtitle: 'Grafos bipartitos, emparejamiento óptimo y Método Húngaro',
      children: [
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle(
                'Grafo bipartito ponderado',
                icon: Icons.account_tree_outlined,
              ),
              const SizedBox(height: 10),
              bodyText(
                'Un grafo bipartito tiene dos conjuntos de vértices disjuntos (aquí, solicitudes y técnicos) y '
                'aristas que sólo unen vértices de conjuntos distintos. Cada arista lleva un peso: el costo de que '
                'ese técnico atienda esa solicitud.',
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: 300,
                  width: math.max(520, MediaQuery.sizeOf(context).width - 96),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1800),
                    curve: Curves.easeInOut,
                    builder: (context, p, _) => CustomPaint(
                      painter: BipartiteGraphPainter(
                        leftLabels: const [
                          'Solicitud A',
                          'Solicitud B',
                          'Solicitud C',
                        ],
                        rightLabels: const [
                          'Técnico 1',
                          'Técnico 2',
                          'Técnico 3',
                        ],
                        cost: const [
                          [9, 2, 7],
                          [6, 4, 3],
                          [5, 8, 1],
                        ],
                        assignment: const [1, 0, 2],
                        unit: 'min',
                        progress: p,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ejemplo 3 × 3: las aristas cian forman un emparejamiento perfecto de costo mínimo (9 min).',
                style: TextStyle(fontSize: 13, color: Brand.grayMid),
              ),
            ],
          ),
        ),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle(
                'Emparejamiento óptimo (matching)',
                icon: Icons.link_rounded,
              ),
              const SizedBox(height: 10),
              bodyText(
                'Un emparejamiento es un conjunto de aristas sin vértices compartidos. Es perfecto cuando todos los '
                'vértices quedan cubiertos. El emparejamiento óptimo es el perfecto de menor costo total (o de mayor '
                'beneficio, en maximización).',
              ),
              const SizedBox(height: 10),
              bodyText(
                'Existe una relación fundamental: el número mínimo de líneas que cubren todos los ceros de la matriz '
                'reducida es igual al mayor número de ceros que pueden elegirse sin compartir fila ni columna '
                '(teorema de König). Esa idea es la base del Método Húngaro.',
              ),
            ],
          ),
        ),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Pasos del Método Húngaro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Brand.navy,
                ),
              ),
              SizedBox(height: 16),
              _NumberedStep(
                number: 1,
                title: 'Reducción de filas',
                text: 'Se resta el mínimo de cada fila; aparece al menos un cero por fila.',
              ),
              _NumberedStep(
                number: 2,
                title: 'Reducción de columnas',
                text: 'Se resta el mínimo de cada columna; aparece al menos un cero por columna.',
              ),
              _NumberedStep(
                number: 3,
                title: 'Recubrimiento de ceros mínimos',
                text: 'Se buscan asignaciones independientes de ceros y se cubren con el menor número de líneas.',
              ),
              _NumberedStep(
                number: 4,
                title: 'Ajuste de la matriz',
                text: 'Si hacen falta líneas, se toma el mínimo no cubierto, se resta y se suma según corresponda. Se repite hasta tener n líneas.',
              ),
            ],
          ),
        ),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle(
                'Por qué O(n³) es tan poderosa',
                icon: Icons.speed_rounded,
              ),
              const SizedBox(height: 8),
              const Text(
                'Escala logarítmica: cada barra muestra el orden de magnitud del número de operaciones.',
                style: TextStyle(fontSize: 13, color: Brand.grayMid),
              ),
              const SizedBox(height: 18),
              const _GrowthChart(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gráfica de crecimiento: O(n³) frente a O(n!), con escala logarítmica.
class _GrowthChart extends StatelessWidget {
  const _GrowthChart();

  static const _ns = [6, 10, 15, 20];
  static const _maxLog = 19.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final n in _ns)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    'n = $n',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Brand.navy,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _bar(
                        'O(n³)',
                        math.log(n * n * n) / math.ln10 / _maxLog,
                        Brand.success,
                        '${n * n * n} ops',
                        n,
                      ),
                      const SizedBox(height: 6),
                      _bar(
                        'O(n!)',
                        _log10Factorial(n) / _maxLog,
                        Brand.navy,
                        _factLabel(n),
                        n + 100,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _factLabel(int n) {
    switch (n) {
      case 6:
        return '720';
      case 10:
        return '3.628.800';
      case 15:
        return '1,3 × 10¹²';
      default:
        return '2,4 × 10¹⁸';
    }
  }

  Widget _bar(
    String label,
    double fraction,
    Color color,
    String valueText,
    int key,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Brand.grayMid),
          ),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            key: ValueKey('$label-$key'),
            tween: Tween<double>(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 14,
                color: color,
                backgroundColor: Brand.grayLight,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 118,
          child: Text(
            valueText,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.title,
    required this.text,
  });

  final int number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Brand.cyan,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Brand.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Brand.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(color: Brand.grayDark, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 12. SECCIÓN 5: SIMULADOR EN VIVO (con reproductor de pasos)
// =====================================================================
class SimulatorSection extends StatefulWidget {
  const SimulatorSection({super.key});

  @override
  State<SimulatorSection> createState() => _SimulatorSectionState();
}

class _SimulatorSectionState extends State<SimulatorSection> {
  int _n = 6;
  bool _maximize = false;
  bool _lastMaximize = false;
  late List<List<TextEditingController>> _ctrl;
  HungarianResult? _hungarian;
  GreedyResult? _greedy;
  List<List<int>>? _lastCost;
  String? _error;

  int _runId = 0; // cambia en cada ejecución: reinicia las animaciones
  int _stepIdx = 0;
  bool _playing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final preset = CampusPreset.costs.map((r) => List<int>.from(r)).toList();
    _ctrl = _makeControllers(preset);
    _n = _ctrl.length;
    // Al llegar al simulador ya hay un plan real para inspeccionar y comparar.
    _lastCost = preset;
    _hungarian = HungarianSolver.solve(preset);
    _greedy = GreedySolver.solve(preset);
    _runId = 1;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposeControllers(_ctrl);
    super.dispose();
  }

  // ----- Controladores de texto -----
  static List<List<TextEditingController>> _makeControllers(
    List<List<int>> values,
  ) => [
    for (final row in values)
      [for (final x in row) TextEditingController(text: '$x')],
  ];

  static void _disposeControllers(List<List<TextEditingController>> c) {
    for (final row in c) {
      for (final ctrl in row) {
        ctrl.dispose();
      }
    }
  }

  void _setControllers(List<List<int>> values) {
    final old = _ctrl;
    _stopTimer();
    setState(() {
      _ctrl = _makeControllers(values);
      _n = values.length;
      _hungarian = null;
      _greedy = null;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _disposeControllers(old),
    );
  }

  List<List<int>>? _readStrict() {
    final out = <List<int>>[];
    for (final row in _ctrl) {
      final r = <int>[];
      for (final c in row) {
        final v = int.tryParse(c.text.trim());
        if (v == null || v < 0) return null;
        r.add(v);
      }
      out.add(r);
    }
    return out;
  }

  List<List<int>> _readLenient() => [
    for (final row in _ctrl)
      [for (final c in row) math.max(0, int.tryParse(c.text.trim()) ?? 10)],
  ];

  int _randomCost() => 5 + _rng.nextInt(56);

  // ----- Acciones -----
  void _loadPreset() {
    _setControllers(CampusPreset.costs.map((r) => List<int>.from(r)).toList());
  }

  void _randomize() {
    _setControllers([
      for (var i = 0; i < _n; i++) [for (var j = 0; j < _n; j++) _randomCost()],
    ]);
  }

  void _resize(double value) {
    final n = value.round();
    if (n == _n) return;
    final old = _readLenient();
    final values = [
      for (var i = 0; i < n; i++)
        [
          for (var j = 0; j < n; j++)
            i < old.length && j < old.length ? old[i][j] : _randomCost(),
        ],
    ];
    _setControllers(values);
  }

  void _run() {
    final cost = _readStrict();
    if (cost == null) {
      setState(
        () => _error = 'Revisa la matriz: todos los valores deben ser enteros no negativos.',
      );
      return;
    }
    _stopTimer();
    setState(() {
      _error = null;
      _lastCost = cost;
      _lastMaximize = _maximize;
      _hungarian = HungarianSolver.solve(cost, maximize: _maximize);
      _greedy = GreedySolver.solve(cost, maximize: _maximize);
      _runId++;
      _stepIdx = 0;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _playing = false;
  }

  void _togglePlay() {
    final h = _hungarian;
    if (h == null) return;
    if (_playing) {
      setState(_stopTimer);
      return;
    }
    final last = h.steps.length - 1;
    setState(() {
      if (_stepIdx >= last) _stepIdx = 0;
      _playing = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 1300), (t) {
      if (!mounted) return;
      if (_stepIdx >= last) {
        setState(_stopTimer);
        return;
      }
      setState(() => _stepIdx++);
    });
  }

  // ----- Interfaz -----
  @override
  Widget build(BuildContext context) {
    final h = _hungarian;
    final g = _greedy;
    final cost = _lastCost;

    return SectionShell(
      number: 5,
      title: 'Aplicación interactiva · simulador en vivo',
      subtitle: 'Edita la matriz, cambia el tamaño y ejecuta el Método Húngaro frente a una asignación voraz',
      children: [
        softCard(child: _controls()),
        softCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardTitle('Matriz de costos', icon: Icons.grid_on_rounded),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  _maximize
                      ? 'Valores = puntaje de idoneidad (más alto, mejor).'
                      : 'Valores = minutos estimados (desplazamiento + diagnóstico).',
                  style: const TextStyle(color: Brand.grayMid),
                ),
              ),
              const SizedBox(height: 14),
              _matrixEditor(),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Ejecutar algoritmo'),
                ),
              ),
            ],
          ),
        ),
        if (h != null && g != null && cost != null)
          ..._resultWidgets(h, g, cost),
      ],
    );
  }

  Widget _controls() {
    return Wrap(
      spacing: 20,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tamaño de la matriz: $_n × $_n',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Brand.navy,
                ),
              ),
              Slider(
                value: _n.toDouble(),
                min: 3,
                max: 6,
                divisions: 3,
                label: '$_n × $_n',
                onChanged: _resize,
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _loadPreset,
          icon: const Icon(Icons.school_rounded),
          label: const Text('Caso UCB La Paz'),
        ),
        OutlinedButton.icon(
          onPressed: _randomize,
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Escenario aleatorio'),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Minimizar tiempo'),
              icon: Icon(Icons.timer_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Maximizar idoneidad'),
              icon: Icon(Icons.star_outline_rounded),
            ),
          ],
          selected: {_maximize},
          onSelectionChanged: (s) {
            _stopTimer();
            setState(() {
              _maximize = s.first;
              _hungarian = null;
              _greedy = null;
            });
          },
        ),
      ],
    );
  }

  Widget _matrixEditor() {
    const labelW = 170.0;
    const cellW = 92.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: labelW),
              for (var j = 0; j < _n; j++)
                SizedBox(
                  width: cellW,
                  height: 44,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        CampusPreset.technicians[j],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.navy,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var i = 0; i < _n; i++)
            Row(
              children: [
                SizedBox(
                  width: labelW,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      CampusPreset.requests[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Brand.grayDark,
                      ),
                    ),
                  ),
                ),
                for (var j = 0; j < _n; j++)
                  SizedBox(
                    width: cellW,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextField(
                        controller: _ctrl[i][j],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _resultWidgets(
    HungarianResult h,
    GreedyResult g,
    List<List<int>> cost,
  ) {
    final n = cost.length;
    final unit = _lastMaximize ? 'pts' : 'min';
    final gain = _gainPercent(g.totalCost, h.totalCost, _lastMaximize);
    final maxBar = math.max(h.totalCost, g.totalCost);
    final k = _runId;

    return [
      DispatchCommandCenter(
        cost: cost,
        hungarian: h,
        greedy: g,
        maximize: _lastMaximize,
      ),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _MetricTile(
            icon: Icons.verified_rounded,
            color: Brand.success,
            label: 'Valor óptimo (húngaro)',
            valueWidget: _CountUp(
              key: ValueKey('h$k'),
              value: h.totalCost.toDouble(),
              suffix: ' $unit',
              style: _metricStyle,
            ),
          ),
          _MetricTile(
            icon: Icons.swap_horiz_rounded,
            color: Brand.grayMid,
            label: 'Valor voraz (ingenuo)',
            valueWidget: _CountUp(
              key: ValueKey('g$k'),
              value: g.totalCost.toDouble(),
              suffix: ' $unit',
              style: _metricStyle,
            ),
          ),
          _MetricTile(
            icon: Icons.trending_up_rounded,
            color: Brand.navyLight,
            label: _lastMaximize ? 'Mejora de idoneidad' : 'Ahorro de tiempo',
            valueWidget: _CountUp(
              key: ValueKey('p$k'),
              value: gain,
              decimals: 1,
              suffix: ' %',
              style: _metricStyle,
            ),
          ),
          _MetricTile(
            icon: Icons.loop_rounded,
            color: Brand.navyLight,
            label: 'Iteraciones húngaras',
            valueWidget: _CountUp(
              key: ValueKey('i$k'),
              value: h.iterations.toDouble(),
              style: _metricStyle,
            ),
          ),
        ],
      ),
      softCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardTitle(
              'Comparación de valor total',
              icon: Icons.bar_chart_rounded,
            ),
            const SizedBox(height: 14),
            _barRow('Húngaro', h.totalCost, maxBar, Brand.success, unit, k),
            const SizedBox(height: 10),
            _barRow('Voraz', g.totalCost, maxBar, Brand.grayMid, unit, k),
          ],
        ),
      ),
      softCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardTitle(
              'Asignaciones',
              icon: Icons.assignment_turned_in_outlined,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Solicitud')),
                  DataColumn(label: Text('Técnico (húngaro)')),
                  DataColumn(label: Text('Costo')),
                  DataColumn(label: Text('Técnico (voraz)')),
                  DataColumn(label: Text('Costo')),
                ],
                rows: List.generate(n, (i) {
                  final hj = h.assignment[i];
                  final gj = g.assignment[i];
                  return DataRow(
                    cells: [
                      DataCell(Text(CampusPreset.requests[i])),
                      DataCell(Text(CampusPreset.technicians[hj])),
                      DataCell(Text('${cost[i][hj]} $unit')),
                      DataCell(Text(CampusPreset.technicians[gj])),
                      DataCell(Text('${cost[i][gj]} $unit')),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
      softCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardTitle(
              'Grafo bipartito: solicitudes ↔ técnicos',
              icon: Icons.account_tree_outlined,
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 48),
              child: Text(
                'Las aristas cian representan la asignación óptima.',
                style: TextStyle(color: Brand.grayMid),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 420,
                width: math.max(520, MediaQuery.sizeOf(context).width - 96),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('graph$k'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1800),
                  curve: Curves.easeInOut,
                  builder: (context, p, _) => CustomPaint(
                    painter: BipartiteGraphPainter(
                      leftLabels: CampusPreset.requests.take(n).toList(),
                      rightLabels: CampusPreset.technicians.take(n).toList(),
                      cost: cost,
                      assignment: h.assignment,
                      unit: unit,
                      progress: p,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      _stepper(h),
    ];
  }

  Widget _barRow(
    String label,
    int value,
    int maxValue,
    Color color,
    String unit,
    int runId,
  ) {
    final fraction = maxValue == 0 ? 0.0 : value / maxValue;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Brand.navy,
            ),
          ),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            key: ValueKey('bar-$label-$runId'),
            tween: Tween<double>(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 12,
                color: color,
                backgroundColor: Brand.grayLight,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value $unit',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  /// Reproductor de los pasos del Método Húngaro: manual o automático.
  Widget _stepper(HungarianResult h) {
    final steps = h.steps;
    final s = steps[_stepIdx];
    return softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cardTitle(
            'Reproductor del Método Húngaro',
            icon: Icons.play_circle_outline_rounded,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Paso anterior',
                onPressed: _stepIdx > 0 && !_playing
                    ? () => setState(() => _stepIdx--)
                    : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              FilledButton.icon(
                onPressed: _togglePlay,
                icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(_playing ? 'Pausar' : 'Reproducir'),
              ),
              IconButton.filledTonal(
                tooltip: 'Paso siguiente',
                onPressed: _stepIdx < steps.length - 1 && !_playing
                    ? () => setState(() => _stepIdx++)
                    : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              Text(
                'Paso ${_stepIdx + 1} de ${steps.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Brand.navy,
                ),
              ),
            ],
          ),
          Slider(
            value: _stepIdx.toDouble(),
            min: 0,
            max: (steps.length - 1).toDouble(),
            divisions: steps.length - 1,
            label: 'Paso ${_stepIdx + 1}',
            onChanged: _playing
                ? null
                : (v) => setState(() => _stepIdx = v.round()),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Column(
              key: ValueKey(_stepIdx),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Brand.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.description,
                  style: const TextStyle(height: 1.6, color: Brand.grayDark),
                ),
                const SizedBox(height: 14),
                Center(
                  child: MatrixView(
                    matrix: s.matrix,
                    coveredRows: s.coveredRows,
                    coveredCols: s.coveredCols,
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Legend(color: Brand.cyanSoft, text: 'cero'),
                    _Legend(color: Brand.amber, text: 'cubierto por una línea'),
                    _Legend(color: Brand.cyan, text: 'cubierto por dos líneas'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var k = 0; k < steps.length; k++)
                ChoiceChip(
                  label: Text('${k + 1}'),
                  selected: k == _stepIdx,
                  onSelected: _playing
                      ? null
                      : (_) => setState(() => _stepIdx = k),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Brand.grayLight),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12.5, color: Brand.grayMid),
        ),
      ],
    );
  }
}

// =====================================================================
// 13. SECCIÓN 6: CONCLUSIÓN
// =====================================================================
class ConclusionSection extends StatelessWidget {
  const ConclusionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      number: 6,
      title: 'Conclusión',
      subtitle: 'Síntesis de resultados e impacto operativo en la UCB La Paz',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Brand.navy, Brand.navyLight, Brand.blue],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'La asignación global con el Método Húngaro siempre iguala o mejora a la asignación voraz, porque '
                'evalúa el conjunto de solicitudes en lugar de decidir una por una.',
                style: TextStyle(fontSize: 17, height: 1.7, color: Brand.white),
              ),
              SizedBox(height: 22),
              Wrap(
                spacing: 40,
                runSpacing: 16,
                children: [
                  _Kpi(value: 94, label: 'minutos con asignación voraz'),
                  _Kpi(value: 67, label: 'minutos con método húngaro'),
                  _Kpi(
                    value: 28.7,
                    decimals: 1,
                    suffix: ' %',
                    label: 'de reducción del tiempo total',
                  ),
                ],
              ),
            ],
          ),
        ),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            FeatureTile(
              icon: Icons.timer_rounded,
              title: 'Menos tiempo de espera',
              text: 'Las urgencias del Bloque D, la biblioteca o el auditorio se atienden antes.',
            ),
            FeatureTile(
              icon: Icons.groups_rounded,
              title: 'Carga equilibrada',
              text: 'Cada técnico atiende una sola solicitud por ciclo, sin saturaciones.',
            ),
            FeatureTile(
              icon: Icons.account_tree_rounded,
              title: 'Decisión sustentada',
              text: 'El coordinador ve la matriz, los pasos y el grafo que justifican la asignación.',
            ),
          ],
        ),
        softCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ventajas de O(n³) frente a O(n!)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Brand.navy,
                ),
              ),
              SizedBox(height: 12),
              _CheckItem(
                text:
                    'Con 20 solicitudes, el Método Húngaro realiza del orden de 8.000 operaciones; la fuerza bruta '
                    'debería evaluar más de 10¹⁸ permutaciones.',
              ),
              SizedBox(height: 10),
              _CheckItem(
                text: 'Garantiza el óptimo global, no una aproximación, y escala a campus completos en tiempo real.',
              ),
            ],
          ),
        ),
        softCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Posibles mejoras futuras',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Brand.navy,
                ),
              ),
              SizedBox(height: 12),
              _CheckItem(
                text: 'Modelo rectangular para casos con más solicitudes que técnicos (o al revés).',
              ),
              SizedBox(height: 10),
              _CheckItem(
                text: 'Costos dinámicos alimentados con ubicación en tiempo real y carga actual.',
              ),
              SizedBox(height: 10),
              _CheckItem(
                text: 'Prioridades y ventanas de tiempo (por ejemplo, antes de un examen o evento).',
              ),
              SizedBox(height: 10),
              _CheckItem(
                text: 'Integración con el sistema de tickets de soporte de la universidad.',
              ),
              SizedBox(height: 10),
              _CheckItem(
                text: 'Algoritmos de subasta o Jonker-Volgenant para instancias de gran tamaño.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
