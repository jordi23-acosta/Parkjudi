import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);

class MetodoCobroScreen extends StatefulWidget {
  const MetodoCobroScreen({super.key});

  @override
  State<MetodoCobroScreen> createState() => _MetodoCobroScreenState();
}

class _MetodoCobroScreenState extends State<MetodoCobroScreen> {
  String _metodo = 'efectivo';
  final _titularCtrl = TextEditingController();
  final _cuentaCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final data = await Supabase.instance.client
        .from('perfiles')
        .select('metodo_cobro, numero_cuenta, banco, titular_cuenta')
        .eq('id', uid)
        .maybeSingle();
    setState(() {
      _metodo = data?['metodo_cobro'] ?? 'efectivo';
      _titularCtrl.text = data?['titular_cuenta'] ?? '';
      _cuentaCtrl.text = data?['numero_cuenta'] ?? '';
      _bancoCtrl.text = data?['banco'] ?? '';
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (_metodo != 'efectivo') {
      if (_titularCtrl.text.trim().isEmpty || _cuentaCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Llena los campos obligatorios.');
        return;
      }
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('perfiles')
          .update({
            'metodo_cobro': _metodo,
            'titular_cuenta': _titularCtrl.text.trim(),
            'numero_cuenta': _cuentaCtrl.text.trim(),
            'banco': _bancoCtrl.text.trim(),
          })
          .eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos de cobro guardados'),
            backgroundColor: _cyan,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _titularCtrl.dispose();
    _cuentaCtrl.dispose();
    _bancoCtrl.dispose();
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
          'Método de cobro',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cyan.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: _cyan, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Estos datos se mostrarán al conductor para que pueda realizarte el pago.',
                            style: TextStyle(color: _cyan, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Selector de método
                  const Text(
                    'TIPO DE COBRO',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _chipMetodo(
                        'transferencia',
                        Icons.account_balance_rounded,
                        'Transferencia',
                      ),
                      const SizedBox(width: 10),
                      _chipMetodo(
                        'efectivo',
                        Icons.payments_rounded,
                        'Efectivo',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Campos según método
                  if (_metodo != 'efectivo') ...[
                    const Text(
                      'DATOS DE CUENTA',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      _titularCtrl,
                      'Nombre del titular *',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      _cuentaCtrl,
                      'CLABE / Número de cuenta *',
                      Icons.numbers_rounded,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      _bancoCtrl,
                      'Banco (opcional)',
                      Icons.account_balance_outlined,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El conductor pagará en efectivo al llegar al estacionamiento.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
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
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar',
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

  Widget _chipMetodo(String tipo, IconData icon, String label) {
    final sel = _metodo == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodo = tipo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? _cyan.withOpacity(0.12) : _card,
            border: Border.all(color: sel ? _cyan : Colors.white12, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: sel ? _cyan : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: sel ? _cyan : Colors.grey,
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: _cyan),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
