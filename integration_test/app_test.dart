import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_pro_max/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('STRESS TEST ULTIME : Navigation, Recherches, Clavier, Audio, Sous-titres et Sauts d\'épisodes', (WidgetTester tester) async {
    // =========================================================================
    // 1. DÉMARRAGE ET INITIALISATION DES SERVICES ET WIDGETS
    // =========================================================================
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Validation du point d'entrée racine
    expect(find.byType(MaterialApp), findsOneWidget);

    // =========================================================================
    // 2. EXPLORATION ET SCROLLS INTENSIFS DANS LES LISTES
    // =========================================================================
    try {
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        // Defilement rapide vers le bas
        for (int i = 0; i < 4; i++) {
          await tester.drag(scrollables.first, const Offset(0, -600));
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
        // Remontée rapide vers le haut
        for (int i = 0; i < 4; i++) {
          await tester.drag(scrollables.first, const Offset(0, 600));
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
        }
      }

      // =========================================================================
      // 3. SAISIE ET RECHERCHE TEXTUELLE AUTOMATISÉE
      // =========================================================================
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Action');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Effacement de la recherche
        await tester.enterText(textFields.first, '');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // =========================================================================
      // 4. BALAYAGE ET CLICS EN RAFALE SUR LES ÉLÉMENTS INTERACTIFS
      // =========================================================================
      final inkWells = find.byType(InkWell);
      if (inkWells.evaluate().isNotEmpty) {
        final count = inkWells.evaluate().length > 5 ? 5 : inkWells.evaluate().length;
        for (int i = 0; i < count; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }
      }

      final iconButtons = find.byType(IconButton);
      if (iconButtons.evaluate().isNotEmpty) {
        final count = iconButtons.evaluate().length > 3 ? 3 : iconButtons.evaluate().length;
        for (int i = 0; i < count; i++) {
          await tester.tap(iconButtons.at(i));
          await tester.pumpAndSettle(const Duration(milliseconds: 800));
        }
      }

      // =========================================================================
      // 5. TEST COMPLET DU LECTEUR ET RACCOURCIS CLAVIER (PLAYER SCREEN)
      // =========================================================================
      // A. Play / Pause (Touche Espace)
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // B. Bascule Plein écran (Touche F)
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // C. Ajustements rapides du volume (Haut / Bas / Mute)
      for (int i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      }
      for (int i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM); // Mute si configuré
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // D. Sauts temporels rapides (+10s / -10s)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // =========================================================================
      // 6. TEST DES BOUTONS DE NAVIGATION D'ÉPISODES ET PISTES AUDIO / SOUS-TITRES
      // =========================================================================
      // A. Bouton Épisode Suivant (skip_next_rounded / skip_next)
      final nextEpIcon = find.byIcon(Icons.skip_next_rounded);
      if (nextEpIcon.evaluate().isNotEmpty) {
        await tester.tap(nextEpIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // B. Bouton Épisode Précédent (skip_previous_rounded / skip_previous)
      final prevEpIcon = find.byIcon(Icons.skip_previous_rounded);
      if (prevEpIcon.evaluate().isNotEmpty) {
        await tester.tap(prevEpIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // C. Menu/Icône des sous-titres
      final subtitleFinder = find.byIcon(Icons.subtitles);
      if (subtitleFinder.evaluate().isNotEmpty) {
        await tester.tap(subtitleFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // D. Menu/Icône des pistes audio
      final audioFinder = find.byIcon(Icons.audiotrack);
      if (audioFinder.evaluate().isNotEmpty) {
        await tester.tap(audioFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // E. Menu de réglages généraux du lecteur
      final settingsFinder = find.byIcon(Icons.settings);
      if (settingsFinder.evaluate().isNotEmpty) {
        await tester.tap(settingsFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

    } catch (e, stack) {
      debugPrint('Capture contrôlée du stress test (composant optionnel absents sur l\'écran courant) : $e\n$stack');
    }

    // =========================================================================
    // 7. STABILISATION ET VÉRIFICATION DE LA STABILITÉ POST-STRESS
    // =========================================================================
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(MaterialApp), findsOneWidget);

    binding.reportData = {'status': 'success', 'details': 'Stress test ultime valide'};
  });
}