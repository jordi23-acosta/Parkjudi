import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _card = Color(0xFF1F252F);

class EscanerQrScreen extends StatefulWidget {
  const EscanerQrScreen({super.key});

  @override
  State<EscanerQrScreen> createState() => _EscanerQrScreenState();
}

class _EscanerQrScreenState extends State<EscanerQrScreen> {
  bool _escaneando = true;
  bool _procesando = false;

  void _onDetect(BarcodeCapture capture) async {
    if (!_escaneando || _procesando) return;
    final codigo = capture.barcodes.firstOrNull?.rawValue;
    if (codigo == null) return;

    setState(() {
      _escaneando = false;
      _procesando = true;
    });

    try {
      final reserva = await Supabase.instance.client
          .from('reservaciones')
          .select(
            '*, perfiles(nombre), espacios(codigo), estacionamientos(nombre)',
          )
          .eq('id', codigo)
          .maybeSingle();

      if (!mounted) return;

      if (reserva == null) {
        _mostrarResultado(
          context,
          esValido: false,
          mensaje: 'Reservación no encontrada',
        );
        return;
      }
      _mostrarResultado(context, esValido: true, reserva: reserva);
    } catch (e) {
      if (mounted) {
        _mostrarResultado(
          context,
          esValido: false,
          mensaje: 'Error al verificar: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _mostrarResultado(
    BuildContext context, {
    required bool esValido,
    Map<String, dynamic>? reserva,
    String? mensaje,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ResultadoSheet(
        esValido: esValido,
        reserva: reserva,
        mensaje: mensaje,
        onCerrar: () {
          Navigator.pop(context);
          setState(() => _escaneando = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _cyan,
        title: const Text(
          'Escanear QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: _cyan, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_procesando)
                  const CircularProgressIndicator(color: _cyan)
                else
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: _cyan,
                    size: 32,
                  ),
                const SizedBox(height: 12),
                Text(
                  _procesando ? 'Verificando...' : 'Apunta al QR del conductor',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resultado del escaneo ──────────────────────────────────────────────────
class _ResultadoSheet extends StatefulWidget {
  final bool esValido;
  final Map<String, dynamic>? reserva;
  final String? mensaje;
  final VoidCallback onCerrar;

  const _ResultadoSheet({
    required this.esValido,
    required this.onCerrar,
    this.reserva,
    this.mensaje,
  });

  @override
  State<_ResultadoSheet> createState() => _ResultadoSheetState();
}

class _ResultadoSheetState extends State<_ResultadoSheet> {
  bool _cobrando = false;

  Future<void> _cobrar() async {
    setState(() => _cobrando = true);
    try {
      final reservaId = widget.reserva!['id'];
      final espacioId = widget.reserva!['espacio_id'];
      final horas = widget.reserva!['horas'] as int? ?? 1;
      final ahora = DateTime.now();
      final finReal = ahora.add(Duration(hours: horas));

      // Guardar inicio_real y fin_real — el tiempo empieza AHORA
      await Supabase.instance.client
          .from('reservaciones')
          .update({
            'estado': 'activa',
            'inicio_real': ahora.toIso8601String(),
            'fin_estimado': finReal.toIso8601String(),
          })
          .eq('id', reservaId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Entrada confirmada! El tiempo ha comenzado.'),
            backgroundColor: _cyan,
          ),
        );
        widget.onCerrar();
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
      if (mounted) setState(() => _cobrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reserva = widget.reserva;
    final esValido = widget.esValido;
    final estado = reserva?['estado'] ?? '';
    final fin = DateTime.tryParse(reserva?['fin_estimado'] ?? '');
    final vencida = fin != null && fin.isBefore(DateTime.now());
    final esEfectivo = reserva?['metodo_pago'] == 'efectivo';
    final esTransferencia = reserva?['metodo_pago'] == 'transferencia';
    final puedesCobrar =
        esValido &&
        !vencida &&
        estado == 'activa' &&
        (esEfectivo || esTransferencia);

    final color = !esValido || vencida
        ? Colors.red
        : estado == 'activa'
        ? _cyan
        : Colors.green;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              esValido && !vencida ? Icons.check_rounded : Icons.close_rounded,
              color: color,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            !esValido
                ? 'QR Inválido'
                : vencida
                ? 'Reserva vencida'
                : estado == 'activa'
                ? 'Reserva válida ✓'
                : 'Reserva $estado',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),

          if (reserva != null) ...[
            _fila('Conductor', reserva['perfiles']?['nombre'] ?? 'N/A'),
            _fila(
              'Estacionamiento',
              reserva['estacionamientos']?['nombre'] ?? 'N/A',
            ),
            _fila('Espacio', reserva['espacios']?['codigo'] ?? 'N/A'),
            _fila('Horas', '${reserva['horas']}h'),
            _fila('Total', '\$${reserva['precio_total']}'),
            _fila(
              'Pago',
              reserva['metodo_pago'] == 'efectivo'
                  ? '💵 Efectivo (pendiente)'
                  : '🏦 Transferencia — verifica en tu banco',
            ),
            if (fin != null)
              _fila('Válido hasta', DateFormat('HH:mm dd/MM').format(fin)),
          ] else
            Text(
              widget.mensaje ?? 'Error desconocido',
              style: const TextStyle(color: Colors.grey),
            ),

          const SizedBox(height: 20),

          // Botón cobrar efectivo
          if (puedesCobrar) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _cobrando ? null : _cobrar,
                icon: _cobrando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.payments_rounded),
                label: Text(
                  _cobrando
                      ? 'Registrando...'
                      : 'Cobrar \$${reserva?['precio_total']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.white12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: widget.onCerrar,
              child: const Text('Escanear otro'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
