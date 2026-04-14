import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);

class AgregarEstacionamientoScreen extends StatefulWidget {
  const AgregarEstacionamientoScreen({super.key});

  @override
  State<AgregarEstacionamientoScreen> createState() => _AgregarState();
}

class _AgregarState extends State<AgregarEstacionamientoScreen> {
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _espaciosCtrl = TextEditingController(text: '10');
  final _descripcionCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController(text: '24 horas');

  LatLng? _ubicacion;
  bool _cubierto = false;
  bool _vigilancia24h = false;
  bool _accesible = false;
  bool _aceptaMotos = false;
  bool _cargando = false;
  String? _error;
  String? _fotoUrl;
  bool _subiendoFoto = false;

  Future<void> _abrirMapa() async {
    final resultado = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const _MapaSelectorScreen()),
    );
    if (resultado != null) {
      setState(() => _ubicacion = resultado);
      try {
        final placemarks = await placemarkFromCoordinates(
          resultado.latitude,
          resultado.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final partes = [
            if (p.street?.isNotEmpty == true) p.street,
            if (p.subLocality?.isNotEmpty == true) p.subLocality,
            if (p.locality?.isNotEmpty == true) p.locality,
          ];
          final dir = partes.join(', ');
          if (dir.isNotEmpty) setState(() => _direccionCtrl.text = dir);
        }
      } catch (_) {}
    }
  }

  Future<void> _subirFoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: _cyan),
              title: const Text(
                'Tomar foto',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: _cyan),
              title: const Text(
                'Galería',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final img = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (img == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('estacionamientos-fotos')
          .upload(
            path,
            File(img.path),
            fileOptions: const FileOptions(upsert: true),
          );
      final url = Supabase.instance.client.storage
          .from('estacionamientos-fotos')
          .getPublicUrl(path);
      setState(() => _fotoUrl = url);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty ||
        _direccionCtrl.text.trim().isEmpty ||
        _precioCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Llena todos los campos obligatorios.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final totalEspacios = int.tryParse(_espaciosCtrl.text.trim()) ?? 10;
      final precio = double.tryParse(_precioCtrl.text.trim()) ?? 0;

      final res = await Supabase.instance.client
          .from('estacionamientos')
          .insert({
            'propietario_id': uid,
            'nombre': _nombreCtrl.text.trim(),
            'direccion': _direccionCtrl.text.trim(),
            'descripcion': _descripcionCtrl.text.trim(),
            'horario': _horarioCtrl.text.trim(),
            'precio_por_hora': precio,
            'total_espacios': totalEspacios,
            'latitud': _ubicacion?.latitude,
            'longitud': _ubicacion?.longitude,
            'foto_url': _fotoUrl,
            'cubierto': _cubierto,
            'vigilancia_24h': _vigilancia24h,
            'accesible': _accesible,
            'acepta_motos': _aceptaMotos,
            'activo': true,
          })
          .select()
          .single();

      // Crear espacios
      final letras = ['A', 'B', 'C', 'D', 'E', 'F'];
      final espacios = <Map<String, dynamic>>[];
      int count = 0;
      for (final l in letras) {
        for (int n = 1; n <= 6; n++) {
          if (count >= totalEspacios) break;
          espacios.add({
            'estacionamiento_id': res['id'],
            'codigo': '$l$n',
            'disponible': true,
          });
          count++;
        }
        if (count >= totalEspacios) break;
      }
      await Supabase.instance.client.from('espacios').insert(espacios);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _precioCtrl.dispose();
    _espaciosCtrl.dispose();
    _descripcionCtrl.dispose();
    _horarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _cyan,
        title: const Text(
          'Nuevo estacionamiento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto del lugar
            GestureDetector(
              onTap: _subirFoto,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  image: _fotoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_fotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _subiendoFoto
                    ? const Center(
                        child: CircularProgressIndicator(color: _cyan),
                      )
                    : _fotoUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_a_photo_rounded,
                            color: _cyan,
                            size: 36,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Agregar foto del lugar',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 16,
                            child: const Icon(
                              Icons.edit,
                              color: _cyan,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            _field(
              _nombreCtrl,
              'Nombre del estacionamiento *',
              Icons.local_parking_rounded,
            ),
            const SizedBox(height: 14),

            // Dirección con botón mapa
            TextField(
              controller: _direccionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Dirección *',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: _cyan,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.map_rounded,
                    color: _ubicacion != null ? _cyan : Colors.grey,
                  ),
                  onPressed: _abrirMapa,
                ),
                filled: true,
                fillColor: _ubicacion != null ? _cyan.withOpacity(0.07) : _card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: _ubicacion != null
                      ? const BorderSide(color: _cyan, width: 1.5)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: _ubicacion != null
                      ? const BorderSide(color: _cyan, width: 1.5)
                      : BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _field(
              _descripcionCtrl,
              'Descripción del lugar (opcional)',
              Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _field(
              _horarioCtrl,
              'Horario (ej. 24 horas / 8am-10pm)',
              Icons.access_time_rounded,
            ),
            const SizedBox(height: 14),
            _field(
              _precioCtrl,
              'Precio por hora (\$) *',
              Icons.attach_money_rounded,
              type: TextInputType.number,
            ),
            const SizedBox(height: 14),
            _field(
              _espaciosCtrl,
              'Total de espacios *',
              Icons.grid_view_rounded,
              type: TextInputType.number,
            ),
            const SizedBox(height: 24),

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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _switchCaract(
                    'Cubierto',
                    Icons.roofing_rounded,
                    _cubierto,
                    (v) => setState(() => _cubierto = v),
                  ),
                  _divider(),
                  _switchCaract(
                    'Vigilancia 24h',
                    Icons.security_rounded,
                    _vigilancia24h,
                    (v) => setState(() => _vigilancia24h = v),
                  ),
                  _divider(),
                  _switchCaract(
                    'Accesible',
                    Icons.accessible_rounded,
                    _accesible,
                    (v) => setState(() => _accesible = v),
                  ),
                  _divider(),
                  _switchCaract(
                    'Acepta motos',
                    Icons.two_wheeler_rounded,
                    _aceptaMotos,
                    (v) => setState(() => _aceptaMotos = v),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _cargando ? null : _guardar,
                child: _cargando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Guardar estacionamiento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: maxLines == 1 ? Icon(icon, color: _cyan) : null,
      filled: true,
      fillColor: _card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _switchCaract(
    String label,
    IconData icon,
    bool val,
    Function(bool) onChange,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Row(
      children: [
        Icon(icon, color: _cyan, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    ),
    value: val,
    activeColor: _cyan,
    onChanged: onChange,
  );

  Widget _divider() => const Divider(color: Colors.white10, height: 1);
}

// ── Mapa selector ──────────────────────────────────────────────────────────
class _MapaSelectorScreen extends StatefulWidget {
  const _MapaSelectorScreen();
  @override
  State<_MapaSelectorScreen> createState() => _MapaSelectorState();
}

class _MapaSelectorState extends State<_MapaSelectorScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _marker;
  LatLng _camara = const LatLng(19.4326, -99.1332);
  bool _buscandoGPS = true;

  @override
  void initState() {
    super.initState();
    _irAMiUbicacion();
  }

  Future<void> _irAMiUbicacion() async {
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
        _camara = ll;
        _buscandoGPS = false;
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 16));
    } catch (_) {
      setState(() => _buscandoGPS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1218),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF00FFE0),
        title: const Text(
          'Selecciona la ubicación',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_marker != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _marker),
              child: const Text(
                'Confirmar',
                style: TextStyle(
                  color: Color(0xFF00FFE0),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _camara, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _mapCtrl = c,
            onTap: (ll) => setState(() => _marker = ll),
            markers: _marker != null
                ? {
                    Marker(
                      markerId: const MarkerId('sel'),
                      position: _marker!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  }
                : {},
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    color: Color(0xFF00FFE0),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _marker == null
                        ? 'Toca el mapa para marcar tu estacionamiento'
                        : 'Toca "Confirmar" para guardar',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF00FFE0),
              foregroundColor: Colors.black,
              mini: true,
              onPressed: _irAMiUbicacion,
              child: _buscandoGPS
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
