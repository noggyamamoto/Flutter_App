#!/usr/bin/env python3
"""
Converte os arquivos MIDI do repertório em partituras MusicXML (.xml)
para piano, com pauta dupla (clave de sol e clave de fá).

As notas a partir do Dó central (MIDI 60) vão para a pauta superior e as
demais para a inferior. Em cada pauta, notas que começam juntas formam um
acorde e sobreposições são encurtadas para manter uma única voz, deixando
a leitura mais limpa para estudantes (RFA04).

Uso:
    pip install music21
    python tools/midi_to_musicxml.py assets/midi/alecrim.mid [...] \
        --out assets/partituras
"""
import argparse
import os
from collections import defaultdict

import music21 as m

SPLIT_MIDI = 60     # Dó central


def build_staff(events, clef, total_ql, time_sig, key_sig, tempo):
    """Monta uma pauta monofônica/acordal a partir de (offset, dur, [midis])."""
    staff = m.stream.PartStaff()
    staff.insert(0, clef)
    staff.insert(0, key_sig)
    staff.insert(0, m.meter.TimeSignature(time_sig))
    if tempo is not None:
        staff.insert(0, m.tempo.MetronomeMark(number=tempo))

    onsets = sorted(events)
    for i, offset in enumerate(onsets):
        dur, pitches = events[offset]
        # Encurta a nota se a próxima começar antes do seu fim (voz única)
        if i + 1 < len(onsets):
            dur = min(dur, onsets[i + 1] - offset)
        dur = max(dur, 0.25)
        if len(pitches) == 1:
            el = m.note.Note(pitches[0])
        else:
            el = m.chord.Chord(sorted(pitches))
        # Sem bequadro explícito: os acidentes são recalculados pela armadura
        for pitch in el.pitches:
            if pitch.accidental is not None and pitch.accidental.alter == 0:
                pitch.accidental = None
        el.quarterLength = dur
        staff.insert(offset, el)

    staff.makeRests(fillGaps=True, inPlace=True, refStreamOrTimeRange=[0.0, total_ql])
    return staff


def convert(path, out_dir):
    src = m.converter.parse(path)
    title = os.path.splitext(os.path.basename(path))[0]
    part = src.parts[0]
    if part.partName:
        title = part.partName

    ts = src.recurse().getElementsByClass(m.meter.TimeSignature).first()
    ks = src.recurse().getElementsByClass(m.key.KeySignature).first()
    mm = src.recurse().getElementsByClass(m.tempo.MetronomeMark).first()
    time_sig = ts.ratioString if ts else '4/4'
    bar_ql = ts.barDuration.quarterLength if ts else 4.0

    upper = defaultdict(lambda: [0.0, []])
    lower = defaultdict(lambda: [0.0, []])
    end = 0.0
    for n in part.flatten().notes:
        offset = round(float(n.getOffsetInHierarchy(part)) * 4) / 4   # grade de semicolcheia
        dur = round(float(n.quarterLength) * 4) / 4 or 0.25
        end = max(end, offset + dur)
        for p in n.pitches:
            target = upper if p.midi >= SPLIT_MIDI else lower
            slot = target[offset]
            slot[0] = max(slot[0], dur)
            if p.midi not in slot[1]:
                slot[1].append(p.midi)

    total_ql = (int(end // bar_ql) + (1 if end % bar_ql else 0)) * bar_ql

    score = m.stream.Score()
    score.metadata = m.metadata.Metadata()
    score.metadata.title = title
    score.metadata.composer = ''

    key = m.key.KeySignature(ks.sharps if ks else 0)
    treble = build_staff(upper, m.clef.TrebleClef(), total_ql, time_sig, key,
                         mm.number if mm else None)
    bass = build_staff(lower, m.clef.BassClef(), total_ql, time_sig,
                       m.key.KeySignature(key.sharps), None)
    treble.partName = 'Piano'
    score.insert(0, treble)
    score.insert(0, bass)
    score.insert(0, m.layout.StaffGroup([treble, bass], symbol='brace', name='Piano'))

    score.makeNotation(inPlace=True)
    out = os.path.join(out_dir, os.path.splitext(os.path.basename(path))[0] + '.xml')
    score.write('musicxml', fp=out)
    print(f'{path} -> {out}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files', nargs='+')
    parser.add_argument('--out', default='assets/partituras')
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for f in args.files:
        convert(f, args.out)


if __name__ == '__main__':
    main()
