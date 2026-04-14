import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'confirmar_reserva.dart';

const Color colorCianNeon = Color(0xFF00FFE0);
const Color colorOscuroFondo = Color(0xFF0F1218);
const Color colorGrisTarjeta = Color(0xFF1F252F);
const Color colorVerdeStatus = Color(0xFF00E676);

class DetalleEstacionamientoScreen extends StatefulWidget {
  final String estacionamientoId;
  final String nombre;
  final String direccion;
  final String precio;

  const DetalleEstacionamientoScreen({
    super.key,
    required this.estacionamientoId,
    required this.nombre,
    required this.direccion,
    required this.precio,
  });

  @override
  State<DetalleEstacionamientoScreen> createState() =>
      _DetalleEstacionamientoScreenState();
}

class _DetalleEstacionamientoScreenState
    extends State<DetalleEstacionamientoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _espacioSeleccionadoId;
  String? _espacioSeleccionadoCodigo;
  List<Map<String, dynamic>> _espacios = [];
  List<Map<String, dynamic>> _resenas = [];
  Map<String, dynamic>? _estacionamiento;
  bool _cargando = true;
  String _propietarioId = '';
  double _promedioEstrellas = 0;

  // Navegación
  GoogleMapController? _mapCtrl;
  LatLng? _miPosicion;
  LatLng? _destino;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      await Supabase.instance.client.rpc('liberar_espacio_vencido');
    } catch (_) {}

    final est = await Supabase.instance.client
        .from('estacionamientos')
        .select()
        .eq('id', widget.estacionamientoId)
        .maybeSingle();

    final espacios = await Supabase.instance.client
        .from('espacios')
        .select()
        .eq('estacionamiento_id', widget.estacionamientoId)
        .order('codigo');

    final resenas = await Supabase.instance.client
        .from('resenas')
        .select('*, perfiles(nombre, avatar_url)')
        .eq('estacionamiento_id', widget.estacionamientoId)
        .order('created_at', ascending: false);

    double promedio = 0;
    if ((resenas as List).isNotEmpty) {
      promedio =
          resenas.fold<double>(
            0,
            (s, r) => s + (r['estrellas'] as int).toDouble(),
          ) /
          resenas.length;
    }

    // Configurar mapa si hay coordenadas
    if (est != null && est['latitud'] != null && est['longitud'] != null) {
      final dest = LatLng(est['latitud'], est['longitud']);
      setState(() => _destino = dest);
      _markers.add(
        Marker(
          markerId: const MarkerId('destino'),
          position: dest,
          infoWindow: InfoWindow(title: est['nombre'] ?? ''),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
      _obtenerMiPosicion();
    }

    setState(() {
      _estacionamiento = est;
      _propietarioId = est?['propietario_id'] ?? '';
      _espacios = List<Map<String, dynamic>>.from(espacios);
      _resenas = List<Map<String, dynamic>>.from(resenas);
      _promedioEstrellas = promedio;
      _cargando = false;
    });
  }

  Future<void> _obtenerMiPosicion() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _miPosicion = ll;
        _markers.add(
          Marker(
            markerId: const MarkerId('yo'),
            position: ll,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: const InfoWindow(title: 'Tu ubicación'),
          ),
        );
        // Línea directa entre mi posición y el destino
        if (_destino != null) {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('ruta'),
              points: [ll, _destino!],
              color: colorCianNeon,
              width: 4,
            ),
          };
        }
      });
      // Ajustar cámara para mostrar ambos puntos
      if (_destino != null && _mapCtrl != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            ll.latitude < _destino!.latitude ? ll.latitude : _destino!.latitude,
            ll.longitude < _destino!.longitude
                ? ll.longitude
                : _destino!.longitude,
          ),
          northeast: LatLng(
            ll.latitude > _destino!.latitude ? ll.latitude : _destino!.latitude,
            ll.longitude > _destino!.longitude
                ? ll.longitude
                : _destino!.longitude,
          ),
        );
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libres = _espacios.where((e) => e['disponible'] == true).length;
    final est = _estacionamiento;

    return Scaffold(
      backgroundColor: colorOscuroFondo,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: colorCianNeon))
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: colorOscuroFondo,
                  foregroundColor: colorCianNeon,
                  flexibleSpace: FlexibleSpaceBar(
                    background: est?['foto_url'] != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                est!['foto_url'],
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      colorOscuroFondo.withOpacity(0.9),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: colorGrisTarjeta,
                            child: const Icon(
                              Icons.local_parking_rounded,
                              color: colorCianNeon,
                              size: 60,
                            ),
                          ),
                  ),
                  title: Text(
                    widget.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(
                        right: 16,
                        top: 10,
                        bottom: 10,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorCianNeon,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ABIERTO',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabs,
                    indicatorColor: colorCianNeon,
                    labelColor: colorCianNeon,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Espacios'),
                      Tab(text: 'Info'),
                      Tab(text: 'Reseñas'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _buildEspacios(libres),
                  _buildInfo(est),
                  _buildResenas(),
                ],
              ),
            ),
      bottomNavigationBar: _espacioSeleccionadoId != null
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              decoration: const BoxDecoration(
                color: colorOscuroFondo,
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Espacio seleccionado: $_espacioSeleccionadoCodigo',
                    style: const TextStyle(
                      color: colorCianNeon,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorCianNeon,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () {
                        final precio =
                            double.tryParse(
                              widget.precio.replaceAll(RegExp(r'[^0-9.]'), ''),
                            ) ??
                            15.0;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConfirmarReservaScreen(
                              nombreEstacionamiento: widget.nombre,
                              direccion: widget.direccion,
                              espacioSeleccionado: _espacioSeleccionadoCodigo!,
                              espacioId: _espacioSeleccionadoId!,
                              estacionamientoId: widget.estacionamientoId,
                              propietarioId: _propietarioId,
                              precioPorHora: precio,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Continuar con reserva →',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // ── TAB 0: ESPACIOS ────────────────────────────────────────────────────────
  Widget _buildEspacios(int libres) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats
          Row(
            children: [
              _stat('$libres', 'Libres', colorCianNeon),
              _stat('${_espacios.length - libres}', 'Ocupados', Colors.orange),
              _stat(widget.precio, '/hora', Colors.white),
            ],
          ),
          const SizedBox(height: 16),

          // Leyenda
          Row(
            children: [
              _leyenda(colorVerdeStatus, 'Libre'),
              const SizedBox(width: 15),
              _leyenda(Colors.grey, 'Ocupado'),
              const SizedBox(width: 15),
              _leyenda(colorCianNeon, 'Seleccionado'),
            ],
          ),
          const SizedBox(height: 16),

          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: _espacios.length,
            itemBuilder: (_, i) {
              final e = _espacios[i];
              final libre = e['disponible'] == true;
              final sel = _espacioSeleccionadoId == e['id'];
              Color border = libre ? colorVerdeStatus : Colors.transparent;
              Color bg = libre ? Colors.transparent : Colors.grey[900]!;
              Color text = libre ? colorVerdeStatus : Colors.grey[700]!;
              if (sel) {
                bg = colorCianNeon;
                border = colorCianNeon;
                text = Colors.black;
              }
              return GestureDetector(
                onTap: libre
                    ? () => setState(() {
                        _espacioSeleccionadoId = e['id'];
                        _espacioSeleccionadoCodigo = e['codigo'];
                      })
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border.all(color: border, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      e['codigo'],
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── TAB 1: INFO + MAPA ─────────────────────────────────────────────────────
  Widget _buildInfo(Map<String, dynamic>? est) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descripción
          if (est?['descripcion']?.isNotEmpty == true) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorGrisTarjeta,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                est!['descripcion'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Características
          const Text(
            'CARACTERÍSTICAS',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (est?['horario'] != null)
                _chip(Icons.access_time_rounded, est!['horario']),
              if (est?['cubierto'] == true)
                _chip(Icons.roofing_rounded, 'Cubierto'),
              if (est?['vigilancia_24h'] == true)
                _chip(Icons.security_rounded, 'Vigilancia 24h'),
              if (est?['accesible'] == true)
                _chip(Icons.accessible_rounded, 'Accesible'),
              if (est?['acepta_motos'] == true)
                _chip(Icons.two_wheeler_rounded, 'Acepta motos'),
            ],
          ),
          const SizedBox(height: 20),

          // Mapa de cómo llegar
          const Text(
            'CÓMO LLEGAR',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          if (_destino != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 220,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _destino!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onMapCreated: (c) {
                    _mapCtrl = c;
                    if (_miPosicion != null && _destino != null) {
                      final bounds = LatLngBounds(
                        southwest: LatLng(
                          _miPosicion!.latitude < _destino!.latitude
                              ? _miPosicion!.latitude
                              : _destino!.latitude,
                          _miPosicion!.longitude < _destino!.longitude
                              ? _miPosicion!.longitude
                              : _destino!.longitude,
                        ),
                        northeast: LatLng(
                          _miPosicion!.latitude > _destino!.latitude
                              ? _miPosicion!.latitude
                              : _destino!.latitude,
                          _miPosicion!.longitude > _destino!.longitude
                              ? _miPosicion!.longitude
                              : _destino!.longitude,
                        ),
                      );
                      c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
                    }
                  },
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: colorGrisTarjeta,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'Ubicación no disponible',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── TAB 2: RESEÑAS ─────────────────────────────────────────────────────────
  Widget _buildResenas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Promedio
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorGrisTarjeta,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(
                  _promedioEstrellas.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RatingBarIndicator(
                      rating: _promedioEstrellas,
                      itemBuilder: (_, __) =>
                          const Icon(Icons.star_rounded, color: Colors.amber),
                      itemCount: 5,
                      itemSize: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_resenas.length} reseñas',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_resenas.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Sin reseñas aún. ¡Sé el primero!',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._resenas.map(_buildResenaItem),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildResenaItem(Map<String, dynamic> r) {
    final nombre = r['perfiles']?['nombre'] ?? 'Usuario';
    final avatar = r['perfiles']?['avatar_url'];
    final fecha = DateTime.tryParse(r['created_at'] ?? '');
    final fechaStr = fecha != null
        ? '${fecha.day}/${fecha.month}/${fecha.year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorGrisTarjeta,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorCianNeon,
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        nombre[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      fechaStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              RatingBarIndicator(
                rating: (r['estrellas'] as int).toDouble(),
                itemBuilder: (_, __) =>
                    const Icon(Icons.star_rounded, color: Colors.amber),
                itemCount: 5,
                itemSize: 16,
              ),
            ],
          ),
          if (r['comentario']?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              r['comentario'],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String valor, String label, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorGrisTarjeta,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    ),
  );

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

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: colorCianNeon.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colorCianNeon.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colorCianNeon, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: colorCianNeon, fontSize: 12)),
      ],
    ),
  );
}
