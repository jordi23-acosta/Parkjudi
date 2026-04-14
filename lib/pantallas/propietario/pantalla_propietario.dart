import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Login.dart';
import 'agregar_estacionamiento.dart';
import 'detalle_estacionamiento.dart';
import 'escaner_qr.dart';
import '../notificaciones.dart';
import '../configuraciones.dart';
import '../../widgets/notif_badge.dart';
import '../../widgets/avatar_picker.dart';
import 'metodo_cobro.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);
const Color _verde = Color(0xFF00E676);

class PantallaPropietario extends StatefulWidget {
  const PantallaPropietario({super.key});

  @override
  State<PantallaPropietario> createState() => _PantallaPropietarioState();
}

class _PantallaPropietarioState extends State<PantallaPropietario> {
  int _tab = 0;
  List<Map<String, dynamic>> _estacionamientos = [];
  List<Map<String, dynamic>> _reservaciones = [];
  bool _cargando = true;
  String _nombre = '';
  String _email = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final user = Supabase.instance.client.auth.currentUser!;
    final uid = user.id;

    final perfil = await Supabase.instance.client
        .from('perfiles')
        .select('nombre, avatar_url')
        .eq('id', uid)
        .maybeSingle();

    final lista = await Supabase.instance.client
        .from('estacionamientos')
        .select()
        .eq('propietario_id', uid)
        .order('created_at', ascending: false);

    final ids = (lista as List).map((e) => e['id']).toList();
    List reservas = [];
    if (ids.isNotEmpty) {
      reservas = await Supabase.instance.client
          .from('reservaciones')
          .select(
            '*, perfiles(nombre), estacionamientos(nombre), espacios(codigo)',
          )
          .inFilter('estacionamiento_id', ids)
          .order('created_at', ascending: false);
    }

    setState(() {
      _nombre = perfil?['nombre'] ?? user.email?.split('@')[0] ?? 'Propietario';
      _email = user.email ?? '';
      _avatarUrl = perfil?['avatar_url'] ?? '';
      _estacionamientos = List<Map<String, dynamic>>.from(lista);
      _reservaciones = List<Map<String, dynamic>>.from(reservas);
      _cargando = false;
    });
  }

  double _calcularIngresoHoy() {
    final hoy = DateTime.now();
    return _reservaciones
        .where((r) {
          final f = DateTime.tryParse(r['created_at'] ?? '');
          return r['estado'] == 'completada' &&
              f != null &&
              f.day == hoy.day &&
              f.month == hoy.month &&
              f.year == hoy.year;
        })
        .fold(
          0.0,
          (s, r) => s + ((r['precio_total'] as num?)?.toDouble() ?? 0),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : SafeArea(child: _getTab()),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _getTab() {
    switch (_tab) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildEstacionamientos();
      case 2:
        return _buildReservaciones();
      case 3:
        return _buildPerfil();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _cyan,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking_rounded),
            label: 'Mis lugares',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Reservas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  // ── TAB 0: DASHBOARD ───────────────────────────────────────────────────────
  Widget _buildDashboard() {
    final totalEsp = _estacionamientos.fold<int>(
      0,
      (s, e) => s + (e['total_espacios'] as int? ?? 0),
    );
    final ocupados = _reservaciones
        .where((r) => r['estado'] == 'activa')
        .length;
    final disponibles = (totalEsp - ocupados).clamp(0, totalEsp);
    final ingresoHoy = _calcularIngresoHoy();

    return RefreshIndicator(
      color: _cyan,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Panel Admin',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    'Hola, $_nombre 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const NotifBadge(),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _cyan,
                    backgroundImage: _avatarUrl.isNotEmpty
                        ? NetworkImage(_avatarUrl)
                        : null,
                    child: _avatarUrl.isEmpty
                        ? Text(
                            _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats 2x2
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard2('$totalEsp', 'Espacios totales', _cyan),
              _statCard2('$disponibles', 'Disponibles', _verde),
              _statCard2('$ocupados', 'Ocupados', Colors.orange),
              _statCard2(
                '\$${ingresoHoy.toStringAsFixed(0)}',
                'Ingresos hoy',
                _verde,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Reservas recientes
          const Text(
            'RESERVAS RECIENTES',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          if (_reservaciones.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Sin reservaciones aún',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._reservaciones.take(5).map(_buildReservaItemDash),

          const SizedBox(height: 20),

          // Botón gestionar
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => setState(() => _tab = 1),
              child: const Text(
                'Gestionar espacios',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard2(String valor, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReservaItemDash(Map<String, dynamic> r) {
    final estado = r['estado'] ?? 'activa';
    final codigo = r['espacios']?['codigo'] ?? '??';
    final nombre = r['perfiles']?['nombre'] ?? 'Usuario';
    final fecha = DateTime.tryParse(r['created_at'] ?? '');
    final hora = fecha != null
        ? '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'
        : '';
    final horas = r['horas'] ?? 1;

    final Color color;
    final String etiqueta;
    if (estado == 'activa') {
      color = _cyan;
      etiqueta = 'Activa';
    } else if (estado == 'completada') {
      color = _verde;
      etiqueta = 'Completada';
    } else {
      color = Colors.orange;
      etiqueta = 'Expiró';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                codigo,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$hora · ${horas}h',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              etiqueta,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: MIS ESTACIONAMIENTOS ────────────────────────────────────────────
  Widget _buildEstacionamientos() {
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _cyan,
        onRefresh: _cargar,
        child: _estacionamientos.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_road_rounded, color: Colors.grey, size: 60),
                    SizedBox(height: 16),
                    Text(
                      'Sin estacionamientos aún',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _estacionamientos.length,
                itemBuilder: (_, i) => _buildEstCard(_estacionamientos[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'Agregar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AgregarEstacionamientoScreen(),
            ),
          );
          _cargar();
        },
      ),
    );
  }

  // ── TAB 2: RESERVACIONES ───────────────────────────────────────────────────
  Widget _buildReservaciones() {
    final activas = _reservaciones
        .where((r) => r['estado'] == 'activa')
        .toList();
    final historial = _reservaciones
        .where((r) => r['estado'] != 'activa')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: const Text(
            'Reservaciones',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: _cyan),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EscanerQrScreen()),
              ),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: _cyan,
            labelColor: _cyan,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Activas'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_listaReservas(activas), _listaReservas(historial)],
        ),
      ),
    );
  }

  Widget _listaReservas(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return const Center(
        child: Text('Sin reservaciones', style: TextStyle(color: Colors.grey)),
      );
    }
    return RefreshIndicator(
      color: _cyan,
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (_, i) => _buildReservaItemDash(lista[i]),
      ),
    );
  }

  // ── TAB 3: PERFIL ──────────────────────────────────────────────────────────
  Widget _buildPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          AvatarPicker(
            nombre: _nombre,
            avatarUrl: _avatarUrl,
            radius: 50,
            onUploaded: (url) => setState(() => _avatarUrl = url),
          ),
          const SizedBox(height: 16),
          Text(
            _nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cyan.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_rounded, color: _cyan, size: 14),
                SizedBox(width: 6),
                Text(
                  'Propietario',
                  style: TextStyle(
                    color: _cyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          _opcion(
            Icons.account_balance_wallet_rounded,
            'Método de cobro',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MetodoCobroScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _opcion(
            Icons.notifications_outlined,
            'Notificaciones',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _opcion(Icons.settings_outlined, 'Configuraciones', () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConfiguracionesScreen(rol: 'propietario'),
              ),
            );
            _cargar(); // Recargar al volver
          }),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Cerrar Sesión',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────
  Widget _buildEstCard(Map<String, dynamic> e) {
    final activo = e['activo'] == true;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DetalleEstacionamientoPropietario(estacionamiento: e),
          ),
        );
        _cargar();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: activo
                    ? _cyan.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_parking_rounded,
                color: activo ? _cyan : Colors.grey,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e['nombre'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    e['direccion'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _tag('\$${e['precio_por_hora']}/hr', _cyan),
                      const SizedBox(width: 8),
                      _tag('${e['total_espacios']} espacios', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _tag(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      texto,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );

  Widget _opcion(IconData icon, String titulo, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: _cyan),
    title: Text(titulo, style: const TextStyle(color: Colors.white)),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    tileColor: _card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    onTap: onTap,
  );
}
