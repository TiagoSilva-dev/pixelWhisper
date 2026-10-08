# Anúncios e Premium

Este documento explica o que já existe no jogo, como testar, e o que falta para ligar os anúncios e a compra **de verdade no Android**.

## Regras do produto

| | |
|---|---|
| **Fim de cada pintura** | Anúncio em vídeo (intersticial) entre a comemoração (confete) e a tela de vitória. Premium não vê. Se não houver anúncio pronto (sem internet, sem anúncio disponível), pula sem atrasar nada. |
| **Imagem Premium** (selo de diamante) | Fica com cadeado. Ao tocar abre "Imagem Premium" com duas saídas: **assistir a um vídeo** (libera *aquela* imagem para sempre) ou **comprar o pacote Premium**. |
| **Pacote Premium** | Compra única: todas as imagens liberadas, **poderes grátis** (varinha, bomba, lupa sem gastar moedas) e **sem anúncios**. Os vídeos opcionais continuam disponíveis para quem quiser. |
| **"Próxima imagem"** | Nunca leva a uma imagem bloqueada. |

Hoje são **5 de 34 imagens** marcadas como Premium (`"premium": true` em `assets/levels/manifest.json`). Para o pacote valer a compra, marque mais imagens (por exemplo, todo o Anime).

## Como funciona no código

```
GameScreen / HomeScreen / ShopPage / UnlockModal
        │  (só falam com os autoloads)
   Ads (autoload)  ──►  AdProvider      ◄── MockAdProvider   (editor, Web, testes)
   Store (autoload) ──►  StoreProvider  ◄── MockStoreProvider (editor, Web, testes)
```

- `autoload/ads.gd` e `autoload/store.gd` escondem o SDK atrás de um *provider* (`monetization/ad_provider.gd`, `store_provider.gd`). O jogo não sabe qual SDK existe.
- O estado fica em `GameState`: `premium`, imagens liberadas por vídeo, e `price_of()` (poderes custam 0 com Premium). É salvo **na hora** (não espera o atraso de 1,5 s).
- `LevelLibrary.is_locked(id)` decide o cadeado. O ponto único de bloqueio é `HomeScreen._on_level_chosen`.
- O intersticial é chamado em `GameScreen._on_level_completed` (uma linha: `await Ads.show_interstitial()`). Para mudar o momento (por exemplo, só ao tocar em "Próxima imagem"), é só mover essa linha.
- **Os provedores falsos nunca vão num build *release* de celular** (`Monetization.mocks_allowed()`): lá o jogo usa os provedores base, sem anúncios e sem nada à venda. Senão a loja falsa daria Premium de graça. Há teste para isso.

### Como testar agora (sem contas, sem aparelho)

- No editor (F5) ou num APK **de debug**: o anúncio é uma tela falsa de 3 s ("Test video ad") e a compra abre uma folha falsa ("Test purchase"). Nada é cobrado.
- Em **Ajustes** (só em build de debug) há o interruptor **"Premium (debug)"** para alternar os dois estados sem comprar.
- A versão **Web** usa os provedores falsos. O AdMob não existe na web, então a versão Web serve só de prévia; se um dia for pública, precisa de outra rede de anúncios.
- `tools/tests/test_monetization.gd` (na suíte) cobre o estado salvo, o bloqueio, as regras de anúncio, os resultados da compra e os fluxos pela interface.

## O que falta: Fase 2, Android

### A. O que só você pode fazer (contas e painéis)

1. **AdMob** ([admob.google.com](https://admob.google.com)): crie a conta, registre o app Android (pacote `com.pixelwhisper.game`) e crie **2 blocos de anúncio**: *Intersticial* e *Premiado (rewarded)*. Anote o **App ID** e os dois **IDs de bloco**.
2. **Google Play Console** (taxa já paga):
   - perfil de pagamentos e impostos (necessário para vender);
   - criar o app;
   - em *Monetizar → Produtos → Produtos únicos*, criar o produto `premium` (compra única) e definir o **preço**;
   - cadastrar *testadores de licença* (seu e-mail) para comprar sem ser cobrado;
   - enviar um build (AAB) para a faixa de **teste interno**: sem isso a cobrança e os anúncios reais não funcionam.
3. **Política de privacidade** com URL pública (Play e AdMob exigem), a **declaração de segurança de dados** (Data safety, o AdMob coleta ID de publicidade) e a declaração do **ID de publicidade**. Público-alvo: adultos / público geral, **não** direcionado a crianças.
4. **Consentimento** (UMP, do próprio AdMob): obrigatório para usuários no Espaço Econômico Europeu e no Reino Unido; configurado no painel do AdMob.

### B. O que eu faço (código)

1. **Anúncios:** instalar o plugin AdMob da Poing Studios (o README dele informa Godot 4.5+; **confirmar com 4.7**) e escrever `AdMobProvider extends AdProvider`: pré-carregar o intersticial e o rewarded, emitir `availability_changed` ao carregar/usar, e **sempre** retornar de `show_*` (anúncio fechado, falhou ao mostrar, app em segundo plano) para o jogo nunca travar num anúncio. Incluir o pedido de consentimento (UMP) na inicialização.
2. **Compra:** instalar o plugin oficial *GodotGooglePlayBilling* (Godot 4.2+) e escrever `PlayBillingProvider extends StoreProvider` com `authoritative = true`:
   - produto `premium` como compra única: **reconhecer (acknowledge) sem consumir**, senão o Google reembolsa em 3 dias;
   - consultar as compras ao conectar; emitir `changed` **só com resposta definitiva** (nunca offline: um pagante não pode perder o Premium por falta de sinal);
   - `restore()` consulta de novo e, se a loja estiver inacessível, devolve o último estado conhecido.
3. **Exportação Android:** ligar `gradle_build/use_gradle_build`, instalar o *Android build template* e habilitar os plugins no preset. Isso exige JDK e Android SDK na máquina que exporta (a do seu editor).
4. **Ligar no jogo:** em `Ads._make_provider()` e `Store._make_provider()`, usar o provider real no Android quando o plugin existir (antes do fallback para o mock).
5. **Testar no seu aparelho** com os IDs de teste do Google e a conta de testador.

IDs de teste públicos do Google para Android (confira na documentação do AdMob antes de usar): App ID `ca-app-pub-3940256099942544~3347511713`, intersticial `ca-app-pub-3940256099942544/1033173712`, rewarded `ca-app-pub-3940256099942544/5224354917`. **Nunca clique nos seus próprios anúncios reais** e só troque pelos IDs reais no build de lançamento.

### Checklist no aparelho

- [ ] Terminar uma pintura: confete → anúncio → tela de vitória. Sem internet: vai direto à vitória.
- [ ] Tocar numa imagem Premium: cadeado → "Assistir a um vídeo" libera só aquela imagem, e continua liberada depois de fechar o app.
- [ ] Fechar o vídeo antes do fim: **não** libera.
- [ ] Comprar o Premium com a conta de testador: imagens liberadas, "Free" nos poderes, sem intersticial.
- [ ] Reinstalar o app e tocar em **Restaurar compras** (aba Loja): o Premium volta.
- [ ] Modo avião com Premium já comprado: continua Premium.
- [ ] Botão Voltar do Android durante um anúncio não sai do jogo.

## Riscos e notas

- **Save editável:** o `save.json` é texto. Com a loja real, o Premium é **reconferido com o Google** (`authoritative`), então editar o arquivo não adianta; só vale para o provedor falso, que não tem conta por trás.
- **Políticas:** o vídeo premiado é sempre opcional (botão explícito); o intersticial só aparece numa pausa natural (fim da pintura), nunca ao abrir o app.
- **iOS:** não coberto. O plugin oficial de compra do iOS usa StoreKit 1, está sem mantenedor e não consulta compras existentes ao abrir o app; exigiria avaliar um plugin com StoreKit 2.
- **Preço:** definido no Play Console, não no código. O jogo mostra o preço formatado que a loja devolve (`Store.price_text()`).
