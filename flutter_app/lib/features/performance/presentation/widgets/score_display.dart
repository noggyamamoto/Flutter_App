import 'package:flutter/material.dart';

import '../../../score/domain/entities/musical_score.dart';
import '../../../score/presentation/notation/score_engraver.dart';
import '../../../score/presentation/notation/score_painter.dart';

export '../../../score/presentation/notation/score_engraver.dart' show EngravedScore;
export '../../../score/presentation/notation/score_painter.dart' show ScorePalette;

// Exibe um trecho curto da partitura (RFA04 / RU08) com símbolos ampliados,
// cores de feedback por nota (RFA06), destaque da próxima nota e cursor.
//
// A gravação (layout) é feita pelo ScoreEngraver com a fonte SMuFL Bravura
// e só é recalculada quando o trecho, o tamanho ou o zoom mudam; durante a
// execução apenas as cores e o cursor são redesenhados.
//
// Quando a altura é limitada, o tamanho dos símbolos é reduzido até o
// trecho inteiro caber (respeitando um mínimo legível). Se ainda assim não
// couber, a partitura rola sozinha até o sistema em que está o cursor.
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

  // Reduz os símbolos para o trecho caber na altura disponível.
  final bool fitHeight;

  // Camada extra sobre a partitura (ex.: selo de avaliação sobre a nota),
  // construída com o layout calculado (posição das notas).
  final Widget Function(BuildContext context, EngravedScore layout)? overlayBuilder;

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
    this.fitHeight = true,
    this.overlayBuilder,
  });

  // Menor espaço entre linhas da pauta (px) usado para caber na altura.
  // Abaixo disso a partitura rola, para não prejudicar a leitura (RFA04).
  static const double minFitSpace = 6.5;

  @override
  State<ScoreDisplay> createState() => _ScoreDisplayState();
}

class _ScoreDisplayState extends State<ScoreDisplay> {
  final ScrollController _scroll = ScrollController();

  EngravedScore? _layout;
  Object? _layoutKey;
  int? _cursorSystem;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  EngravedScore _layoutFor(double width, double height) {
    final fit = widget.fitHeight && height.isFinite && height > 0;
    final key = Object.hash(
      widget.score,
      Object.hashAll(widget.measureIndexes),
      width.roundToDouble(),
      fit ? height.roundToDouble() : null,
      widget.zoom,
    );
    if (_layout == null || key != _layoutKey) {
      final engraver = ScoreEngraver(widget.score);
      var zoom = widget.zoom;
      var layout = engraver.engrave(measureIndexes: widget.measureIndexes, width: width, zoom: zoom);
      while (fit && layout.height > height && layout.space * 0.92 >= ScoreDisplay.minFitSpace) {
        zoom *= 0.92;
        layout = engraver.engrave(measureIndexes: widget.measureIndexes, width: width, zoom: zoom);
      }
      _layout = layout;
      _layoutKey = key;
      _cursorSystem = null;
    }
    return _layout!;
  }

  // Mantém visível o sistema em que está o cursor.
  void _followCursor(EngravedScore layout, double viewport) {
    final beat = widget.cursorBeat;
    if (beat == null || !widget.scrollable) return;
    final located = layout.locate(beat);
    if (located == null) return;
    final system = located.$1;
    final index = layout.systems.indexOf(system);
    if (index == _cursorSystem) return;
    _cursorSystem = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) return;
      // Sistema no topo, mostrando um pouco do anterior quando possível.
      final target = (system.top - layout.space * 2).clamp(0.0, max);
      _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    });
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

    // Fonte dos textos (números de compasso e andamento) igual à do app.
    final textFamily = DefaultTextStyle.of(context).style.fontFamily;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final layout = _layoutFor(width, constraints.maxHeight);
        _followCursor(layout, constraints.maxHeight);

        final content = SizedBox(
          width: width,
          height: layout.height,
          child: Stack(
            clipBehavior: Clip.none,
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
                      textFontFamily: textFamily,
                    ),
                  ),
                ),
              ),
              if (widget.overlayBuilder != null) widget.overlayBuilder!(context, layout),
            ],
          ),
        );

        if (!widget.scrollable) return content;

        // Centraliza verticalmente quando sobra espaço.
        return SingleChildScrollView(
          controller: _scroll,
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
