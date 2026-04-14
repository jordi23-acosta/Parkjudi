import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Login.dart';
import 'detalles_estacionamiento.dart';
import 'notificaciones.dart';
import 'configuraciones.dart';
import 'calificar_estacionamiento.dart';
import '../widgets/notif_badge.dart';
import '../widgets/avatar_picker.dart';

const Color colorCianNeon = Color(0xFF00FFE0);
const Color colorOscuroFondo = Color(0xFF0F1218);
const Color colorGrisTarjeta = Color(0xFF1F252F);
const Color colorVerdeStatus = Color(0xFF00E676);

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _paginaActual = 0;
  bool _ubicacionLista = false;
  bool _buscandoGPS = false;
  String _nombreUsuario = '';
  String _emailUsuario = '';
  String _placaUsuario = '';
  String _avatarUrl = '';

  LatLng? _miPosicionActual;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _timerReserva?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final email = user.email ?? '';
    String nombre = email.split('@')[0];
    String placa = '';
    String avatar = '';

    try {
      final perfil = await Supabase.instance.client
          .from('perfiles')
          .select('nombre, placa, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (perfil != null) {
        // Si el nombre está vacío, tomarlo de los metadatos de auth
        final nombreGuardado = (perfil['nombre'] as String?)?.trim() ?? '';
        if (nombreGuardado.isNotEmpty) {
          nombre = nombreGuardado;
        } else {
          // Actualizar el perfil con el nombre de los metadatos
          final metaNombre = user.userMetadata?['nombre'] ?? nombre;
          nombre = metaNombre.isNotEmpty ? metaNombre : nombre;
          await Supabase.instance.client
              .from('perfiles')
              .update({
                'nombre': nombre,
                'placa': user.userMetadata?['placa'] ?? '',
              })
              .eq('id', user.id);
        }
        placa = perfil['placa'] ?? '';
        avatar = perfil['avatar_url'] ?? '';
      } else {
        final metaNombre = user.userMetadata?['nombre'] ?? nombre;
        final metaPlaca = user.userMetadata?['placa'] ?? '';
        await Supabase.instance.client.from('perfiles').upsert({
          'id': user.id,
          'nombre': metaNombre,
          'placa': metaPlaca,
          'rol': user.userMetadata?['rol'] ?? 'conductor',
        });
        nombre = metaNombre;
        placa = metaPlaca;
      }
    } catch (_) {}

    setState(() {
      _nombreUsuario = nombre;
      _emailUsuario = email;
      _placaUsuario = placa;
      _avatarUrl = avatar;
    });
  }

  Future<void> _obtenerUbicacionReal() async {
    setState(() => _buscandoGPS = true);

    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, enciende el GPS.')),
      );
      setState(() => _buscandoGPS = false);
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        setState(() => _buscandoGPS = false);
        return;
      }
    }

    Position posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _miPosicionActual = LatLng(posicion.latitude, posicion.longitude);
      _ubicacionLista = true;
      _buscandoGPS = false;
    });
  }

  // --- CONTROLADOR DE VISTAS ---
  // Esta función decide qué pantalla mostrar según el botón seleccionado
  Widget _obtenerVistaActual() {
    switch (_paginaActual) {
      case 0:
        return _construirVistaMapa();
      case 1:
        return _construirVistaLista();
      case 2:
        return _construirVistaReserva();
      case 3:
        return _construirVistaPerfil();
      default:
        return _construirVistaMapa();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si aún no tenemos la ubicación, mostramos la pantalla de permisos
    if (!_ubicacionLista) {
      return _construirPantallaPermiso();
    }

    return Scaffold(
      backgroundColor: colorOscuroFondo,
      body: SafeArea(child: _obtenerVistaActual()),
      floatingActionButton: _paginaActual == 0
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(alignment: Alignment.topRight, child: NotifBadge()),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,

      // BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: colorCianNeon,
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          currentIndex: _paginaActual,
          onTap: (index) {
            setState(() {
              _paginaActual =
                  index; // Al tocar, cambiamos la variable y se actualiza la pantalla
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.public_rounded),
              label: 'Mapa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: 'Lista',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Mi Reserva',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // VISTA 0: MAPA (Tu mapa actual)
  // =========================================================================
  Widget _construirVistaMapa() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _miPosicionActual!,
            zoom: 15.0,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (GoogleMapController controller) =>
              _mapController = controller,
        ),
        Positioned(
          top: 10,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.grey, size: 20),
                SizedBox(width: 10),
                Text(
                  "Buscando en tu zona...",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 20,
          child: FloatingActionButton(
            backgroundColor: colorCianNeon,
            foregroundColor: Colors.black,
            onPressed: () => _mapController?.animateCamera(
              CameraUpdate.newLatLng(_miPosicionActual!),
            ),
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // VISTA 1: LISTA DE ESTACIONAMIENTOS
  // =========================================================================
  List<Map<String, dynamic>> _listaEstacionamientos = [];
  bool _cargandoLista = false;

  Future<void> _cargarEstacionamientos() async {
    setState(() => _cargandoLista = true);
    try {
      final data = await Supabase.instance.client
          .from('estacionamientos')
          .select('*, espacios(disponible)')
          .eq('activo', true)
          .order('created_at', ascending: false);
      setState(
        () => _listaEstacionamientos = List<Map<String, dynamic>>.from(data),
      );
    } catch (_) {}
    setState(() => _cargandoLista = false);
  }

  Widget _construirVistaLista() {
    if (_listaEstacionamientos.isEmpty && !_cargandoLista) {
      _cargarEstacionamientos();
    }
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cerca de ti',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _cargandoLista
                ? const Center(
                    child: CircularProgressIndicator(color: colorCianNeon),
                  )
                : RefreshIndicator(
                    color: colorCianNeon,
                    onRefresh: _cargarEstacionamientos,
                    child: _listaEstacionamientos.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay estacionamientos disponibles',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _listaEstacionamientos.length,
                            itemBuilder: (_, i) {
                              final e = _listaEstacionamientos[i];
                              final espacios = (e['espacios'] as List?) ?? [];
                              final libres = espacios
                                  .where((s) => s['disponible'] == true)
                                  .length;
                              final total = espacios.length;
                              final progress = total > 0
                                  ? (total - libres) / total
                                  : 0.0;
                              final color = libres == 0
                                  ? Colors.red
                                  : libres <= 3
                                  ? Colors.orange
                                  : colorVerdeStatus;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: _buildParkingCard(
                                  estacionamientoId: e['id'],
                                  name: e['nombre'] ?? '',
                                  address: e['direccion'] ?? '',
                                  price: '\$${e['precio_por_hora']}',
                                  freeSpots: '$libres libres',
                                  progressColor: color,
                                  progress: progress.toDouble(),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // VISTA 2: MI RESERVA
  // =========================================================================
  Map<String, dynamic>? _reservaActiva;
  Map<String, dynamic>? _reservaPendienteCalificar;
  bool _cargandoReserva = false;
  Timer? _timerReserva;

  Future<void> _cargarReserva() async {
    setState(() => _cargandoReserva = true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final activa = await Supabase.instance.client
        .from('reservaciones')
        .select('*, estacionamientos(nombre, direccion), espacios(codigo)')
        .eq('conductor_id', uid)
        .eq('estado', 'activa')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final completadas = await Supabase.instance.client
        .from('reservaciones')
        .select('*, estacionamientos(nombre)')
        .eq('conductor_id', uid)
        .eq('estado', 'completada')
        .order('created_at', ascending: false)
        .limit(5);

    Map<String, dynamic>? pendiente;
    for (final r in (completadas as List)) {
      final resena = await Supabase.instance.client
          .from('resenas')
          .select('id')
          .eq('reservacion_id', r['id'])
          .maybeSingle();
      if (resena == null) {
        pendiente = r;
        break;
      }
    }

    setState(() {
      _reservaActiva = activa;
      _reservaPendienteCalificar = pendiente;
      _cargandoReserva = false;
    });

    // Timer para actualizar el tiempo restante cada segundo
    _timerReserva?.cancel();
    if (activa != null) {
      _timerReserva = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Widget _construirVistaReserva() {
    if (!_cargandoReserva &&
        _reservaActiva == null &&
        _reservaPendienteCalificar == null) {
      _cargarReserva();
    }
    if (_cargandoReserva) {
      return const Center(
        child: CircularProgressIndicator(color: colorCianNeon),
      );
    }
    return RefreshIndicator(
      color: colorCianNeon,
      onRefresh: _cargarReserva,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_reservaActiva != null)
              _buildTicketActivo(_reservaActiva!)
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorGrisTarjeta,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.local_parking_rounded,
                      color: Colors.grey,
                      size: 50,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Sin reserva activa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ve al mapa o lista para reservar',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            if (_reservaPendienteCalificar != null) ...[
              const SizedBox(height: 20),
              _buildCalificarCard(_reservaPendienteCalificar!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTicketActivo(Map<String, dynamic> r) {
    final fin = DateTime.tryParse(r['fin_estimado'] ?? '');
    final inicioReal = r['inicio_real'];
    final esperando = inicioReal == null; // propietario aún no confirmó
    final ahora = DateTime.now();
    final restante = fin != null ? fin.difference(ahora) : Duration.zero;
    final vencida = !esperando && restante.isNegative;
    final hh = restante.inHours.abs().toString().padLeft(2, '0');
    final mm = (restante.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final ss = (restante.inSeconds.abs() % 60).toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorGrisTarjeta,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorCianNeon.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            vencida
                ? 'Reserva vencida'
                : esperando
                ? 'Esperando confirmación'
                : 'Ticket Activo',
            style: TextStyle(
              color: vencida
                  ? Colors.orange
                  : esperando
                  ? Colors.grey
                  : colorCianNeon,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.qr_code_2, size: 120, color: Colors.black),
          ),
          const SizedBox(height: 16),
          Text(
            r['estacionamientos']?['nombre'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Espacio ${r['espacios']?['codigo'] ?? ''}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const Divider(color: Colors.white12, height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tiempo restante:',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                vencida
                    ? 'Vencido'
                    : esperando
                    ? 'Pendiente de entrada'
                    : '$hh:$mm:$ss',
                style: TextStyle(
                  color: vencida
                      ? Colors.orange
                      : esperando
                      ? Colors.grey
                      : colorVerdeStatus,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(color: Colors.grey)),
              Text(
                '\$${r['precio_total']}',
                style: const TextStyle(
                  color: colorCianNeon,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!vencida)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancelar'),
                    onPressed: () => _cancelarReserva(r),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorCianNeon.withOpacity(0.15),
                      foregroundColor: colorCianNeon,
                      elevation: 0,
                      side: const BorderSide(color: colorCianNeon),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.more_time_rounded, size: 18),
                    label: const Text('Extender'),
                    onPressed: () => _extenderReserva(r),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _cancelarReserva(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorGrisTarjeta,
        title: const Text(
          '¿Cancelar reserva?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'El espacio quedará libre.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc(
        'cancelar_reserva',
        params: {'reserva_id': r['id']},
      );
      _timerReserva?.cancel();
      _cargarReserva();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva cancelada'),
            backgroundColor: Colors.orange,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  Future<void> _extenderReserva(Map<String, dynamic> r) async {
    int horasExtra = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: colorGrisTarjeta,
          title: const Text(
            'Extender tiempo',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Cuántas horas más?',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: colorCianNeon,
                    ),
                    onPressed: horasExtra > 1
                        ? () => setS(() => horasExtra--)
                        : null,
                  ),
                  Text(
                    '$horasExtra h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: colorCianNeon,
                    ),
                    onPressed: horasExtra < 6
                        ? () => setS(() => horasExtra++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirmar',
                style: TextStyle(
                  color: colorCianNeon,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final finActual =
          DateTime.tryParse(r['fin_estimado'] ?? '') ?? DateTime.now();
      final nuevoFin = finActual.add(Duration(hours: horasExtra));
      final pph = (r['precio_total'] as num) / (r['horas'] as num? ?? 1);
      final nuevoPrecio = (r['precio_total'] as num) + (pph * horasExtra);
      await Supabase.instance.client
          .from('reservaciones')
          .update({
            'fin_estimado': nuevoFin.toIso8601String(),
            'horas': (r['horas'] as int? ?? 1) + horasExtra,
            'precio_total': nuevoPrecio,
          })
          .eq('id', r['id']);
      _cargarReserva();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tiempo extendido +${horasExtra}h'),
            backgroundColor: colorCianNeon,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  Widget _buildCalificarCard(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorGrisTarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                '�C�mo estuvo tu visita?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r['estacionamientos']?['nombre'] ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalificarEstacionamientoScreen(
                      estacionamientoId: r['estacionamiento_id'],
                      reservacionId: r['id'],
                      nombreEstacionamiento:
                          r['estacionamientos']?['nombre'] ?? '',
                    ),
                  ),
                );
                _cargarReserva();
              },
              child: const Text(
                'Calificar ahora',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // VISTA 3: PERFIL DE USUARIO
  // =========================================================================
  Widget _construirVistaPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Avatar con foto de perfil
          AvatarPicker(
            nombre: _nombreUsuario,
            avatarUrl: _avatarUrl,
            radius: 50,
            onUploaded: (url) => setState(() => _avatarUrl = url),
          ),
          const SizedBox(height: 16),

          Text(
            _nombreUsuario,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _emailUsuario,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),

          if (_placaUsuario.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colorCianNeon.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorCianNeon.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: colorCianNeon,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _placaUsuario,
                    style: const TextStyle(
                      color: colorCianNeon,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

          // Opciones
          _buildOpcionPerfil(
            Icons.notifications_outlined,
            'Notificaciones',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _buildOpcionPerfil(
            Icons.settings_outlined,
            'Configuraciones',
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConfiguracionesScreen(rol: 'conductor'),
                ),
              );
              _cargarPerfil(); // Recargar al volver
            },
          ),

          const SizedBox(height: 36),

          // Cerrar sesión
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOpcionPerfil(IconData icon, String titulo, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: colorCianNeon),
      title: Text(titulo, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      tileColor: colorGrisTarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  // --- PANTALLA DE PERMISOS (Intacta) ---
  Widget _construirPantallaPermiso() {
    return Scaffold(
      backgroundColor: colorOscuroFondo,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorCianNeon.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: colorCianNeon.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 80,
                  color: colorCianNeon,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "Encuentra tu lugar",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Necesitamos acceder a tu ubicación para mostrarte el mapa real de tu ciudad.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorCianNeon,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _buscandoGPS ? null : _obtenerUbicacionReal,
                  child: _buscandoGPS
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 15),
                            Text(
                              "Buscando señal GPS...",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          "Permitir Ubicación",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET AUXILIAR PARA LAS TARJETAS ---
  Widget _buildParkingCard({
    required String estacionamientoId,
    required String name,
    required String address,
    required String price,
    required String freeSpots,
    required Color progressColor,
    required double progress,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleEstacionamientoScreen(
            estacionamientoId: estacionamientoId,
            nombre: name,
            direccion: address,
            precio: price,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorGrisTarjeta,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: colorOscuroFondo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.local_parking_rounded,
                  color: Colors.grey,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    address,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        color: colorCianNeon,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "/hora",
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    freeSpots,
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ), // Container
    ); // GestureDetector
  } // _buildParkingCard
}
