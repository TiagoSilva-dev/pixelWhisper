# PixelWhisper no iPhone (guia para o Mac)

O Godot **gera o projeto Xcode** e o Xcode compila e instala no aparelho. O `.ipa` só pode ser montado em macOS,
por isso o passo final é sempre no Mac. O preset **iOS** já está em `export_presets.cfg`
(retrato, iOS 14+, arm64, `com.pixelwhisper.game`). Validei no Linux que o export gera um projeto Xcode correto
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

**Primeiro no simulador** (não precisa de aparelho nem de conta paga):
1. Abra `build/ios/PixelWhisper.xcodeproj`.
2. No topo escolha um *iPhone 15/16* simulado → ▶ **Run**.
3. O simulador **não vibra** e o desempenho do blur não representa um iPhone real.

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

## Publicar (TestFlight / App Store)

Exige o Apple Developer Program. Em linhas gerais: criar o app no App Store Connect com o mesmo Bundle Identifier,
no Godot trocar *Export Method Release* para *App Store*, exportar, e no Xcode usar *Product → Archive →
Distribute App*. Além disso a App Store pede ícone 1024×1024 sem transparência, capturas de tela e política de
privacidade. O ícone atual é gerado do `icon.svg`; vale revisar antes de enviar.
