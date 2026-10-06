import 'package:flutter/material.dart';

/// Rute transisi kustom: geser halus + fade + scale tipis.
/// Dipakai di semua push halaman biar pindah page terasa "detail" —
/// bukan slide mentah default Flutter.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Geser masuk: dari kanan bawah sedikit, bukan full-slide
            final slide = Tween<Offset>(
              begin: const Offset(0.08, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            // Fade: cepat di awal, pelan di akhir biar nggak nunggu
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
              ),
            );

            // Scale: halaman lama menyusut tipis, baru masuk — efek kedalaman
            final scale = Tween<double>(begin: 0.98, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );

            // Halaman lama juga ikut meredup/susut — detail dua arah
            final outgoing = Tween<double>(begin: 1.0, end: 0.97).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOutCubic,
              ),
            );
            final outgoingFade = Tween<double>(begin: 1.0, end: 0.6).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
              ),
            );

            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(
                  scale: scale,
                  child: FadeTransition(
                    opacity: outgoingFade,
                    child: ScaleTransition(
                      scale: outgoing,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        );
}
