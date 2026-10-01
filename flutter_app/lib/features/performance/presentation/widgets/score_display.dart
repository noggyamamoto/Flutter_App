import 'package:flutter/material.dart';

import '../../../score/domain/entities/musical_score.dart';
import '../../../score/presentation/notation/score_engraver.dart';
import '../../../score/presentation/notation/score_painter.dart';

export '../../../score/presentation/notation/score_painter.dart' show ScorePalette;

// Exibe um trecho curto da partitura (RFA04 / RU08) com símbolos ampliados,
// cores de feedback por nota (RFA06), destaque da próxima nota e cursor.
//
// A gravação (layout) é feita pelo ScoreEngraver com a fonte SMuFL Bravura
// e só é recalculada quando o trecho, a largura ou o zoom mudam; durante a
// execução apenas as cores e o cursor são redesenhados.
class ScoreDisplay extends StatefulWidget {
  // Partitura completa.
  final MusicalScore score;

  // Compassos exibidos (normalmente os da frase atual).
  final List<int> measureIndexes;

  // Cor de cada nota avaliada (verde/amarelo/vermelho).
  final Map<int, Color> noteColors;

  // Notas destacadas (próxima nota esperada).
  final Set<int> activeNoteIds;

  // Posição atual da execução (semínimas) ou null.
  final double? cursorBeat;

  // Ampliação dos símbolos (1.0 = normal).
  final double zoom;

  final ScorePalette palette;

  // Rola verticalmente quando o trecho não cabe na altura disponível.
  final bool scrollable;

  const ScoreDisplay({
    super.key,
    required this.score,
    required this.measureIndexes,
    this.noteColors = const {},
    this.activeNoteIds = const {},
    this.cursorBeat,
    this.zoom = 1.2,
    this.palette = const ScorePalette(),
    this.scrollable = true,
  });

  @override
  State<ScoreDisplay> createState() => _ScoreDisplayState();
}

class _ScoreDisplayState extends State<ScoreDisplay> {
  EngravedScore? _layout;
  Object? _layoutKey;

  EngravedScore _layoutFor(double width) {
    final key = Object.hash(
      widget.score,
      Object.hashAll(widget.measureIndexes),
      width.roundToDouble(),
      widget.zoom,
    );
    if (_layout == null || key != _layoutKey) {
      _layout = ScoreEngraver(widget.score).engrave(
        measureIndexes: widget.measureIndexes,
        width: width,
        zoom: widget.zoom,
      );
      _layoutKey = key;
    }
    return _layout!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.score.measures.isEmpty || widget.measureIndexes.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma nota encontrada.',
          style: TextStyle(color: widget.palette.muted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final layout = _layoutFor(width);

        final content = SizedBox(
          width: width,
          height: layout.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ScoreCursorPainter(
                      layout: layout,
                      cursorBeat: widget.cursorBeat,
                      activeNoteIds: widget.activeNoteIds,
                      palette: widget.palette,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ScorePainter(
                      layout: layout,
                      noteColors: widget.noteColors,
                      palette: widget.palette,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (!widget.scrollable) return content;

        // Centraliza verticalmente quando sobra espaço.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
