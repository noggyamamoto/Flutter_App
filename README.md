# Flutter_App
Este repositório é para a aplicação Flutter do TCC desenvolvido por Gabriel e mim.

**Sistema de Processamento de Áudio com Feedback em Tempo Real Aplicado ao Ensino de Partitura** – o aluno toca a partitura (MusicXML) exibida no app, o [dispositivo embarcado](https://github.com/noggyamamoto/firmware_I2S) (ESP32 + microfone INMP441) identifica as notas tocadas e o app compara, nota a nota, com as notas esperadas.

## Funcionalidades

| Requisito | Onde |
|---|---|
| RFA01 / RU02 – Pareamento com o dispositivo | `features/connection` (busca por broadcast UDP, conexão por IP, heartbeat, modo demonstração) |
| RFA02 / RU03 – Catálogo por dificuldade e busca | `features/songs` |
| RFA03 / RU04–RU06 – Música guia, metrônomo sonoro e visual | `features/configuration` |
| RFA04 / RU08 – Partitura em trechos curtos e ampliados | `features/score` (parser MusicXML) + `performance/presentation/widgets/score_display.dart` |
| RFA05 / RU07 – Dois compassos de contagem | `performance` (sincronizado com o metrônomo do dispositivo) |
| RFA06 / RU10 – Cores em tempo real | verde = acerto, laranja = aproximado, vermelho = erro/nota perdida |
| RFA07 – Avaliação por frase | `score/domain/services/performance_evaluator.dart` |
| RFA08 / RU11 – Interrupção abaixo de 50% | tela de incentivo com “Repetir trecho” |
| RFA09 / RU12 – Redução de BPM | sugestão ou ajuste automático (configuração) |
| RFA10 / RU13 / RU15 – Pontuação e troféus | precisão de altura e de ritmo + `features/gamification` |
| RFA11 / RU14 – Gráfico de evolução | a partir da 10ª execução da mesma música |
| RU16 / RU17 – Reiniciar e desconexão segura | tela de resultado / tela de conexão e logout |

## Partituras (MusicXML)

As partituras ficam em `flutter_app/assets/partituras/*.xml` (MusicXML *partwise*, exportável pelo MuseScore, Finale, Sibelius etc.). O documento da música no Firestore (coleção `partituras`) pode ter o campo `arquivoPartitura` com o nome do arquivo; se não tiver, o app usa o nome do `arquivoMidi` com extensão `.xml`.

Para converter MIDIs do repertório em MusicXML de piano (pauta dupla):

```bash
pip install music21
python tools/midi_to_musicxml.py assets/midi/minha_musica.mid --out assets/partituras
```

O microfone reconhece uma nota por vez, por isso a avaliação usa a **melodia** (nota mais aguda da pauta superior). As demais notas aparecem em cinza como acompanhamento.

## Como a avaliação funciona

1. O app envia `SESSION_START` ao dispositivo, que zera o relógio e toca 2 compassos de contagem.
2. Cada nota esperada recebe um horário a partir do BPM de cada trecho.
3. Ao receber `NOTE_ON`, o app procura a nota esperada dentro de uma janela de tempo (±160 a ±400 ms, conforme a duração):
   - **altura**: nota exata = 100%; semitom ou oitava = 50%; outra = 0%;
   - **ritmo**: erro de ataque (até 70 ms = perfeito) e duração medida pelo `NOTE_OFF`.
4. Notas cuja janela passa sem serem tocadas ficam vermelhas.
5. Ao fim de cada trecho: abaixo de 50% a execução trava (RFA08); aprovada mas irregular, o app sugere ou aplica um BPM 10% menor (RFA09/RU12).

## Executar

```bash
cd flutter_app
flutter pub get
flutter run
```

Sem o hardware, use **“Usar modo demonstração”** na tela de conexão: um aluno virtual toca a partitura com pequenos erros (também funciona na web, onde UDP não está disponível).

No iOS, a busca por broadcast exige a permissão de rede local; se o dispositivo não aparecer, use **Conectar pelo IP** (o IP aparece no menu serial do firmware).

### Firestore

- `partituras`: `titulo`, `compositor`, `nivelDificuldade` (fácil/médio/difícil), `bpmPadrao`, `arquivoMidi`, `arquivoPartitura` (opcional)
- `execucoes`: além dos campos anteriores, `pontuacaoAltura`, `pontuacaoRitmo`, `bpmFinal`, `notasTocadas`, `notasCorretas`
- `trofeus` (opcional): catálogo de troféus (`titulo`, `descricao`, `icone`, `criterio`, `meta`); vazio = catálogo padrão do app
- `usuarios/{uid}/trofeus`: troféus conquistados – as regras de segurança devem permitir leitura/escrita pelo próprio usuário

## Testes

```bash
cd flutter_app
flutter test
```

- `test/score`: parser MusicXML (inclui as partituras do repertório), linha do tempo e avaliador
- `test/performance`: fluxo completo com o dispositivo simulado (execução, reprovação de trecho, redução automática de BPM)
- `test/connection`: protocolo UDP contra o dispositivo falso em C do firmware
  (`make -C MicroDetection/test/host fake_device` no repositório firmware_I2S e `FAKE_DEVICE=/caminho/fake_device flutter test test/connection`)
- `test/widget_test.dart`: renderização da partitura e telas de conexão/execução

A fonte [Noto Music](https://fonts.google.com/noto/specimen/Noto+Music) (SIL Open Font License, `assets/fonts/OFL.txt`) é usada para os símbolos musicais.
