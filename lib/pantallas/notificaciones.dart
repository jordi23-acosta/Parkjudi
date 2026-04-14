import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client
        .from('notificaciones')
        .select()
        .eq('usuario_id', uid)
        .order('created_at', ascending: false);
    setState(() {
      _notifs = List<Map<String, dynamic>>.from(data);
      _cargando = false;
    });
    // Marcar todas como leídas
    await Supabase.instance.client
        .from('notificaciones')
        .update({'leida': true})
        .eq('usuario_id', uid)
        .eq('leida', false);
  }

  Future<void> _eliminarTodas() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client
        .from('notificaciones')
        .delete()
        .eq('usuario_id', uid);
    setState(() => _notifs = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _cyan,
        title: const Text(
          'Notificaciones',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_notifs.isNotEmpty)
            TextButton(
              onPressed: _eliminarTodas,
              child: const Text(
                'Limpiar',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : RefreshIndicator(
              color: _cyan,
              onRefresh: _cargar,
              child: _notifs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.grey,
                            size: 60,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Sin notificaciones',
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifs.length,
                      itemBuilder: (_, i) => _buildItem(_notifs[i]),
                    ),
            ),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final leida = n['leida'] == true;
    final tipo = n['tipo'] ?? 'info';
    final fecha = DateTime.tryParse(n['created_at'] ?? '');
    final color = _colorTipo(tipo);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: leida ? _card : _card.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: leida ? Colors.transparent : color.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconTipo(tipo), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      n['titulo'] ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: leida ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (!leida)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n['mensaje'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                if (fecha != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatFecha(fecha),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'reserva':
        return _cyan;
      case 'vencimiento':
        return Colors.orange;
      case 'pago':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _iconTipo(String tipo) {
    switch (tipo) {
      case 'reserva':
        return Icons.local_parking_rounded;
      case 'vencimiento':
        return Icons.timer_outlined;
      case 'pago':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diff = ahora.difference(fecha);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}
