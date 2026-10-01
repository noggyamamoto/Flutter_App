import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../score/domain/entities/expected_note.dart';
import '../../../score/domain/entities/note_comparison.dart';
import 'feedback_colors.dart';

// Painel guia (como nos apps de piano): próxima nota esperada, última nota
// tocada e um teclado com a tecla esperada (roxo) e a tocada (cor do
// feedback).
class NoteGuide extends StatelessWidget {
  final int? expectedMidi;
  final int? playedMidi;
  final NoteFeedback? playedFeedback;
  final bool compact;

  const NoteGuide({
    super.key,
    required this.expectedMidi,
    required this.playedMidi,
    required this.playedFeedback,
    this.compact = false,
  });

  // Centro do teclado: entre a nota esperada e a tocada quando estão
  // próximas, para que as duas teclas apareçam.
  int _center() {
    final expected = expectedMidi;
    final played = playedMidi;
    if (expected != null && played != null && (expected - played).abs() <= 14) {
      return (expected + played) ~/ 2;
    }
    return expected ?? played ?? 60;
  }

  @override
  Widget build(BuildContext context) {
    final playedColor = playedFeedback == null
        ? AppColors.textMuted
        : (FeedbackColors.of(playedFeedback!) ?? AppColors.textMuted);

    final labels = Row(
      children: [
        Expanded(
          child: _NoteLabel(
            caption: 'Próxima nota',
            value: expectedMidi != null ? ExpectedNote.noteName(expectedMidi!) : '—',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NoteLabel(
            caption: 'Você tocou',
            value: playedMidi != null ? ExpectedNote.noteName(playedMidi!) : '—',
            color: playedColor,
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labels,
        const SizedBox(height: 10),
        SizedBox(
          height: compact ? 54 : 72,
          child: MiniKeyboard(
            centerMidi: _center(),
            expectedMidi: expectedMidi,
            playedMidi: playedMidi,
            playedColor: playedColor,
          ),
        ),
      ],
    );
  }
}

class _NoteLabel extends StatelessWidget {
  final String caption;
  final String value;
  final Color color;

  const _NoteLabel({required this.caption, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              value,
              key: ValueKey(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Teclado de duas oitavas centrado na nota esperada.
class MiniKeyboard extends StatelessWidget {
  final int centerMidi;
  final int? expectedMidi;
  final int? playedMidi;
  final Color playedColor;

  const MiniKeyboard({
    super.key,
    required this.centerMidi,
    this.expectedMidi,
    this.playedMidi,
    this.playedColor = AppColors.correct,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Quantidade de teclas brancas conforme a largura (mín. 1 oitava).
        final whiteCount = (constraints.maxWidth / 26).floor().clamp(8, 22);
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _KeyboardPainter(
            fontFamily: DefaultTextStyle.of(context).style.fontFamily,
            firstMidi: _firstWhite(centerMidi, whiteCount),
            whiteCount: whiteCount,
            expectedMidi: expectedMidi,
            playedMidi: playedMidi,
            playedColor: playedColor,
          ),
        );
      },
    );
  }

  static const _whiteSteps = [0, 2, 4, 5, 7, 9, 11];

  static bool isWhite(int midi) => _whiteSteps.contains(midi % 12);

  // Primeira tecla branca (Dó) para que a nota fique perto do centro.
  static int _firstWhite(int center, int whiteCount) {
    var midi = center - (whiteCount ~/ 2) * 12 ~/ 7;
    while (midi % 12 != 0) {
      midi--;
    }
    return midi.clamp(21, 108);
  }
}

class _KeyboardPainter extends CustomPainter {
  final String? fontFamily;
  final int firstMidi;
  final int whiteCount;
  final int? expectedMidi;
  final int? playedMidi;
  final Color playedColor;

  _KeyboardPainter({
    required this.fontFamily,
    required this.firstMidi,
    required this.whiteCount,
    required this.expectedMidi,
    required this.playedMidi,
    required this.playedColor,
  });

  Color? _highlight(int midi) {
    if (midi == playedMidi) return playedColor;
    if (midi == expectedMidi) return AppColors.primary;
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final whiteW = size.width / whiteCount;
    final radius = Radius.circular(whiteW * 0.18);

    final whites = <int>[];
    var midi = firstMidi;
    while (whites.length < whiteCount) {
      if (MiniKeyboard.isWhite(midi)) whites.add(midi);
      midi++;
    }

    for (var i = 0; i < whites.length; i++) {
      final rect = Rect.fromLTWH(i * whiteW + 1, 0, whiteW - 2, size.height);
      final color = _highlight(whites[i]) ?? const Color(0xFFF2F1F7);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, bottomLeft: radius, bottomRight: radius),
        Paint()..color = color,
      );
      // Nome do Dó para orientação.
      if (whites[i] % 12 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: 'C${whites[i] ~/ 12 - 1}',
            style: TextStyle(
              fontFamily: fontFamily,
              color: _highlight(whites[i]) != null ? Colors.white : const Color(0xFF8A8799),
              fontSize: (whiteW * 0.38).clamp(7.0, 11.0),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, size.height - tp.height - 3));
      }
    }

    final blackW = whiteW * 0.6;
    final blackH = size.height * 0.6;
    for (var i = 0; i < whites.length; i++) {
      final black = whites[i] + 1;
      if (MiniKeyboard.isWhite(black) || i == whites.length - 1) continue;
      final x = (i + 1) * whiteW - blackW / 2;
      final rect = Rect.fromLTWH(x, 0, blackW, blackH);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, bottomLeft: radius, bottomRight: radius),
        Paint()..color = _highlight(black) ?? const Color(0xFF1B1928),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KeyboardPainter old) =>
      old.firstMidi != firstMidi ||
      old.whiteCount != whiteCount ||
      old.expectedMidi != expectedMidi ||
      old.playedMidi != playedMidi ||
      old.playedColor != playedColor;
}
