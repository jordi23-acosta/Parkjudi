import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);

class ConfirmarReservaScreen extends StatefulWidget {
  final String nombreEstacionamiento;
  final String direccion;
  final String espacioSeleccionado;
  final String espacioId;
  final String estacionamientoId;
  final String propietarioId;
  final double precioPorHora;

  const ConfirmarReservaScreen({
    super.key,
    required this.nombreEstacionamiento,
    required this.direccion,
    required this.espacioSeleccionado,
    required this.espacioId,
    required this.estacionamientoId,
    required this.propietarioId,
    required this.precioPorHora,
  });

  @override
  State<ConfirmarReservaScreen> createState() => _ConfirmarReservaScreenState();
}

class _ConfirmarReservaScreenState extends State<ConfirmarReservaScreen> {
  int _horas = 2;
  String _metodoPago = 'efectivo';
  bool _procesando = false;
  bool _cargandoCobro = true;
  String? _error;
  int _tiempoGracia = 30; // minutos

  // Datos de cobro del propietario
  String _metodoCobro = 'efectivo';
  String _titular = '';
  String _cuenta = '';
  String _banco = '';

  String _formatHora(DateTime dt) => DateFormat.Hm().format(dt);
  double get _subtotal => widget.precioPorHora * _horas;

  @override
  void initState() {
    super.initState();
    _cargarDatosCobro();
  }

  Future<void> _cargarDatosCobro() async {
    try {
      final data = await Supabase.instance.client
          .from('perfiles')
          .select('metodo_cobro, titular_cuenta, numero_cuenta, banco')
          .eq('id', widget.propietarioId)
          .maybeSingle();

      final est = await Supabase.instance.client
          .from('estacionamientos')
          .select('tiempo_gracia_minutos')
          .eq('id', widget.estacionamientoId)
          .maybeSingle();

      setState(() {
        _metodoCobro = data?['metodo_cobro'] ?? 'efectivo';
        _titular = data?['titular_cuenta'] ?? '';
        _cuenta = data?['numero_cuenta'] ?? '';
        _banco = data?['banco'] ?? '';
        _metodoPago = _metodoCobro;
        _tiempoGracia = est?['tiempo_gracia_minutos'] ?? 30;
        _cargandoCobro = false;
      });
    } catch (_) {
      setState(() => _cargandoCobro = false);
    }
  }

  Future<void> _confirmarReserva() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final ahora = DateTime.now();
      final finEstimado = ahora.add(Duration(hours: _horas));

      await Supabase.instance.client
          .from('espacios')
          .update({
            'disponible': false,
            'reservado_hasta': null,
            'reservado_por': null,
          })
          .eq('id', widget.espacioId);

      final reserva = await Supabase.instance.client
          .from('reservaciones')
          .insert({
            'conductor_id': uid,
            'espacio_id': widget.espacioId,
            'estacionamiento_id': widget.estacionamientoId,
            'horas': _horas,
            'precio_total': _subtotal,
            'estado': 'activa',
            'metodo_pago': _metodoPago,
            'fin_estimado': finEstimado.toIso8601String(),
            'expira_llegada': ahora
                .add(Duration(minutes: _tiempoGracia))
                .toIso8601String(),
          })
          .select()
          .single();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TicketScreen(
              reservacionId: reserva['id'],
              nombre: widget.nombreEstacionamiento,
              espacio: widget.espacioSeleccionado,
              horas: _horas,
              total: _subtotal,
              finEstimado: finEstimado,
              metodoPago: _metodoPago,
              titular: _titular,
              cuenta: _cuenta,
              banco: _banco,
              tiempoGracia: _tiempoGracia,
              expiraLlegada: ahora.add(Duration(minutes: _tiempoGracia)),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Error al procesar: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final fin = ahora.add(Duration(hours: _horas));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _cyan,
        title: const Text(
          'Confirmar reserva',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _cargandoCobro
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen
                  _seccion(
                    'RESUMEN',
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          _fila(
                            'Estacionamiento',
                            '${widget.nombreEstacionamiento} — ${widget.espacioSeleccionado}',
                          ),
                          _fila('Dirección', widget.direccion),
                          _fila(
                            'Espacio',
                            widget.espacioSeleccionado,
                            color: _cyan,
                          ),
                          _fila(
                            'Precio',
                            '\$${widget.precioPorHora.toStringAsFixed(0)}/hr',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Duración
                  _seccion(
                    'DURACIÓN',
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [1, 2, 3, 4, 6, 8].map(_chipHora).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tiempo y total
                  _seccion(
                    'TIEMPO',
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          _fila('Inicio', 'Ahora • ${_formatHora(ahora)}'),
                          _fila('Fin estimado', _formatHora(fin)),
                          const Divider(color: Colors.white12, height: 24),
                          _fila(
                            'Total',
                            '\$${_subtotal.toStringAsFixed(2)}',
                            color: _cyan,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Método de pago
                  _seccion(
                    'MÉTODO DE PAGO',
                    Column(
                      children: [
                        // Solo mostrar los métodos que acepta el propietario
                        if (_metodoCobro == 'efectivo' ||
                            _metodoCobro == 'transferencia')
                          Row(
                            children: [
                              if (_metodoCobro == 'efectivo' ||
                                  _metodoCobro == 'transferencia')
                                Expanded(
                                  child: _chipPago(
                                    'efectivo',
                                    Icons.payments_rounded,
                                    'Efectivo',
                                  ),
                                ),
                              if (_metodoCobro == 'transferencia') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _chipPago(
                                    'transferencia',
                                    Icons.account_balance_rounded,
                                    'Transferencia',
                                  ),
                                ),
                              ],
                            ],
                          ),

                        const SizedBox(height: 14),

                        // Info según método seleccionado
                        if (_metodoPago == 'efectivo')
                          _infoBox(
                            Icons.payments_rounded,
                            Colors.orange,
                            'Pago en efectivo',
                            'Paga al propietario al llegar. Muestra tu QR para confirmar.',
                          ),

                        if (_metodoPago == 'transferencia') ...[
                          _infoBox(
                            Icons.account_balance_rounded,
                            _cyan,
                            'Transferencia bancaria',
                            'Realiza la transferencia ANTES de llegar. '
                                'El propietario verificará el pago al escanear tu QR.',
                          ),
                          const SizedBox(height: 12),
                          // Datos bancarios del propietario
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _cyan.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DATOS PARA TRANSFERIR',
                                  style: TextStyle(
                                    color: _cyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_titular.isNotEmpty)
                                  _datosBancarios('Titular', _titular),
                                if (_cuenta.isNotEmpty)
                                  _datosBancarios('CLABE / Cuenta', _cuenta),
                                if (_banco.isNotEmpty)
                                  _datosBancarios('Banco', _banco),
                                _datosBancarios(
                                  'Monto',
                                  '\$${_subtotal.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

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
                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: _procesando ? null : _confirmarReserva,
            child: _procesando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _metodoPago == 'transferencia'
                        ? 'Ya transferí — Confirmar reserva'
                        : 'Reservar — \$${_subtotal.toStringAsFixed(2)} en efectivo',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _seccion(String titulo, Widget contenido) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 10),
      contenido,
    ],
  );

  Widget _fila(
    String label,
    String valor, {
    Color color = Colors.white,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _datosBancarios(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: SelectableText(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoBox(IconData icon, Color color, String titulo, String msg) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg,
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _chipHora(int h) {
    final sel = _horas == h;
    return GestureDetector(
      onTap: () => setState(() => _horas = h),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _cyan.withOpacity(0.15) : _card,
          border: Border.all(color: sel ? _cyan : Colors.white12, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${h}h',
          style: TextStyle(
            color: sel ? _cyan : Colors.grey,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _chipPago(String tipo, IconData icon, String label) {
    final sel = _metodoPago == tipo;
    return GestureDetector(
      onTap: () => setState(() => _metodoPago = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? _cyan.withOpacity(0.1) : _card,
          border: Border.all(color: sel ? _cyan : Colors.white12, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: sel ? _cyan : Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: sel ? _cyan : Colors.grey,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ticket con QR ──────────────────────────────────────────────────────────
class TicketScreen extends StatelessWidget {
  final String reservacionId;
  final String nombre;
  final String espacio;
  final int horas;
  final double total;
  final DateTime finEstimado;
  final String metodoPago;
  final String titular;
  final String cuenta;
  final String banco;
  final int tiempoGracia;
  final DateTime? expiraLlegada;

  const TicketScreen({
    super.key,
    required this.reservacionId,
    required this.nombre,
    required this.espacio,
    required this.horas,
    required this.total,
    required this.finEstimado,
    required this.metodoPago,
    this.titular = '',
    this.cuenta = '',
    this.banco = '',
    this.tiempoGracia = 30,
    this.expiraLlegada,
  });

  @override
  Widget build(BuildContext context) {
    final esTransferencia = metodoPago == 'transferencia';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cyan.withOpacity(0.1),
                  border: Border.all(color: _cyan, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: _cyan, size: 44),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡Reserva confirmada!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                esTransferencia
                    ? 'Muestra este QR — el propietario verificará tu transferencia'
                    : 'Muestra este QR al llegar y paga en efectivo',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cyan.withOpacity(0.3), width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Espacio $espacio',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: reservacionId,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${reservacionId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const Divider(color: Colors.white12, height: 28),
                    _fila('Duración', '${horas}h'),
                    _fila('Total', '\$${total.toStringAsFixed(2)}'),
                    _fila(
                      'Válido hasta',
                      DateFormat('HH:mm').format(finEstimado),
                    ),
                    _fila(
                      'Pago',
                      esTransferencia
                          ? '🏦 Transferencia'
                          : '💵 Efectivo al llegar',
                    ),
                  ],
                ),
              ),

              // Recordatorio de transferencia
              if (esTransferencia) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Recuerda: debes haber realizado la transferencia '
                          'ANTES de llegar. El propietario verificará el pago '
                          'al escanear tu QR.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Aviso de tiempo de gracia
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cyan.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: _cyan,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tienes $tiempoGracia minutos para llegar al estacionamiento'
                        '${expiraLlegada != null ? ' (antes de las ${DateFormat.Hm().format(expiraLlegada!)})' : ''}. '
                        'Si no llegas a tiempo, tu reserva se cancelará automáticamente.',
                        style: const TextStyle(color: _cyan, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
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
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text(
                    'Volver al inicio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
