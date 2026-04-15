import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);
const Color _card = Color(0xFF1F252F);

class CalificarEstacionamientoScreen extends StatefulWidget {
  final String estacionamientoId;
  final String reservacionId;
  final String nombreEstacionamiento;

  const CalificarEstacionamientoScreen({
    super.key,
    required this.estacionamientoId,
    required this.reservacionId,
    required this.nombreEstacionamiento,
  });

  @override
  State<CalificarEstacionamientoScreen> createState() => _CalificarState();
}

class _CalificarState extends State<CalificarEstacionamientoScreen> {
  double _estrellas = 5;
  final _comentarioCtrl = TextEditingController();
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('resenas').insert({
        'estacionamiento_id': widget.estacionamientoId,
        'conductor_id': uid,
        'reservacion_id': widget.reservacionId,
        'estrellas': _estrellas.toInt(),
        'comentario': _comentarioCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true); // éxito
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
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
          'Calificar estacionamiento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.star_rounded, color: Colors.amber, size: 60),
            const SizedBox(height: 16),
            Text(
              widget.nombreEstacionamiento,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '¿Cómo fue tu experiencia?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),

            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              itemCount: 5,
              itemSize: 48,
              itemBuilder: (_, _) =>
                  const Icon(Icons.star_rounded, color: Colors.amber),
              onRatingUpdate: (r) => setState(() => _estrellas = r),
            ),
            const SizedBox(height: 28),

            TextField(
              controller: _comentarioCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe un comentario (opcional)...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: _card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.white12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Omitir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _guardando ? null : _guardar,
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
                            'Enviar reseña',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
