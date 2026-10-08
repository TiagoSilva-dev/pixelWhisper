# PixelWhisper

Jogo de **colorir por números** em pixel art (Godot 4.7, renderer *Compatibility* / GLES3),
com interface **clara e lúdica ("candy")** — papel creme, cartões brancos, cores vivas com "lábio" 3D —,
moedas e poderes, feedback tátil e sonoro estilo ASMR e time-lapse da pintura.
As 34 fases incluídas foram geradas com a **PixelLab** (64×64): 15 cenários/ilustrações e 19 personagens "cute" (animais, anime e desenhos kawaii) com fundo transparente.

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
| **Paleta** | Discos numerados; o selecionado sobe e ganha **anel duplo**; ao concluir a cor o número vira um **✓**; auto-avanço para a próxima cor; "balanço" no disco certo quando você toca o número errado. |
| **Moedas e poderes** | Carteira de moedas (250 no início; +60 ao concluir uma imagem pela primeira vez; +50 no presente diário da Loja). **Varinha Mágica** (40) pinta, de uma vez, todas as células da cor escolhida que estão **na tela** (afaste o zoom para pegar a imagem toda) · **Bomba de Tinta** (25) arma e, no próximo toque, pinta o quadrado **5×5** em volta, cada célula na sua cor · **Lupa** (15) voa a câmera, com zoom suave, até um pixel que falta. A Dica (lâmpada) continua grátis. Preços em `GameState.COST_*`. |
| **ASMR — sinfonia de cores** | Cada pixel toca uma nota de **Kalimba ou Marimba** (sintetizadas, `tools/gen_audio.py`). A nota vem do número da cor (pentatônica em 2 oitavas: cor 1 = dó, cor 2 = ré…, e repete) e cada pixel ainda entorta o tom com `pitch_scale` × aleatório 0,95–1,15, sem repetir o mesmo desvio em seguida. Pool de 10 players (cada voz com o próprio `pitch_scale`), throttle, vibração de **25 ms** por pixel e **100 ms** ao concluir uma cor (`Input.vibrate_handheld`), partículas pixel-shard, trilha ambiente em loop sem emenda. |
| **Vitória e time-lapse** | Ao chegar a 100%: **confete e brilhos `GPUParticles2D`** sobre a tela inteira, a grade se dissolve e um brilho varre a imagem. Cada pixel pintado vai para uma pilha com *timestamp*; `CanvasView.play_timelapse()` reproduz a pintura do quadro em branco até o fim a **10×** (o filme fica entre 3 e 40 s; pausas longas são comprimidas). O histórico é salvo junto do progresso (4 bytes por pixel). Botão na tela de vitória e em Ajustes. |
| **Paleta automática** | Imagens da IA têm até ~57 tons. Quantização *median-cut* em **OKLab** + fusão de clusters minúsculos → ≤ 28 cores jogáveis sem cores de 1–2 células. |
| **Portrait de verdade** | Só containers/âncoras; coluna "formato celular" centrada em janelas largas (web/desktop); área segura (notch); botão voltar do Android; i18n **en + pt-BR**. |
| **Interface clara** | Fundo creme (`#FFFDF0`→`#F8F6EF`) desenhado uma vez (sem shader animado) · botões "candy" achatados com lábio mais escuro, brilho e *squish* ao toque · cartões com a imagem sobre cor viva e faixa colorida com título, progresso e nº de cores · carrossel de categorias · **5 abas fixas** (Início, Categorias, Diário, Loja, Perfil) com realce que desliza · ícones prontos de bibliotecas livres (Fluent Emoji 3D + Phosphor, ambas MIT, em `assets/icons/`; veja `ui/icons.gd`). Sem cópia de tela nem blur: custo de GPU baixo em celular fraco. |
| **Anúncios e Premium** | Ao terminar cada pintura, um **anúncio em vídeo** entre o confete e a tela de vitória. Imagens com selo **Premium** ficam com cadeado: o jogador **assiste a um vídeo** (libera aquela imagem para sempre) ou **compra o pacote Premium** (compra única: todas as imagens, poderes grátis, sem anúncios). **Hoje tudo é simulado** (anúncio e compra falsos, nada é cobrado): o SDK real do Android ainda não está ligado — veja **[docs/MONETIZATION.md](docs/MONETIZATION.md)**. |
| **Salvamento** | Progresso comprimido (≈100–300 B/fase), debounce, escrita atômica, flush ao pausar o app. |

## Estrutura de nós

```
Main (Control)                              scenes/Main.tscn · main.gd
├─ Background (PaperBackground)             papel creme + estrelinhas (desenhado 1×, redesenha só ao redimensionar)
└─ ScreenHost (Control)                     coluna central + área segura; recebe uma tela por vez
     ├─ HomeScreen                          (instanciada por main.gd; troca com recuo/avanço + fade)
     └─ GameScreen

HomeScreen (Control)                        scenes/Home.tscn · home_screen.gd   — o "hub"
└─ Layout (VBoxContainer)
   ├─ PageHost (Control, clip)              uma página visível por vez; criadas na 1ª visita e mantidas
   │    ├─ GalleryPage    (Início)          scenes/pages/gallery_page.gd
   │    │    └─ Header: GradientTitle · CoinPill · CandyButton(engrenagem)
   │    │       CategoryBar (ScrollContainer h → CandyButton "pílulas")
   │    │       ScrollContainer → ContinueCard + GridContainer(2 col) → LevelCard…
   │    ├─ CategoriesPage (Categorias)      título · busca (LineEdit) · CategoryCard… (ou LevelCard… ao buscar)
   │    ├─ DiaryPage      (Diário)          calendário do mês (DayCell…) · sequência · "Em andamento" / "Concluídas"
   │    ├─ ShopPage       (Loja)            card Premium (comprar / restaurar) · presente diário · preço dos poderes · como ganhar moedas
   │    └─ ProfilePage    (Perfil)          avatar · estatísticas · atalho para Ajustes
   └─ BottomNav (CandyPanel)                ui/bottom_nav.gd — 5 NavTab + realce que desliza

GameScreen (Control)                        scenes/Game.tscn · game_screen.gd
├─ Layout (VBoxContainer)
│   ├─ TopBar → Row: BackButton (vermelho) · TitleBox(TitleLabel, ProgressRow(Progress=CandyProgress, Percent)) · HintButton (lâmpada) · MenuButton
│   ├─ CanvasHolder (Control, clip)
│   │    ├─ Canvas (CanvasView)              game/canvas_view.gd — cria em runtime:
│   │    │     moldura (Panel) · _surface (TextureRect + canvas_grid.gdshader) · ParticleFx
│   │    │     (28 emissores de faíscas, GPUParticles2D reciclados) · overlay (dica, onda da bomba)
│   │    └─ Overlay (MarginContainer, mouse ignora) → OverlayColumn
│   │          ├─ TopRight: Coins (CoinPill) · PowerUps (HBox: PowerUpButton × 3 — Varinha, Bomba, Lupa)
│   │          └─ BottomRow: FitButton
│   └─ PaletteDock → PalettePanel (CandyPanel, base reta) → PaletteScroll → PaletteRow (PaletteSwatch…)
└─ Confetti (ConfettiOverlay)               ui/confetti_overlay.gd — 3 emissores de confete + 3 de brilhos (GPUParticles2D), por cima de tudo

Modais criados em runtime: SettingsModal, WinOverlay, UnlockModal ("Imagem Premium": vídeo ou pacote) — herdam de ui/modal.gd: fundo escurecido + cartão branco.
Telas falsas de anúncio/compra (MockAdScreen, MockPurchaseModal, em `monetization/`) vivem num CanvasLayer próprio, por cima de tudo.
```

Autoloads (`project.godot`): `GameState` (ajustes, moedas, **Premium e imagens liberadas**, progresso, histórico do time-lapse, dias pintados) · `I18n` ·
`Feedback` (áudio + vibração) · `Ads` (anúncios) · `Store` (compra do Premium) · `PixelLabAPI` · `LevelLibrary`.

Dados: `assets/levels/manifest.json` agora traz `category` (`animals` / `drawings` / `anime`) e as marcas `popular` / `premium`
por imagem; `core/categories.gd` define as categorias (cor, ícone) e o filtro. "Anime" tem 5 personagens chibi inspirados nos animes mais populares (nomes genéricos de propósito, veja abaixo) e
**"Premium" bloqueia a imagem** até assistir a um vídeo ou comprar o pacote (hoje simulado, veja [docs/MONETIZATION.md](docs/MONETIZATION.md)). Uma categoria sem imagens mostra "em breve".

Widgets (`ui/widgets/`): `CandyButton` (botão com ícone/texto, pílula ou quadrado), `CandyPanel` (cartão arredondado),
`CandyProgress`, `CoinPill`, `GradientTitle` (logo), `PowerUpButton`, `ToggleSwitch`, `RoundedTexture`. Ícones: `Icons.draw()` (arquivos em `assets/icons/`, baixados por `tools/fetch_icons.py`; licenças em `assets/icons/LICENSES.md`).

## Sua especificação → onde está

| Pedido | Arquivo |
|---|---|
| 1. `PixelLabAPI` (Node + `HTTPRequest`), POST 64×64, JSON, buffer → `Image` → `ImageTexture` | `autoload/pixellab_api.gd` (`generate_image`, `decode_image`) — módulo mantido, sem uso na UI |
| 2. `LevelGenerator`: varredura `get_pixel(x, y)`, dicionário cor → ID | `core/level_generator.gd` (+ `palette_quantizer.gd`, `pixel_level.gd`) |
| 2. Grid sem milhares de nós (shader em vez de `TileMapLayer`/`_draw`) | `shaders/canvas_grid.gdshader`, `game/canvas_view.gd` |
| 3. Mouse **e** toque, selecionar cor, arrastar para pintar | `CanvasView._input` e handlers `_on_touch/_on_drag/_on_mouse_*` |
| 3. `GPUParticles2D` por célula · vibração · pop com `pitch_scale` | `game/particle_fx.gd` · `Feedback.haptic()` · `Feedback.pop(color_index)` |
| 4. Portrait, `Control`/`VBoxContainer`/`ScrollContainer`, Compatibility, GDScript modular | `scenes/*.tscn`, `project.godot` |

**Segunda especificação (tema claro, poderes, áudio, vitória):**

| Pedido | Arquivo |
|---|---|
| Tema claro creme, título com gradiente, moedas, engrenagem | `ui/app_theme.gd` · `ui/paper_background.gd` · `ui/widgets/gradient_title.gd` · `coin_pill.gd` · `scenes/pages/gallery_page.gd` |
| Carrossel de categorias (Popular, Animais, Desenhos, Anime, Premium) | `core/categories.gd` · `ui/category_bar.gd` |
| Cartões (título em faixa colorida, progresso, nº de cores) | `ui/level_card.gd` |
| Barra inferior com 5 abas | `ui/bottom_nav.gd` · `scenes/home_screen.gd` · `scenes/pages/*` |
| Tela de jogo: voltar vermelho, nome, % global, lâmpada | `scenes/Game.tscn` · `scenes/game_screen.gd` |
| Varinha Mágica (gasta moedas; pinta a cor escolhida na tela) | `CanvasView.use_wand()` · `GameScreen._on_wand()` |
| Bomba de Tinta (5×5) · Lupa (zoom suave) | `CanvasView.apply_bomb()` / `magnify()` · `game_screen.gd` · `ui/widgets/power_up_button.gd` |
| Barra de cores: círculos, anel duplo, ✓ | `ui/palette_swatch.gd` |
| Sinfonia de cores + modulador de pitch (0,95–1,15) | `Feedback.note_ratio()` / `pop()` · `tools/gen_audio.py` (`kalimba`, `marimba`) |
| Vibração 25 ms ao pintar, 100 ms ao concluir a cor | `Feedback.haptic()` / `vibrate()` / `color_done()` |
| Confete `GPUParticles2D` ao chegar a 100% | `ui/confetti_overlay.gd` · `GameScreen._on_level_completed()` |
| Histórico com timestamp + `play_timelapse()` a 10× | `game/timelapse_recorder.gd` · `CanvasView.play_timelapse()` |

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

**Terceira especificação (anúncios e Premium):**

| Pedido | Arquivo |
|---|---|
| Vídeo de anúncio ao finalizar cada pintura | `autoload/ads.gd` · `GameScreen._on_level_completed()` (uma linha: `await Ads.show_interstitial()`) |
| Arte Premium: assistir a um vídeo **ou** comprar | `ui/unlock_modal.gd` · `LevelLibrary.is_locked()` · bloqueio em `HomeScreen._on_level_chosen()` · cadeado em `ui/level_card.gd` |
| Pacote Premium: tudo ilimitado (imagens, poderes, sem anúncios) | `autoload/store.gd` · `GameState.premium` / `price_of()` · card na `ShopPage` |
| SDK de anúncio / de compra trocáveis | `monetization/ad_provider.gd` · `store_provider.gd` (contratos) · `mock_*` (simulação) |

## Testes

```bash
GODOT=/caminho/do/godot tools/run_tests.sh          # SKIP_GUI=1 em máquina sem display
```
Cobrem: compilação de todos os scripts/cenas/shaders · gerador e quantizador nos 15 PNGs · estatística da nota
(desvio 0,95–1,15, repetição, throttle, mute) · **`test_features.gd`**: economia de moedas, mapeamento cor→nota,
gravador do time-lapse (empilhar, comprimir pausas, salvar/ler, reconciliar, 3–40 s a 10×), varinha (imagem inteira × só o
que está na tela), bomba (quadrado 5×5, canto, armar/soltar), lupa (cor certa, zoom, célula centrada), replay sem tocar no
progresso, vibração 25/100 ms, preços na tela de jogo, confete e recompensa na vitória · benchmark de CPU · testes de
entrada (arrasto, toque rápido, pinça, pan, dedo remanescente, número errado, botão flutuante não pinta por baixo) ·
**`test_monetization.gd`**: Premium e liberações salvos e recarregados, quais imagens ficam bloqueadas, "Próxima imagem" que pula
o bloqueio, regras do intersticial (nunca para Premium, nunca empilhado, pula se não há anúncio) e do vídeo premiado (só paga
se assistido até o fim), resultados da compra (cancelada/falha/ok), loja autoritativa que revoga, **provedores falsos nunca num
release de celular**, e os fluxos pela interface (imagem bloqueada → janela → vídeo/compra → imagem abre; anúncio antes da
tela de vitória; poderes grátis com 0 moedas).
`tools/tests/screenshot_tour.gd` percorre todas as abas, o jogo, os poderes, o time-lapse e a vitória (também em pt-BR)
e salva PNGs de cada estado.

Números medidos (CPU desktop): pintar as 4096 células 20 ms (4,9 µs/célula, já com o histórico do time-lapse) · `_process` com 400 células
animando 0,11 ms/frame · carregar uma fase 3,7 ms · salvar progresso 0,03 ms.

## Exportar

`export_presets.cfg` traz **Web** (sem threads, PWA retrato), **Android** (arm64, retrato, permissão `VIBRATE`) e
**iOS** (projeto Xcode, retrato, iOS 15+). Para iOS veja **[docs/IOS.md](docs/IOS.md)**: o Godot gera o projeto e o
Xcode, no Mac, compila e instala; o *Team ID* do preset fica vazio de propósito (é seu).

```bash
godot --headless --path . --export-release "Web" build/web/index.html    # servir com MIME application/wasm
godot --headless --path . --export-debug "Android" build/android/PixelWhisper.apk
```
Android exige *Import ETC2 ASTC* (já ligado) e SDK/JDK/keystore nas configurações do editor. Para release use
as variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` — não grave senhas no preset.

## Verificado × não verificado

**Verificado:** todos os testes acima (inclusive os fluxos de anúncio e Premium, com provedores falsos); fluxo completo com screenshots reais (as 5 abas → jogo → arrasto → varinha, bomba,
lupa → ajustes → vitória com confete → time-lapse → diário/perfil, também em pt-BR); **build Web** exportado e aberto em
Chromium/WebGL2 (categoria → carta → jogo → voltar → loja, e Premium → imagem bloqueada → janela → vídeo falso → imagem abre, sem erros de console); cliente de IA e
proxy contra o mock; **APK Android de debug** gerado antes do redesenho (assinatura v2/v3 verificada, só a permissão `VIBRATE`) — não regerado depois.

**Não verificado — faça antes de lançar:**
- **Anúncios e compra de verdade:** só existem os provedores falsos. O AdMob e o Google Play Billing ainda não foram ligados nem testados
  em aparelho (veja [docs/MONETIZATION.md](docs/MONETIZATION.md)); idem o comportamento offline e o "Restaurar compras" reais.
- O timbre dos sons (Kalimba e Marimba sintetizados: conferi só que a fundamental cai exatamente em dó 262 Hz e a faixa de
  `pitch_scale`, mas ninguém ouviu) e a sensação da vibração de 25/100 ms.
- Execução do APK em aparelho real, **execução em iOS** (só confirmei que o export gera um projeto Xcode válido, no
  Linux, sem compilar), e desempenho em celular fraco (só medi CPU em desktop).
- Toque real em celular na nova interface (carrossel de pílulas e listas rolando com o dedo): só testei com mouse e
  toque sintético. Medi FPS só em software (Mesa/SwiftShader); o redesenho removeu o blur e o fundo animado, mas não medi em GPU móvel.
- O confete/brilhos (`GPUParticles2D` com `color_initial_ramp`) foram vistos em Mesa e Chromium; não em aparelho.
- O cliente `PixelLabAPI` **contra a API real** — segue o OpenAPI à risca e foi testado contra um mock feito dele,
  mas eu não usei um token real no jogo. Faça um teste com poucos créditos.
- Salvar imagem no Android sem permissão de armazenamento cai para a pasta privada do app (não há *share sheet* nativo).

## Fontes e licenças

- Fonte **Nunito** (OFL, `assets/fonts/OFL.txt`). Oversampling fixado em 2× no import: o automático perdia a
  última linha de pixels de textos pequenos em escalas fracionárias.
- Áudio: sintetizado por `tools/gen_audio.py` (sem licenças de terceiros). Depois de mexer nas receitas, rode
  `python3 tools/gen_audio.py` e reimporte no Godot.
- Arte das 34 fases: gerada com PixelLab (sujeita aos [Termos](https://pixellab.ai/termsofservice)).
- Anime: os 5 personagens (Garoto Ninja, Capitão Pirata, Guerreiro das Esferas, Soldado das Asas, Caçador de Lâminas) são
  chibis *inspirados* em séries muito assistidas, com títulos genéricos. Antes de publicar nas lojas, avalie o risco de
  direitos autorais/marca (semelhança com personagens protegidos) ou troque por personagens originais.
