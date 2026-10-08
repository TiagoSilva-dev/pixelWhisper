# PixelWhisper

Jogo premium de **colorir por números** em pixel art (Godot 4.7, renderer *Compatibility* / GLES3),
com interface em **vidro fosco (glassmorphism) com movimento** e feedback tátil e sonoro estilo ASMR.
As 15 fases incluídas foram geradas com a **PixelLab** (64×64).

## Rodar

1. Abra a pasta no Godot **4.7+** (`project.godot`) e aperte **F5**. (Se o editor já estava aberto
   antes destes arquivos existirem: *Project → Reload Current Project*.)
2. Janela de teste em retrato: *Project Settings → Display → Window* já usa 540×960 (override).
3. Para acrescentar uma fase: coloque um PNG 64×64 em `assets/levels/` e uma linha em `assets/levels/manifest.json`.

## O que torna isto mais que um clone

| | |
|---|---|
| **Renderização** | O grid inteiro (cinza-fantasma, números, grade, realce pulsante da cor ativa, animação de "pop", brilho de vitória) é **1 draw call** num shader com uma textura de estado 64×64. Zero nós por célula, zero `draw_string` por frame. |
| **Números nítidos** | Fonte bitmap 5×7 em atlas filtrado pelo shader → dígitos suaves em qualquer zoom. |
| **Câmera** | Pinça, pan com 2 dedos + inércia, roda do mouse, gestos de trackpad, zoom-to-fit animado. 1 dedo/botão esquerdo pinta; arrasto rápido não deixa buracos (Bresenham). |
| **Paleta** | Anel de progresso por cor, check ao concluir, auto-avanço para a próxima cor, "balanço" no swatch certo quando você toca o número errado. |
| **Ferramentas** | Dica (câmera voa até a célula e pulsa um anel) e Varinha Mágica (cascata de 40 células; 1 varinha ganha por fase concluída). |
| **ASMR** | Pool de 10 players (cada voz com o próprio `pitch_scale`), pitch aleatório 0,9–1,2 sem repetir tom parecido, 3 variações de pop, volume com jitter, vibração com throttle, partículas pixel-shard da cor da célula, chimes por cor/fase concluída, trilha ambiente em loop sem emenda. Todos os sons são sintetizados (`tools/gen_audio.py`). |
| **Paleta automática** | Imagens da IA têm até ~57 tons. Quantização *median-cut* em **OKLab** + fusão de clusters minúsculos → ≤ 28 cores jogáveis sem cores de 1–2 células. |
| **Portrait de verdade** | Só containers/âncoras; coluna "formato celular" centrada em janelas largas (web/desktop); área segura (notch); botão voltar do Android; i18n **en + pt-BR**. |
| **Interface em vidro** | Fundo *aurora* com bokeh animado (shader renderizado a 1/4 da resolução num `SubViewport`) · painéis, cartões, botões 3D e diálogos de vidro fosco (rim-light, bevel, sombra suave, brilho que varre ao entrar/tocar) · **blur real do fundo** no cabeçalho, filtro, dica e diálogos (1 cópia de tela por frame, via `BackBufferCopy`) · cartões que entram com animação e **dimmam/encolhem conforme a posição de rolagem** · filtro segmentado com pílula que desliza com overshoot · transições de tela com profundidade · parallax do fundo na rolagem. |
| **Salvamento** | Progresso comprimido (≈100–300 B/fase), debounce, escrita atômica, flush ao pausar o app. |

## Estrutura de nós

```
Main (Control)                              scenes/Main.tscn · main.gd
├─ Background (AuroraBackground)            fundo animado (SubViewport 1/4 res + shader aurora)
└─ ScreenHost (Control)                     coluna central + área segura; recebe uma tela por vez
     ├─ HomeScreen                          (instanciada por main.gd; troca com recuo/avanço + fade)
     └─ GameScreen

HomeScreen (Control)                        scenes/Home.tscn · home_screen.gd
├─ Scroll (ScrollContainer, tela inteira)   o conteúdo rola POR BAIXO do cabeçalho de vidro
│   └─ ScrollMargin → ScrollContent (VBoxContainer)
│        ├─ ContinueHolder                   ContinueCard
│        └─ Grid (GridContainer, 2 colunas)  LevelCard…
├─ BlurCopy (BackBufferCopy)                uma cópia da tela por frame, compartilhada pelo blur
├─ HeaderBlock (MarginContainer)
│   └─ HeaderColumn (VBoxContainer)
│        ├─ HeaderPanel (GlassPanel, blur) → HeaderRow: TitleBox(Logo=GlowLabel, SubChip) · CoinButton · SettingsButton
│        └─ FilterRow → Filters (GlassSegmented)
└─ HintHolder (CenterContainer)             HintPill ("Toque e comece a colorir")

GameScreen (Control)                        scenes/Game.tscn · game_screen.gd
└─ Layout (VBoxContainer)
   ├─ TopBar → TopPanel (GlassPanel) → Row: BackButton · TitleBox(TitleLabel, ProgressRow(Progress=GlassProgress, Percent)) · HintButton · MenuButton
   ├─ CanvasHolder (Control, clip)
   │    ├─ Canvas (CanvasView)                  game/canvas_view.gd — cria em runtime:
   │    │     moldura (Panel) · _surface (TextureRect + canvas_grid.gdshader) · ParticleFx
   │    │     (28 emissores de faíscas + 4 de confete, GPUParticles2D reciclados) · overlay da dica
   │    └─ Tools (MarginContainer) → ToolsRow: WandButton · Spacer · FitButton
   └─ PaletteDock (MarginContainer) → PalettePanel (GlassPanel) → PaletteScroll → PaletteInset → PaletteRow (PaletteSwatch…)

Modais criados em runtime: SettingsModal, WinOverlay (herdam de ui/modal.gd: backdrop desfocado + cartão de vidro)
```

Autoloads (`project.godot`): `GameState` · `I18n` · `Feedback` (áudio + vibração) · `PixelLabAPI` · `LevelLibrary`.

Sistema de vidro: `shaders/glass_common.gdshaderinc` (SDF arredondado, rim-light direcional, bevel, sombra, varredura de brilho)
→ `glass.gdshader` (translúcido, sem cópia de tela) e `glass_blur.gdshader` (+ blur real). `ui/glass.gd` tem os presets
(PANEL/CARD/BUTTON/PILL/MODAL); widgets: `GlassPanel`, `IconButton` (botão 3D com ícones vetoriais), `GlassSegmented`,
`GlassProgress`, `GlowLabel`, `HintPill`. **Ajustes → "Efeitos de vidro"** desliga o blur (vidro fosco opaco, sem cópia
de tela) para aparelhos fracos.

## Sua especificação → onde está

| Pedido | Arquivo |
|---|---|
| 1. `PixelLabAPI` (Node + `HTTPRequest`), POST 64×64, JSON, buffer → `Image` → `ImageTexture` | `autoload/pixellab_api.gd` (`generate_image`, `decode_image`) — módulo mantido, sem uso na UI |
| 2. `LevelGenerator`: varredura `get_pixel(x, y)`, dicionário cor → ID | `core/level_generator.gd` (+ `palette_quantizer.gd`, `pixel_level.gd`) |
| 2. Grid sem milhares de nós (shader em vez de `TileMapLayer`/`_draw`) | `shaders/canvas_grid.gdshader`, `game/canvas_view.gd` |
| 3. Mouse **e** toque, selecionar cor, arrastar para pintar | `CanvasView._input` e handlers `_on_touch/_on_drag/_on_mouse_*` |
| 3. `GPUParticles2D` por célula · `Input.vibrate_handheld(30)` · pop com `pitch_scale` 0,9–1,2 | `game/particle_fx.gd` · `Feedback.haptic()` · `Feedback.pop()` |
| 4. Portrait, `Control`/`VBoxContainer`/`ScrollContainer`, Compatibility, GDScript modular | `scenes/*.tscn`, `project.godot` |

## IA / PixelLab (módulo opcional, fora da interface)

A tela "Criar com IA" foi removida do jogo. O cliente `PixelLabAPI`, o proxy e o mock continuam no repositório
como módulo isolado (nada na UI atual depende deles) — úteis para gerar fases novas ou um recurso futuro.

Contrato real (extraído do OpenAPI oficial, `https://api.pixellab.ai/v2/openapi.json`):
`POST /create-image-pixflux-background` → `202 {background_job_id}` → polling em
`GET /background-jobs/{id}` → `last_response.image.base64`. O cliente trata 401/402/422/429, timeout (150 s,
com cancelamento do job) e também aceita imagem por URL.

> ⚠️ **Nunca coloque o token da PixelLab dentro do app.** Um APK/build Web é desempacotado em minutos.
> Para lançar, rode `server/proxy.mjs` (Node 18+, sem dependências) e aponte `[pixellab] base_url` em
> `project.godot` para ele. O proxy guarda o token, **força 64×64 no servidor**, limita por IP
> (`RATE_PER_HOUR`), só deixa cada cliente ler os próprios jobs e nunca devolve saldo/`usage`.
> Ele também resolve CORS no build Web (não sei se a API oficial libera origens de navegador).

```bash
PIXELLAB_API_TOKEN=... node server/proxy.mjs        # Railway: defina a variável e use este start command
```

Desenvolvimento local, sem proxy e **sem gastar créditos**:

```bash
python3 tools/mock_pixellab_server.py               # imita a API (modos: ok|401|402|429|fail|slow)
PIXELLAB_BASE_URL=http://127.0.0.1:8787/v2 godot --path .
```
Ou, com token real só na sua máquina: `PIXELLAB_API_TOKEN=...` ou `user://pixellab.cfg`
(`[api] token="..."`; *Project → Open User Data Folder*).

## Testes

```bash
GODOT=/caminho/do/godot tools/run_tests.sh          # SKIP_GUI=1 em máquina sem display
```
Cobrem: compilação de todos os scripts/cenas/shaders · gerador e quantizador nos 15 PNGs · estatística do pop
(faixa de pitch, repetição, throttle, mute) · benchmark de CPU · 9 testes de entrada (arrasto, toque rápido,
pinça, pan, dedo remanescente, toque no número errado, botão flutuante não pinta por baixo).
`tools/tests/screenshot_tour.gd` percorre o jogo e salva PNGs de cada estado.

Números medidos (CPU desktop): pintar as 4096 células 14 ms (3,6 µs/célula) · `_process` com 400 células
animando 0,11 ms/frame · carregar uma fase 3,7 ms · salvar progresso 0,03 ms.

## Exportar

`export_presets.cfg` traz **Web** (sem threads, PWA retrato), **Android** (arm64, retrato, permissão `VIBRATE`) e
**iOS** (projeto Xcode, retrato, iOS 14+). Para iOS veja **[docs/IOS.md](docs/IOS.md)**: o Godot gera o projeto e o
Xcode, no Mac, compila e instala; o *Team ID* do preset fica vazio de propósito (é seu).

```bash
godot --headless --path . --export-release "Web" build/web/index.html    # servir com MIME application/wasm
godot --headless --path . --export-debug "Android" build/android/PixelWhisper.apk
```
Android exige *Import ETC2 ASTC* (já ligado) e SDK/JDK/keystore nas configurações do editor. Para release use
as variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` — não grave senhas no preset.

## Verificado × não verificado

**Verificado:** todos os testes acima; fluxo completo com screenshots reais (home → jogo → arrasto → ajustes →
vitória → galeria → ajustes, também em pt-BR, em janela larga e com efeitos de vidro desligados); cliente de IA e
proxy contra o mock; **build Web** exportado e executado em Chromium/WebGL2 (sem erros de console; blur real do fundo
funciona; rolagem por toque, abrir fase e arrastar para pintar); **APK Android de debug** gerado, assinatura (v2/v3) verificada, só a permissão `VIBRATE`.

**Não verificado — faça antes de lançar:**
- O timbre dos sons (sintetizados e analisados por espectrograma/estatística, mas ninguém ouviu) e a sensação da vibração.
- Execução do APK em aparelho real, **execução em iOS** (só confirmei que o export gera um projeto Xcode válido, no
  Linux, sem compilar), e desempenho em celular fraco (só medi CPU em desktop).
- **Custo de GPU dos efeitos de vidro**: o blur real exige uma cópia da tela por frame (+ o fundo aurora a 1/4 de resolução).
  Validei o visual em Mesa (software) e Chromium/WebGL2, mas não medi FPS em GPU móvel antiga — por isso existe o
  interruptor *Ajustes → Efeitos de vidro*. Meça num aparelho de entrada antes de decidir o padrão.
- O cliente `PixelLabAPI` **contra a API real** — segue o OpenAPI à risca e foi testado contra um mock feito dele,
  mas eu não usei um token real no jogo. Faça um teste com poucos créditos.
- Salvar imagem no Android sem permissão de armazenamento cai para a pasta privada do app (não há *share sheet* nativo).

## Fontes e licenças

- Fonte **Nunito** (OFL, `assets/fonts/OFL.txt`). Oversampling fixado em 2× no import: o automático perdia a
  última linha de pixels de textos pequenos em escalas fracionárias.
- Áudio: sintetizado por `tools/gen_audio.py` (sem licenças de terceiros).
- Arte das 15 fases: gerada com PixelLab (sujeita aos [Termos](https://pixellab.ai/termsofservice)).
