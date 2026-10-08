extends Node
## Tiny runtime localisation. English strings are the keys, so a missing translation
## degrades to readable English instead of an ID like "UI_HOME_TITLE".
## Use tr("English text") everywhere; Control.text set to English also auto-translates.

const PT := {
	# Home / navigation
	"Continue": "Continuar",
	"Play": "Jogar",
	"Home": "Início",
	"Categories": "Categorias",
	"Diary": "Diário",
	"Shop": "Loja",
	"Profile": "Perfil",
	"%d colors": "%d cores",
	"%d pictures": "%d imagens",
	"Nothing here yet": "Nada por aqui ainda",
	"Anime pictures are coming soon": "As imagens de Anime chegam em breve",
	"Progress": "Progresso",
	# Categories
	"Popular": "Popular",
	"Animals": "Animais",
	"Drawings": "Desenhos",
	"Anime": "Anime",
	"Premium": "Premium",
	"All pictures": "Todas as imagens",
	"Explore Categories": "Explore Categorias",
	"Search": "Buscar",
	# Diary
	"In progress": "Em andamento",
	"Completed": "Concluídas",
	"Paint something to start your diary": "Pinte algo para começar seu diário",
	"January": "Janeiro", "February": "Fevereiro", "March": "Março", "April": "Abril", "May": "Maio",
	"June": "Junho", "July": "Julho", "August": "Agosto", "September": "Setembro", "October": "Outubro",
	"November": "Novembro", "December": "Dezembro",
	"Sun": "Dom", "Mon": "Seg", "Tue": "Ter", "Wed": "Qua", "Thu": "Qui", "Fri": "Sex", "Sat": "Sáb",
	# Shop
	"Daily gift": "Presente diário",
	"+%d coins, once a day": "+%d moedas, uma vez por dia",
	"+%d coins": "+%d moedas",
	"Claim": "Resgatar",
	"Come back tomorrow": "Volte amanhã",
	"Power-ups": "Poderes",
	"Ink bomb": "Bomba de Tinta",
	"Magnifier": "Lupa",
	"Paints every cell of the selected color that you can see": "Pinta todas as células da cor escolhida que você está vendo",
	"Tap a spot: paints the 5x5 square around it": "Toque num ponto: pinta o quadrado 5x5 ao redor",
	"Zooms smoothly onto a pixel you are missing": "Dá zoom suave num pixel que falta",
	"Earn coins: finish a picture for the first time (+60) and claim your daily gift (+50).": "Ganhe moedas: termine uma imagem pela primeira vez (+60) e resgate o presente diário (+50).",
	# Profile
	"Artist": "Artista",
	"Pictures finished": "Imagens concluídas",
	"Pixels painted": "Pixels pintados",
	"Day streak": "Dias seguidos",
	"Coins": "Moedas",
	# Game
	"Back": "Voltar",
	"Magic wand": "Varinha Mágica",
	"Beautiful!": "Lindo!",
	"Level complete": "Fase completa",
	"Next picture": "Próxima imagem",
	"Save image": "Salvar imagem",
	"Time-lapse": "Time-lapse",
	"Image saved": "Imagem salva",
	"Could not save the image": "Não foi possível salvar a imagem",
	"Not enough coins": "Moedas insuficientes",
	"Everything of this color is painted": "Tudo dessa cor já está pintado",
	"Nothing of this color on screen": "Nada dessa cor na tela",
	"Tap the picture to drop the bomb": "Toque na imagem para soltar a bomba",
	"Nothing to paint there": "Nada para pintar aí",
	"Nothing left to paint": "Não falta nada para pintar",
	"Pick a color first": "Escolha uma cor primeiro",
	"Restart picture": "Recomeçar imagem",
	"Tap again to confirm": "Toque de novo para confirmar",
	# Settings
	"Settings": "Ajustes",
	"Icons: Fluent Emoji (Microsoft) and Phosphor Icons, MIT license": "Ícones: Fluent Emoji (Microsoft) e Phosphor Icons, licença MIT",
	"Sound": "Som",
	"Music": "Música",
	"Haptics": "Vibração",
	"Numbers": "Números",
	"Grid": "Grade",
	"Language": "Idioma",
	"Automatic": "Automático",
	# PixelLab client messages (see autoload/pixellab_api.gd)
	"AI generation is not set up yet.": "A geração por IA ainda não foi configurada.",
	"Invalid API token.": "Token de API inválido.",
	"Out of credits.": "Créditos esgotados.",
	"The service is busy. Try again in a moment.": "O serviço está ocupado. Tente de novo em instantes.",
	"Network error. Check your connection.": "Erro de rede. Verifique sua conexão.",
	"The image could not be generated.": "Não foi possível gerar a imagem.",
	"Timed out waiting for the image.": "Tempo esgotado esperando a imagem.",
	# Level titles
	"Space Walk": "Passeio Espacial",
	"Balloon Valley": "Vale dos Balões",
	"Tiny Island": "Ilha Tropical",
	"Sunset Lake": "Lago ao Pôr do Sol",
	"Berry Cake": "Bolo de Morango",
	"Scarlet Macaw": "Arara Vermelha",
	"Koi Pond": "Lago das Carpas",
	"Autumn Fox": "Raposa do Outono",
	"Cozy Cottage": "Casinha Aconchegante",
	"Flower Crown Cat": "Gatinho Florido",
	"Moon Owl": "Coruja da Lua",
	"Sea Turtle": "Tartaruga Marinha",
	"Spring Bouquet": "Buquê da Primavera",
	"Vintage Car": "Carro Vintage",
	"Forest River": "Rio da Floresta",
}


func _ready() -> void:
	var t := Translation.new()
	t.locale = "pt"
	for key in PT:
		t.add_message(key, PT[key])
	TranslationServer.add_translation(t)
	apply_language()
	GameState.settings_changed.connect(apply_language)


func apply_language() -> void:
	var lang: String = GameState.language
	if lang == "auto":
		lang = OS.get_locale_language()
	TranslationServer.set_locale("pt" if lang == "pt" else "en")
