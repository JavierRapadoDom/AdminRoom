import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/dashboard_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth > 1400 ? 4 : c.maxWidth > 1000 ? 3 : 2;
          return GridView.count(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              DashboardCard(
                title: 'Usuarios',
                subtitle: 'Banear, buscar y ver perfiles',
                icon: Icons.person_outline,
                onTap: () {
                  context.go('/users'); // la añadiremos en el siguiente paso
                },
              ),
              DashboardCard(
                title: 'Reportes',
                subtitle: 'Leer y resolver casos',
                icon: Icons.report_outlined,
                onTap: () {
                  context.go('/reports'); // la añadiremos en el siguiente paso
                },
              ),
              DashboardCard(
                title: 'Fotos',
                subtitle: 'Moderación y aprobación',
                icon: Icons.image_outlined,
                onTap: () {},
              ),
              DashboardCard(
                title: 'Promociones',
                subtitle: 'Descuentos y packs',
                icon: Icons.local_offer_outlined,
                onTap: () {},
              ),
            ],
          );
        },
      ),
    );
  }
}
