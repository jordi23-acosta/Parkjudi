import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pantallas/notificaciones.dart';

const Color _cyan = Color(0xFF00FFE0);

class NotifBadge extends StatefulWidget {
  const NotifBadge({super.key});

  @override
  State<NotifBadge> createState() => _NotifBadgeState();
}

class _NotifBadgeState extends State<NotifBadge> {
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Escuchar cambios en tiempo real
    Supabase.instance.client
        .from('notificaciones')
        .stream(primaryKey: ['id'])
        .listen((_) => _cargar());
  }

  Future<void> _cargar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final data = await Supabase.instance.client
        .from('notificaciones')
        .select('id')
        .eq('usuario_id', uid)
        .eq('leida', false);
    if (mounted) setState(() => _noLeidas = (data as List).length);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
            );
            _cargar();
          },
        ),
        if (_noLeidas > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: _cyan,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _noLeidas > 9 ? '9+' : '$_noLeidas',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
