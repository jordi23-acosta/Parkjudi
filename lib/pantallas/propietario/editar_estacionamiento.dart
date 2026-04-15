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

class EditarEstacionamientoScreen extends StatefulWidget {
  final Map<String, dynamic> estacionamiento;
  const EditarEstacionamientoScreen({super.key, required this.estacionamiento});

  @override
  State<EditarEstacionamientoScreen> createState() => _EditarState();
}

class _EditarState extends State<EditarEstacionamientoScreen> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _descripcionCtrl;
  late TextEditingController _horarioCtrl;

  LatLng? _ubicacion;
  bool _cubierto = false;
  bool _vigilancia24h = false;
  bool _accesible = false;
  bool _aceptaMotos = false;
  int _tiempoGracia = 30;
  String? _fotoUrl;
  bool _subiendoFoto = false;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.estacionamiento;
    _nombreCtrl = TextEditingController(text: e['nombre'] ?? '');
    _direccionCtrl = TextEditingController(text: e['direccion'] ?? '');
    _precioCtrl = TextEditingController(
      text: e['precio_por_hora']?.toString() ?? '',
    );
    _descripcionCtrl = TextEditingController(text: e['descripcion'] ?? '');
    _horarioCtrl = TextEditingController(text: e['horario'] ?? '24 horas');
    _cubierto = e['cubierto'] ?? false;
    _vigilancia24h = e['vigilancia_24h'] ?? false;
    _accesible = e['accesible'] ?? false;
    _aceptaMotos = e['acepta_motos'] ?? false;
    _tiempoGracia = e['tiempo_gracia_minutos'] ?? 30;
    _fotoUrl = e['foto_url'];
    if (e['latitud'] != null && e['longitud'] != null) {
      _ubicacion = LatLng(e['latitud'], e['longitud']);
    }
  }

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
    if (_nombreCtrl.text.trim().isEmpty || _precioCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nombre y precio son obligatorios.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await Supabase.instance.client
          .from('estacionamientos')
          .update({
            'nombre': _nombreCtrl.text.trim(),
            'direccion': _direccionCtrl.text.trim(),
            'descripcion': _descripcionCtrl.text.trim(),
            'horario': _horarioCtrl.text.trim(),
            'precio_por_hora': double.tryParse(_precioCtrl.text.trim()) ?? 0,
            'latitud': _ubicacion?.latitude,
            'longitud': _ubicacion?.longitude,
            'foto_url': _fotoUrl,
            'cubierto': _cubierto,
            'vigilancia_24h': _vigilancia24h,
            'accesible': _accesible,
            'acepta_motos': _aceptaMotos,
            'tiempo_gracia_minutos': _tiempoGracia,
          })
          .eq('id', widget.estacionamiento['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('¿Eliminar?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client
        .from('estacionamientos')
        .delete()
        .eq('id', widget.estacionamiento['id']);
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _precioCtrl.dispose();
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
          'Editar estacionamiento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _eliminar,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto
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
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                    : const Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 16,
                            child: Icon(Icons.edit, color: _cyan, size: 16),
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

            // Dirección con mapa
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
              'Descripción (opcional)',
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
                  const Divider(color: Colors.white10, height: 1),
                  _switchCaract(
                    'Vigilancia 24h',
                    Icons.security_rounded,
                    _vigilancia24h,
                    (v) => setState(() => _vigilancia24h = v),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _switchCaract(
                    'Accesible',
                    Icons.accessible_rounded,
                    _accesible,
                    (v) => setState(() => _accesible = v),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _switchCaract(
                    'Acepta motos',
                    Icons.two_wheeler_rounded,
                    _aceptaMotos,
                    (v) => setState(() => _aceptaMotos = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tiempo de gracia
            const Text(
              'TIEMPO DE GRACIA',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Si el conductor no llega en este tiempo, la reserva se cancela.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.timer_outlined, color: _cyan, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Límite de llegada',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: _tiempoGracia,
                    dropdownColor: _card,
                    underline: const SizedBox(),
                    items: [15, 30, 45, 60, 90, 120]
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m < 60 ? '$m min' : '${m ~/ 60}h',
                              style: const TextStyle(
                                color: _cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _tiempoGracia = v ?? 30),
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
                        'Guardar cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
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
    activeThumbColor: _cyan,
    onChanged: onChange,
  );
}

// ── Mapa selector (reutilizado) ────────────────────────────────────────────
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _cyan,
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
                  color: _cyan,
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
                  const Icon(Icons.touch_app_rounded, color: _cyan, size: 18),
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
              backgroundColor: _cyan,
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
