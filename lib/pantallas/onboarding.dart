import 'package:flutter/material.dart';
import 'Login.dart';
import 'Registro.dart';

const Color _cyan = Color(0xFF00FFE0);
const Color _bg = Color(0xFF0F1218);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _paginaActual = 0;

  final List<_SlideData> _slides = [
    _SlideData(
      imagen: 'assets/images/slide1.png',
      titulo: 'Encuentra.\nReserva.\nEstaciona.',
      subtitulo: 'Localiza lugares disponibles cerca de ti en tiempo real.',
    ),
    _SlideData(
      imagen: 'assets/images/slide2.png',
      titulo: 'Elige tu\nespacio.',
      subtitulo: 'Selecciona el lugar exacto que quieres antes de llegar.',
    ),
    _SlideData(
      imagen: 'assets/images/slide3.png',
      titulo: 'Tu ticket\ndigital.',
      subtitulo: 'Accede con un QR. Sin filas, sin papeles, sin estrés.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Slides ──────────────────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _paginaActual = i),
            itemBuilder: (_, i) => _buildSlide(_slides[i]),
          ),

          // ── Indicadores ─────────────────────────────────────────────────
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _paginaActual == i ? 24 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _paginaActual == i ? _cyan : Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // ── Botones fijos abajo ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                        child: const Text(
                          'Iniciar sesión',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegistroScreen(),
                          ),
                        ),
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_SlideData slide) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagen de fondo
        Image.asset(slide.imagen, fit: BoxFit.cover),

        // Gradiente oscuro encima (más denso abajo como Sonaris)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.95),
                Colors.black,
              ],
              stops: const [0.0, 0.4, 0.75, 1.0],
            ),
          ),
        ),

        // Texto en la parte inferior
        Positioned(
          bottom: 160,
          left: 28,
          right: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre de la app
              const Text(
                'PARKJUDI',
                style: TextStyle(
                  color: _cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slide.titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                slide.subtitulo,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlideData {
  final String imagen;
  final String titulo;
  final String subtitulo;
  const _SlideData({
    required this.imagen,
    required this.titulo,
    required this.subtitulo,
  });
}
