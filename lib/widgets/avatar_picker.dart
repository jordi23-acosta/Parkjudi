import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);

class AvatarPicker extends StatefulWidget {
  final String nombre;
  final String? avatarUrl;
  final double radius;
  final Function(String url)? onUploaded;

  const AvatarPicker({
    super.key,
    required this.nombre,
    this.avatarUrl,
    this.radius = 50,
    this.onUploaded,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _subiendo = false;
  String? _urlActual;

  @override
  void initState() {
    super.initState();
    _urlActual = widget.avatarUrl;
  }

  @override
  void didUpdateWidget(AvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      setState(() => _urlActual = widget.avatarUrl);
    }
  }

  Future<void> _seleccionar(ImageSource source) async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (imagen == null) return;

    setState(() => _subiendo = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final ext = imagen.path.split('.').last;
      final path = '$uid/avatar.$ext';
      final file = File(imagen.path);

      await Supabase.instance.client.storage
          .from('avatars')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      // Agregar timestamp para evitar caché
      final urlConCache = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client
          .from('perfiles')
          .update({'avatar_url': url}) // guardamos sin timestamp
          .eq('id', uid);

      setState(() => _urlActual = urlConCache); // mostramos con timestamp
      widget.onUploaded?.call(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F252F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Foto de perfil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: _cyan),
              title: const Text(
                'Tomar foto',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _seleccionar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: _cyan),
              title: const Text(
                'Elegir de galería',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _seleccionar(ImageSource.gallery);
              },
            ),
            if (_urlActual != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Eliminar foto',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _eliminar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminar() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client
        .from('perfiles')
        .update({'avatar_url': null})
        .eq('id', uid);
    setState(() => _urlActual = null);
    widget.onUploaded?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _mostrarOpciones,
      child: Stack(
        children: [
          // Avatar
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: _cyan,
            backgroundImage: _urlActual != null && _urlActual!.isNotEmpty
                ? NetworkImage(_urlActual!)
                : null,
            child: _urlActual == null || _urlActual!.isEmpty
                ? Text(
                    widget.nombre.isNotEmpty
                        ? widget.nombre[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: widget.radius * 0.8,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  )
                : null,
          ),

          // Indicador de carga
          if (_subiendo)
            Positioned.fill(
              child: CircleAvatar(
                radius: widget.radius,
                backgroundColor: Colors.black54,
                child: const CircularProgressIndicator(
                  color: _cyan,
                  strokeWidth: 2,
                ),
              ),
            ),

          // Botón de editar
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _cyan,
                shape: BoxShape.circle,
                border: Border.all(color: _bg, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.black,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
