import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'editar_estacionamiento.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);

class DetalleEstacionamientoPropietario extends StatefulWidget {
  final Map<String, dynamic> estacionamiento;
  const DetalleEstacionamientoPropietario({
    super.key,
    required this.estacionamiento,
  });

  @override
  State<DetalleEstacionamientoPropietario> createState() => _DetalleState();
}

class _DetalleState extends State<DetalleEstacionamientoPropietario>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _espacios = [];
  List<Map<String, dynamic>> _reservaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    final id = widget.estacionamiento['id'];

    final results = await Future.wait([
      Supabase.instance.client
          .from('espacios')
          .select('*, reservado_hasta, reservado_por')
          .eq('estacionamiento_id', id),
      Supabase.instance.client
          .from('reservaciones')
          .select('*, perfiles(nombre)')
          .eq('estacionamiento_id', id)
          .order('created_at', ascending: false)
          .limit(30),
      Supabase.instance.client
          .from('reservaciones')
          .select('espacio_id')
          .eq('estacionamiento_id', id)
          .eq('estado', 'activa'),
    ]);

    final espacios = results[0] as List;
    final reservaciones = results[1] as List;
    final reservasActivas = results[2] as List;

    final espaciosConReserva = <String>{
      for (final r in reservasActivas) r['espacio_id'] as String,
    };

    // Corregir disponible según reservas activas
    final espaciosCorregidos = espacios.map((e) {
      if (espaciosConReserva.contains(e['id'])) {
        return {...e as Map<String, dynamic>, 'disponible': false};
      }
      return e as Map<String, dynamic>;
    }).toList();

    setState(() {
      _espacios = List<Map<String, dynamic>>.from(espaciosCorregidos);
      _reservaciones = List<Map<String, dynamic>>.from(reservaciones);
      _cargando = false;
    });
  }

  Future<void> _toggleActivo() async {
    final nuevo = !(widget.estacionamiento['activo'] as bool);
    await Supabase.instance.client
        .from('estacionamientos')
        .update({'activo': nuevo})
        .eq('id', widget.estacionamiento['id']);
    setState(() => widget.estacionamiento['activo'] = nuevo);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.estacionamiento['activo'] == true;
    final libres = _espacios.where((e) => e['disponible'] == true).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _cyan,
        title: Text(
          widget.estacionamiento['nombre'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditarEstacionamientoScreen(
                    estacionamiento: widget.estacionamiento,
                  ),
                ),
              );
              _cargar();
            },
          ),
          Switch(
            value: activo,
            activeThumbColor: _cyan,
            onChanged: (_) => _toggleActivo(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _cyan,
          labelColor: _cyan,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Espacios'),
            Tab(text: 'Reservaciones'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _stat('$libres', 'Libres', _cyan),
                      _stat(
                        '${_espacios.length - libres}',
                        'Ocupados',
                        Colors.orange,
                      ),
                      _stat(
                        '${_reservaciones.where((r) => r['estado'] == 'activa').length}',
                        'Activas',
                        Colors.purpleAccent,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [_buildEspacios(), _buildReservaciones()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEspacios() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leyenda
          Row(
            children: [
              _leyenda(const Color(0xFF00E676), 'Libre'),
              const SizedBox(width: 10),
              _leyenda(Colors.grey, 'Ocupado'),
              const SizedBox(width: 10),
              _leyenda(Colors.orange, 'Reservado'),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _espacios.length,
            itemBuilder: (_, i) {
              final e = _espacios[i];
              final libre = e['disponible'] == true;
              final reservadoHasta = e['reservado_hasta'] != null
                  ? DateTime.tryParse(e['reservado_hasta'])?.toLocal()
                  : null;
              final bloqueado =
                  reservadoHasta != null &&
                  reservadoHasta.isAfter(DateTime.now());

              Color border, bg, text;
              if (!libre) {
                border = Colors.transparent;
                bg = Colors.grey[900]!;
                text = Colors.grey[600]!;
              } else if (bloqueado) {
                border = Colors.orange.withOpacity(0.6);
                bg = Colors.orange.withOpacity(0.1);
                text = Colors.orange;
              } else {
                border = const Color(0xFF00E676);
                bg = const Color(0xFF00E676).withOpacity(0.08);
                text = const Color(0xFF00E676);
              }

              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    e['codigo'],
                    style: TextStyle(color: text, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String texto) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(texto, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );

  Widget _buildReservaciones() {
    if (_reservaciones.isEmpty) {
      return const Center(
        child: Text('Sin reservaciones', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reservaciones.length,
      itemBuilder: (_, i) {
        final r = _reservaciones[i];
        final estado = r['estado'] ?? 'activa';
        final color = estado == 'activa'
            ? _cyan
            : estado == 'completada'
            ? Colors.green
            : Colors.red;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline, color: _cyan, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['perfiles']?['nombre'] ?? 'Usuario',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${r['precio_total']} • ${r['horas']}h',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String valor, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
