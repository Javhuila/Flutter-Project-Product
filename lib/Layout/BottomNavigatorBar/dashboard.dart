import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/settings_account.dart';
import 'package:flutter_project_product/Layout/ini_layout.dart';
import 'package:flutter_project_product/Models/reporte_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int touchedIndex = 0;
  List<DocumentSnapshot> _pedidos = [];
  bool _loading = true;
  Map<String, int> _topProductos = {};

  Map<String, double> topClientes = {};
  bool _loadingClientes = true;

  Map<String, int> topFechas = {};
  bool _loadingFechas = true;

  Map<String, Map<String, int>> categoriasConProductos = {};
  bool _loadingRadar = true;

  @override
  void initState() {
    super.initState();
    _inicializarDashboard();
  }

  Future<void> _inicializarDashboard() async {
    await _cargarPedidosParaReporte(); // Esperar a que termine
    await cargarTopClientes(); // Ahora sí, con datos listos
    await cargarFechasMasActivas();
    await _cargarCategoriasRadar();
  }

  Future<void> _cargarPedidosParaReporte() async {
    final prefs = await SharedPreferences.getInstance();
    final dias = prefs.getInt('dias_retenidos') ?? 15;

    final ahora = DateTime.now();
    final desdeFecha = ahora.subtract(Duration(days: dias));

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Determinar adminId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    String adminId = user.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    // Cargar pedidos recientes
    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('adminId', isEqualTo: adminId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desdeFecha))
        .get();

    final pedidos = snapshot.docs;
    final processor = ReporteModel(pedidos);

    final topProds = processor.getTopProductosVendidos(top: 5);

    setState(() {
      _pedidos = pedidos;
      _topProductos = topProds;
      _loading = false;
    });
  }

  Future<void> cargarTopClientes() async {
    final processor = ReporteModel(
      _pedidos,
    ); // 'pedidos' es tu lista de DocumentSnapshot
    final resultado = processor.getTopClientesConMayorCompra();

    setState(() {
      topClientes = resultado;
      _loadingClientes = false;
    });
  }

  Future<void> cargarFechasMasActivas() async {
    final processor = ReporteModel(_pedidos);
    final resultado = processor.getFechasMasActivas(top: 4);
    setState(() {
      topFechas = resultado;
      _loadingFechas = false;
    });
  }

  Future<void> _cargarCategoriasRadar() async {
    final processor = ReporteModel(_pedidos);
    final result = await processor.getTopCategoriasConProductos(
      topCategorias: 4,
      topProductos: 3,
    );
    if (!mounted) return;
    setState(() {
      categoriasConProductos = result;
      _loadingRadar = false;
    });
  }

  // Método que prepara los datos del radar
  RadarChartData _buildRadarData() {
    // Si no hay datos, retornar un gráfico vacío
    if (categoriasConProductos.isEmpty) {
      return RadarChartData(
        dataSets: [],
        radarBackgroundColor: Colors.transparent,
        radarShape: RadarShape.polygon,
        titleTextStyle: const TextStyle(color: Colors.transparent),
        getTitle: (index, angle) => const RadarChartTitle(text: ''),
        tickCount: 1,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        tickBorderData: BorderSide.none,
        gridBorderData: BorderSide.none,
      );
    }

    // Obtener lista de features (categorías base)
    final features = categoriasConProductos.keys.toList();

    // Si hay menos de 2 categorías, no tiene sentido mostrar radar
    if (features.length < 2) {
      // No tiene sentido mostrar radar con 1 sola categoría
      return RadarChartData(
        dataSets: [],
        radarBackgroundColor: Colors.transparent,
        radarShape: RadarShape.polygon,
        titleTextStyle: const TextStyle(color: Colors.transparent),
        getTitle: (index, angle) => const RadarChartTitle(text: ''),
        tickCount: 1,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        tickBorderData: BorderSide.none,
        gridBorderData: BorderSide.none,
      );
    }

    // Obtener valor máximo para escala (si lo vas a usar en el futuro)
    // final double maxValue = categoriasConProductos.values
    //     .map((prodMap) => prodMap.values.fold<int>(0, (sum, v) => sum + v))
    //     .reduce((a, b) => a > b ? a : b)
    //     .toDouble();

    List<RadarDataSet> dataSets = [];
    int colorIndex = 0;

    final List<Color> colores = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      // Agrega más si necesitas
    ];

    categoriasConProductos.forEach((categoria, productosMap) {
      final sumaCat = productosMap.values.fold<int>(
        0,
        (addSum, v) => addSum + v,
      );

      // Este vector tendrá tantos elementos como 'features', siempre
      final List<double> valores = features.map((f) {
        return f == categoria ? sumaCat.toDouble() : 0.0;
      }).toList();

      // Validación: todos los dataEntries deben tener el mismo largo
      if (valores.length != features.length) return;

      final RadarDataSet ds = RadarDataSet(
        dataEntries: valores.map((v) => RadarEntry(value: v)).toList(),
        borderColor: colores[colorIndex % colores.length],
        fillColor: colores[colorIndex % colores.length].withValues(alpha: 0.3),
        entryRadius: 3,
        borderWidth: 2,
      );

      dataSets.add(ds);
      colorIndex++;
    });

    // Validar que todos los dataSets tienen la misma longitud de entries
    final int expectedLength = features.length;
    final bool allValid = dataSets.every(
      (ds) => ds.dataEntries.length == expectedLength,
    );

    if (!allValid || dataSets.isEmpty) {
      return RadarChartData(
        dataSets: [],
        radarBackgroundColor: Colors.transparent,
        radarShape: RadarShape.polygon,
        titleTextStyle: const TextStyle(color: Colors.transparent),
        getTitle: (index, angle) => const RadarChartTitle(text: ''),
        tickCount: 1,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        tickBorderData: BorderSide.none,
        gridBorderData: BorderSide.none,
      );
    }

    return RadarChartData(
      dataSets: dataSets,
      radarBackgroundColor: Colors.transparent,
      borderData: FlBorderData(show: true),
      radarShape: RadarShape.polygon,
      // Color del texto de los items - Colors.black87
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      getTitle: (index, angle) {
        final f = features[index];
        final text = f.length > 10 ? '${f.substring(0, 10)}...' : f;
        return RadarChartTitle(text: text, angle: angle);
      },
      tickCount: 4,
      ticksTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
      tickBorderData: const BorderSide(color: Colors.grey),
      gridBorderData: const BorderSide(color: Colors.grey),
      // maxEntry: maxValue, // Puedes agregar esto si lo necesitas
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("Dashboard"), elevation: 10),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 40),
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 55),
                      child: Text(
                        "1- Productos más vendidos",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _topProductos.isEmpty
                      ? SizedBox(
                          height: 250,
                          child: const Center(
                            child: Text(
                              "No hay datos para mostrar en la gráfica",
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 250,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        response == null ||
                                        response.touchedSection == null) {
                                      touchedIndex = -1;
                                      return;
                                    }
                                    touchedIndex = response
                                        .touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: piechartSection(),
                            ),
                          ),
                        ),
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 55),
                      child: Text(
                        "2- 5 top de clientes de mayor compra",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 250,
                        child: _loadingClientes
                            ? const Center(child: Text("Nada"))
                            : topClientes.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    "No hay datos para mostrar en la gráfica",
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: topClientes.values.isNotEmpty
                                        ? topClientes.values.reduce(
                                                (a, b) => a > b ? a : b,
                                              ) +
                                              50
                                        : 100,
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (group) =>
                                            Colors.black54,
                                        getTooltipItem:
                                            (group, groupIndex, rod, rodIndex) {
                                              final cliente = topClientes.keys
                                                  .elementAt(groupIndex);
                                              final valor =
                                                  topClientes[cliente]!
                                                      .toStringAsFixed(2);
                                              return BarTooltipItem(
                                                '$cliente\n\$ $valor',
                                                TextStyle(color: Colors.white),
                                              );
                                            },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index >= 0 &&
                                                index < topClientes.length) {
                                              final nombre = topClientes.keys
                                                  .elementAt(index);
                                              return SideTitleWidget(
                                                meta: meta,
                                                child: Text(
                                                  nombre.length > 6
                                                      ? '${nombre.substring(0, 6)}...'
                                                      : nombre,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(),
                                      topTitles: AxisTitles(),
                                    ),
                                    barGroups: topClientes.entries.mapIndexed((
                                      index,
                                      entry,
                                    ) {
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: entry.value,
                                            width: 20,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            color: Colors.teal,
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),

                  const Align(
                    alignment: Alignment.topCenter,

                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 55),
                      child: Text(
                        "3 - Fechas con mayor actividad (número de pedidos por día)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 250,
                        child: _loadingFechas
                            ? const Center(child: CircularProgressIndicator())
                            : topFechas.isEmpty
                            ? const Center(
                                child: Text("No hay datos para mostrar"),
                              )
                            : PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  startDegreeOffset:
                                      -90, // para comenzar en la parte superior, opcional
                                  sections: _sectionsFechas(),
                                  pieTouchData: PieTouchData(
                                    touchCallback: (event, pieTouchResponse) {
                                      // si quieres interacción
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),

                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 55),
                      child: Text(
                        "4- Categorías y sus productos de mayor peticion",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 300,
                        child: _loadingRadar
                            ? const Center(child: CircularProgressIndicator())
                            : categoriasConProductos.isEmpty
                            ? const Center(
                                child: Text("No hay datos para el radar"),
                              )
                            : RadarChart(
                                _buildRadarData(),
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                              ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.question_mark_rounded),
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react,
        height: 70,
        initialActiveIndex: 0,
        backgroundColor: theme.colorScheme.primary,
        activeColor: theme.colorScheme.onPrimary,
        color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
        items: const [
          TabItem(icon: Icons.dashboard_outlined, title: "Reporte"),
          TabItem(icon: Icons.home, title: "Inicio"),
          TabItem(icon: Icons.settings, title: "Ajustes"),
        ],
        onTap: (int index) {
          switch (index) {
            case 0:
              break;
            case 1:
              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const IniLayout()),
              );
              break;
            case 2:
              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const SettingsAcount()),
              );
              break;
          }
        },
      ),
    );
  }

  List<PieChartSectionData> piechartSection() {
    final sectionColors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    final entries = _topProductos.entries.toList();

    return List.generate(entries.length, (index) {
      final producto = entries[index];
      final isTouched1 = index == touchedIndex;
      final radius = isTouched1 ? 60.0 : 50.0;
      final fontSize = isTouched1 ? 18.0 : 14.0;

      return PieChartSectionData(
        color: sectionColors[index % sectionColors.length],
        value: producto.value.toDouble(),
        title: producto.key,
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  List<PieChartSectionData> _sectionsFechas() {
    final colors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
    ];

    final entries = topFechas.entries.toList();
    if (entries.isEmpty) return [];

    return List.generate(entries.length, (i) {
      final e = entries[i];
      final isTouched2 = i == touchedIndex;
      final double radius = isTouched2 ? 60 : 50;
      final double fontSize = isTouched2 ? 16 : 14;

      return PieChartSectionData(
        color: colors[i % colors.length],
        value: e.value.toDouble(),
        title: "${e.key}\n${e.value}",
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.6,
      );
    });
  }
}
