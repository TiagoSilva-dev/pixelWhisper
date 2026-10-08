extends Node
## Tiny runtime localisation. English strings are the keys, so a missing translation
## degrades to readable English instead of an ID like "UI_HOME_TITLE".
## Use tr("English text") everywhere; Control.text set to English also auto-translates.

const PT := {
	# Home
	"Continue": "Continuar",
	"Play": "Jogar",
	"All": "Todas",
	"In progress": "Em andamento",
	"Completed": "Concluídas",
	"%d colors": "%d cores",
	"Nothing here yet": "Nada por aqui ainda",
	"Your gallery": "Sua galeria",
	# Game
	"Magic wand": "Varinha mágica",
	"Beautiful!": "Lindo!",
	"Level complete": "Fase completa",
	"Next picture": "Próxima imagem",
	"Home": "Início",
	"Save image": "Salvar imagem",
	"Image saved": "Imagem salva",
	"Could not save the image": "Não foi possível salvar a imagem",
	"No wands left. Finish a picture to earn one!": "Sem varinhas. Termine uma imagem para ganhar uma!",
	"Everything of this color is painted": "Tudo dessa cor já está pintado",
	"Pick a color first": "Escolha uma cor primeiro",
	"Restart picture": "Recomeçar imagem",
	"Tap again to confirm": "Toque de novo para confirmar",
	# Settings
	"Settings": "Ajustes",
	"Sound": "Som",
	"Music": "Música",
	"Haptics": "Vibração",
	"Numbers": "Números",
	"Grid": "Grade",
	"Glass effects": "Efeitos de vidro",
	"Progress": "Progresso",
	"Tap and start coloring": "Toque e comece a colorir",
	"Finish a picture to earn a magic wand": "Termine uma imagem para ganhar uma varinha mágica",
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
