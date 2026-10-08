# PixelWhisper no iPhone (guia para o Mac)

O Godot **gera o projeto Xcode** e o Xcode compila e instala no aparelho. O `.ipa` só pode ser montado em macOS,
por isso o passo final é sempre no Mac. O preset **iOS** já está em `export_presets.cfg`
(retrato, iOS 15+, arm64, `com.pixelwhisper.game`). Validei no Linux que o export gera um projeto Xcode correto
(bundle id, retrato, ícones a partir do `icon.svg`), mas **ainda não rodei em nenhum iPhone/simulador**.

## O que você precisa

| Item | Para quê | Custo |
|---|---|---|
| Mac com **Xcode** (App Store) | compilar e assinar | grátis |
| **Godot 4.7.2** para macOS (a mesma versão do projeto) | exportar | grátis |
| **Apple ID** | assinar para o *seu* iPhone | grátis |
| Apple Developer Program | TestFlight / App Store / apps sem expirar | US$ 99/ano |

Com Apple ID grátis o app instalado **expira em 7 dias** (reinstale pelo Xcode), com limite de 3 apps ativos
por aparelho, e não há TestFlight.

## 1. Preparar o Mac (uma vez)

1. Instale o Xcode, abra uma vez, aceite a licença e deixe instalar os componentes extras.
2. Xcode → *Settings → Accounts* → **+** → entre com seu Apple ID. Aparece um *Personal Team*.
3. Baixe o **Godot 4.7.2 (macOS)** em godotengine.org e abra.
4. No Godot: *Editor → Manage Export Templates → Download and Install* (baixa os templates oficiais, inclusive iOS).

## 2. Baixar o projeto

```bash
git clone git@github.com:TiagoSilva-dev/pixelWhisper.git
```
Abra a pasta no Godot (*Import* → `project.godot`) e espere a importação terminar.

## 3. Achar o Team ID (o Godot recusa exportar sem ele)

- **Conta paga:** developer.apple.com → *Account → Membership details → Team ID* (10 caracteres).
- **Apple ID grátis:** o Xcode precisa ter criado o certificado (basta ter conectado a conta e feito um build
  para dispositivo, ou *Settings → Accounts → Manage Certificates → + → Apple Development*). Então:
  ```bash
  security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
  ```
  O Team ID é o valor de **`OU=`** na saída (não o código entre parênteses no `CN`).

## 4. Exportar do Godot

1. *Project → Export…* → preset **iOS**.
2. Preencha **App Store Team ID** (passo 3).
3. **Bundle Identifier**: precisa ser único no mundo. Se o Xcode reclamar que `com.pixelwhisper.game` já existe,
   troque por algo seu, por exemplo `com.tiago.pixelwhisper`.
4. Deixe *Export Project Only* ligado → **Export Project…** → salve em `build/ios/PixelWhisper.ipa`
   (a pasta `build/` está no `.gitignore`). O resultado é `build/ios/PixelWhisper.xcodeproj`.

## 5. Rodar no Xcode

**Sem cabo, num Mac Apple Silicon (M1 ou mais novo):**
1. Abra `build/ios/PixelWhisper.xcodeproj`.
2. No topo, no seletor de destino, escolha **My Mac (Designed for iPhone)** (em alguns Xcodes aparece como
   *Designed for iPad*) → ▶ **Run**. O app abre numa janela, com o mouse fazendo o papel do toque.
3. Precisa do *Team* configurado (passo 3 abaixo, "No seu iPhone"). Não vibra e o blur não representa um iPhone.

**No simulador de iPhone:** em Mac Apple Silicon pode falhar no link com `Undefined symbol: _main` (veja "Erros
conhecidos"). Se for o seu caso, use o iPhone de verdade ou a opção acima.

**No seu iPhone:**
1. Conecte por cabo e toque em *Confiar neste computador*.
2. No iPhone: *Ajustes → Privacidade e Segurança → Modo de Desenvolvedor* → ligar → reiniciar.
3. No Xcode: target **PixelWhisper → Signing & Capabilities** → marque *Automatically manage signing* e confira o *Team*.
4. Escolha o iPhone no topo → ▶ **Run**.
5. Na primeira vez o iPhone bloqueia o app: *Ajustes → Geral → VPN e Gerenciamento de Dispositivo* → seu Apple ID → **Confiar**.

## O que olhar no aparelho (nada disso foi testado em iOS)

- **A tela aparece?** O projeto usa o renderer *Compatibility*. Se ficar preta, me mande o log do Xcode (painel inferior).
- **Som mudo?** Por padrão o Godot usa a categoria de áudio *Ambient*, que **obedece ao botão físico de silêncio**
  do iPhone. Confira o botão antes de achar que é bug. Para tocar mesmo no silencioso, mude
  *Project Settings → Audio → General → iOS → Session Category* para **Playback** (decisão de produto: num jogo de ASMR
  pode ser o desejado, mas ignora a escolha do usuário).
- **Vibração:** `Input.vibrate_handheld(30)` deve dar um toque háptico no iPhone (não existe em iPad nem no simulador).
- **Entalhe / Dynamic Island:** a UI usa a área segura do sistema; confira o cabeçalho e a paleta inferior.
- **Fluidez do blur de vidro:** em *Ajustes → Efeitos de vidro* dá para desligar; compare o FPS nos dois modos.

## Erros conhecidos

- **"IPHONEOS_DEPLOYMENT_TARGET is set to 14.0, but the range of supported deployment target versions is 15.0 to …"**:
  o seu Xcode não aceita iOS 14. No Godot, *Project → Export → iOS → Application → Min iOS Version* = `15.0`
  (ou a versão mínima que a mensagem indicar) e **exporte de novo**. O Xcode só lê o que o Godot gerou, então
  mudar o número dentro do Xcode é desfeito no próximo export.

- **"Undefined symbol: _main"** (ou `Undefined symbols for architecture arm64: _main`) ao compilar para o
  **simulador**: na biblioteca do motor que o Godot 4.7.2 copia para o projeto
  (`build/ios/PixelWhisper.xcframework`), a fatia `ios-arm64_x86_64-simulator` que examinei tinha **só código
  x86_64**; o `_main` está lá, mas um simulador arm64 (Mac Apple Silicon) não consegue usá-lo. A fatia do aparelho
  (`ios-arm64`) está completa. Solução: rode no **iPhone de verdade** ou em **My Mac (Designed for iPhone)**.
  *Isto é a causa mais provável, inferida do conteúdo da biblioteca; não consegui reproduzir o link do Xcode no
  Linux.* Se o erro aparecer num destino que não seja o simulador, ou num Mac Intel, a causa é outra: cole a
  mensagem completa (Report navigator → build log).

## Publicar (TestFlight / App Store)

Exige o Apple Developer Program. Em linhas gerais: criar o app no App Store Connect com o mesmo Bundle Identifier,
no Godot trocar *Export Method Release* para *App Store*, exportar, e no Xcode usar *Product → Archive →
Distribute App*. Além disso a App Store pede ícone 1024×1024 sem transparência, capturas de tela e política de
privacidade. O ícone atual é gerado do `icon.svg`; vale revisar antes de enviar.
