import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);

class ConfiguracionesScreen extends StatefulWidget {
  final String rol; // 'conductor' o 'propietario'
  const ConfiguracionesScreen({super.key, this.rol = 'conductor'});

  @override
  State<ConfiguracionesScreen> createState() => _ConfiguracionesScreenState();
}

class _ConfiguracionesScreenState extends State<ConfiguracionesScreen> {
  bool _notifReservas = true;
  bool _notifVencimiento = true;
  bool _notifOfertas = false;
  bool _modoOscuro = true;
  bool _guardando = false;

  final _nombreCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final perfil = await Supabase.instance.client
        .from('perfiles')
        .select(
          'nombre, placa, notif_reservas, notif_vencimiento, notif_ofertas',
        )
        .eq('id', uid)
        .maybeSingle();
    setState(() {
      _nombreCtrl.text = perfil?['nombre'] ?? '';
      _placaCtrl.text = perfil?['placa'] ?? '';
      _notifReservas = perfil?['notif_reservas'] ?? true;
      _notifVencimiento = perfil?['notif_vencimiento'] ?? true;
      _notifOfertas = perfil?['notif_ofertas'] ?? false;
      _cargando = false;
    });
  }

  Future<void> _guardarNotif(String campo, bool valor) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client
        .from('perfiles')
        .update({campo: valor})
        .eq('id', uid);
  }

  Future<void> _guardarPerfil() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('perfiles')
          .update({
            'nombre': _nombreCtrl.text.trim(),
            if (widget.rol == 'conductor') 'placa': _placaCtrl.text.trim(),
          })
          .eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: _cyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    final emailCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'Restablecer contraseña',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Te enviaremos un correo para restablecer tu contraseña.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tu correo',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (emailCtrl.text.trim().isEmpty) return;
              await Supabase.instance.client.auth.resetPasswordForEmail(
                emailCtrl.text.trim(),
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Correo enviado. Revisa tu bandeja.'),
                    backgroundColor: _cyan,
                  ),
                );
              }
            },
            child: const Text(
              'Enviar',
              style: TextStyle(color: _cyan, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarCuenta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          '¿Eliminar cuenta?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Esta acción es permanente.',
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
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esPropietario = widget.rol == 'propietario';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _cyan,
        title: const Text(
          'Configuraciones',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── CUENTA ──────────────────────────────────────────────
                _titulo('CUENTA'),
                _seccionCard([
                  _buildField(
                    _nombreCtrl,
                    'Nombre completo',
                    Icons.person_outline,
                  ),
                  if (!esPropietario) ...[
                    const SizedBox(height: 12),
                    _buildField(
                      _placaCtrl,
                      'Placa del vehículo',
                      Icons.directions_car_outlined,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _guardando ? null : _guardarPerfil,
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar cambios',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── NOTIFICACIONES ───────────────────────────────────────
                _titulo('NOTIFICACIONES'),
                _seccionCard([
                  _buildSwitch(
                    esPropietario ? 'Nuevas reservas' : 'Reserva confirmada',
                    esPropietario
                        ? 'Aviso cuando alguien reserve tu espacio'
                        : 'Aviso cuando tu reserva sea confirmada',
                    Icons.local_parking_rounded,
                    _notifReservas,
                    (v) {
                      setState(() => _notifReservas = v);
                      _guardarNotif('notif_reservas', v);
                    },
                  ),
                  _divider(),
                  _buildSwitch(
                    'Tiempo por vencer',
                    'Aviso 15 min antes de que expire la reserva',
                    Icons.timer_outlined,
                    _notifVencimiento,
                    (v) {
                      setState(() => _notifVencimiento = v);
                      _guardarNotif('notif_vencimiento', v);
                    },
                  ),
                  if (!esPropietario) ...[
                    _divider(),
                    _buildSwitch(
                      'Ofertas y novedades',
                      'Estacionamientos con descuento cerca de ti',
                      Icons.local_offer_outlined,
                      _notifOfertas,
                      (v) {
                        setState(() => _notifOfertas = v);
                        _guardarNotif('notif_ofertas', v);
                      },
                    ),
                  ],
                ]),
                const SizedBox(height: 24),

                // ── APARIENCIA ───────────────────────────────────────────
                _titulo('APARIENCIA'),
                _seccionCard([
                  _buildSwitch(
                    'Modo oscuro',
                    'Tema oscuro activado',
                    Icons.dark_mode_outlined,
                    _modoOscuro,
                    (v) => setState(() => _modoOscuro = v),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── SEGURIDAD ────────────────────────────────────────────
                _titulo('SEGURIDAD'),
                _seccionCard([
                  _buildOpcion(
                    Icons.lock_reset_rounded,
                    'Cambiar contraseña',
                    'Te enviaremos un correo',
                    Colors.orange,
                    _cambiarContrasena,
                  ),
                ]),
                const SizedBox(height: 24),

                // ── ACERCA DE ────────────────────────────────────────────
                _titulo('ACERCA DE'),
                _seccionCard([
                  _buildInfo(Icons.info_outline, 'Versión', '1.0.0'),
                ]),
                const SizedBox(height: 24),

                // ── ZONA DE PELIGRO ──────────────────────────────────────
                _titulo('ZONA DE PELIGRO'),
                _seccionCard([
                  _buildOpcion(
                    Icons.delete_forever_rounded,
                    'Eliminar cuenta',
                    'Esta acción no se puede deshacer',
                    Colors.redAccent,
                    _eliminarCuenta,
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      texto,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _seccionCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _buildField(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: _cyan, size: 20),
          filled: true,
          fillColor: _bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _buildSwitch(
    String titulo,
    String sub,
    IconData icon,
    bool valor,
    Function(bool) onChange,
  ) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _cyan.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _cyan, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
      Switch(value: valor, activeColor: _cyan, onChanged: onChange),
    ],
  );

  Widget _buildOpcion(
    IconData icon,
    String titulo,
    String sub,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
      ],
    ),
  );

  Widget _buildInfo(IconData icon, String titulo, String valor) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          titulo,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      if (valor.isNotEmpty)
        Text(valor, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ],
  );

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Divider(color: Colors.white10, height: 1),
  );
}
