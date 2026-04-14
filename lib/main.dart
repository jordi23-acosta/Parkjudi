import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantallas/onboarding.dart';
import 'pantallas/pantallaPrincipal.dart';
import 'pantallas/propietario/pantalla_propietario.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ffehaehakpwxxisjvqfp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZWhhZWhha3B3eHhpc2p2cWZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDExMDIsImV4cCI6MjA5MTY3NzEwMn0.7wmnXyugaUsfiMhZ4Ppy8tLO5GuCh67XIu8ViovS_ls',
  );
  runApp(const MiAppEstacionamiento());
}

class MiAppEstacionamiento extends StatelessWidget {
  const MiAppEstacionamiento({super.key});

  Future<Widget> _getPantallaInicial() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const OnboardingScreen();

    try {
      final perfil = await Supabase.instance.client
          .from('perfiles')
          .select('rol')
          .eq('id', session.user.id)
          .maybeSingle();

      final rol = perfil?['rol'] ?? 'conductor';
      if (rol == 'propietario') return const PantallaPropietario();
      return const PantallaPrincipal();
    } catch (_) {
      return const OnboardingScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkjudi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FFE0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<Widget>(
        future: _getPantallaInicial(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F1218),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF00FFE0)),
              ),
            );
          }
          return snapshot.data ?? const OnboardingScreen();
        },
      ),
    );
  }
}
