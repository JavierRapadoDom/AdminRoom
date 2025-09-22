import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'router.dart';

class AdminRoomApp extends StatelessWidget {
  const AdminRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    final seed = const Color(0xFFE3A62F); // dorado ChillRoom

    final light = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: Brightness.light,
      visualDensity: VisualDensity.comfortable,
    );

    final dark = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.comfortable,
    );

    return MaterialApp.router(
      title: 'AdminRoom',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 599, name: MOBILE),
          Breakpoint(start: 600, end: 1023, name: TABLET),
          Breakpoint(start: 1024, end: 1919, name: DESKTOP),
          Breakpoint(start: 1920, end: double.infinity, name: '4K'),
        ],
      ),
    );
  }
}
