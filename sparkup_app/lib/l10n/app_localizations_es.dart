// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Spark Up';

  @override
  String get appSlogan => 'Tu dosis diaria de conocimiento, desafío y quiz.';

  @override
  String get dailyFact => 'Hecho diario';

  @override
  String get source => 'Fuente';

  @override
  String get tapToLoadNewChallenge => 'Toca para cargar un nuevo desafío';

  @override
  String get noChallengeAvailable => 'No hay un nuevo desafío disponible.';

  @override
  String get challengeCouldNotBeLoaded => 'No se pudo cargar el desafío.';

  @override
  String get startNewQuiz => 'Quiz Cerebral';

  @override
  String get startWithOneBolt => 'Comenzar con 1 ⚡';

  @override
  String get energyLabel => 'Energía';

  @override
  String get quizFinished => '¡Quiz terminado!';

  @override
  String get yourScore => 'Tu puntuación';

  @override
  String get trueFalseTitle => 'Verdadero / Falso';

  @override
  String get startTrueFalseProblems => 'Prueba Verdadero/Falso';

  @override
  String get trueLabel => 'Verdadero';

  @override
  String get falseLabel => 'Falso';

  @override
  String get categoryLabel => 'Categoría';

  @override
  String get great => '¡Genial!';

  @override
  String get question => 'Pregunta';

  @override
  String get quizCouldNotStart => 'No se pudo iniciar el quiz';

  @override
  String get questionDataIsEmpty => 'Los datos del quiz están vacíos.';

  @override
  String get navMainMenu => 'Temas';

  @override
  String get navInfo => 'Hecho';

  @override
  String get navQuiz => 'Quiz';

  @override
  String get navChallenge => 'Desafío';

  @override
  String get navSettings => 'Configuración';

  @override
  String get loginFailedMessage =>
      'Fallo al iniciar sesión. Por favor, comprueba tu red y vuelve a intentarlo.';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get infoNotFound =>
      'No se encontraron conocimientos para tus temas preferidos.';

  @override
  String get selectYourInterests => 'Selecciona tus intereses';

  @override
  String get preferencesSaved => '¡Preferencias guardadas con éxito!';

  @override
  String get preferencesCouldNotBeSaved =>
      'No se pudieron guardar las preferencias.';

  @override
  String get error => 'Error';

  @override
  String get saving => 'Guardando';

  @override
  String get settings => 'Configuración';

  @override
  String get general => 'General';

  @override
  String get applicationLanguage => 'Idioma de la aplicación';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get forAllAlarms => 'Para todos los hechos y desafíos';

  @override
  String get account => 'Cuenta';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get language => 'Español';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get refresh => 'Actualizar';

  @override
  String get noDataFound => 'No se encontraron datos';

  @override
  String get navLeaderboard => 'Clasificación';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountConfirmation =>
      '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción es irreversible y todos tus datos, incluida tu puntuación, se perderán permanentemente.';

  @override
  String get delete => 'Eliminar';

  @override
  String get signOutConfirmation =>
      '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get noDataAvailable => 'No hay datos disponibles';

  @override
  String get errorCouldNotSaveChanges => 'No se pudieron guardar los cambios';

  @override
  String get selected => 'seleccionado';

  @override
  String get yourRank => 'Tu Rango';

  @override
  String get rankMaster => 'Maestro';

  @override
  String get rankDiamond => 'Diamante';

  @override
  String get rankGold => 'Oro';

  @override
  String get rankSilver => 'Plata';

  @override
  String get rankBronze => 'Bronce';

  @override
  String get rankIron => 'Hierro';

  @override
  String get subscriptions => 'Suscripciones';

  @override
  String get chooseYourPlan => 'Elija su plan';

  @override
  String get planFree => 'Plan Gratuito';

  @override
  String get planPro => 'Plan Pro';

  @override
  String get planUltra => 'Plan Ultra';

  @override
  String get free => 'Gratis';

  @override
  String get month => 'Mes';

  @override
  String get questionsPerDay => 'Preguntas/Día';

  @override
  String get challengesPerDay => 'Desafíos/Día';

  @override
  String get notificationPerDay => 'Notificación/Día';

  @override
  String get notificationsPerDay => 'Notificaciones/Día';

  @override
  String get unlimitedQuizzes => 'Cuestionarios Ilimitados';

  @override
  String get unlimitedChallenges => 'Desafíos Ilimitados';

  @override
  String get purchaseSuccess => 'Suscripción actualizada correctamente.';

  @override
  String get purchaseError => 'Compra fallida';

  @override
  String get current => 'Actual';

  @override
  String get active => 'Activo';

  @override
  String get freeTrial => 'Nivel Gratuito';

  @override
  String get upgrade => 'Actualizar';

  @override
  String get subscriptionNote =>
      'Esto es una simulación de compra. Debe integrarse con un sistema de pago real.';

  @override
  String get limitExceeded => 'Límite Excedido';

  @override
  String get insufficientEnergy => 'Energía insuficiente ⚡';

  @override
  String get streak => 'Racha';

  @override
  String streakBonus(Object streak) {
    return 'Bono de racha x$streak';
  }

  @override
  String get maxStreak => 'Racha Máx.';

  @override
  String get streakBroken => 'Racha Rota';

  @override
  String get points => 'Puntos';

  @override
  String get pointsEarned => 'Puntos Ganados';

  @override
  String get pointsPerQuestion => 'puntos por pregunta';

  @override
  String get errorSubmittingAnswer => 'Error al enviar la respuesta.';

  @override
  String get wrongAnswerResetStreak =>
      'Respuesta incorrecta! Racha reiniciada.';

  @override
  String get correct => 'Correcto';

  @override
  String get incorrect => 'Incorrecto';

  @override
  String get unstoppable => 'IMPARABLE 🔥';

  @override
  String livesLeft(Object count) {
    return 'Quedan $count vidas';
  }

  @override
  String pointsGain(Object points) {
    return '+$points Puntos';
  }

  @override
  String streakBonusFire(Object streak) {
    return 'Bono de racha x$streak 🔥';
  }

  @override
  String get errorCouldNotLoadData => 'No se pudieron cargar los datos.';

  @override
  String get topPlayers => 'Mejores jugadores';

  @override
  String get yourName => 'Tu nombre';

  @override
  String get changeLanguage => 'Cambiar idioma';

  @override
  String get memberSince => 'Miembro desde';

  @override
  String get anonymous => 'Anónimo';

  @override
  String get help => 'Ayuda';

  @override
  String get failedToSaveName => 'No se pudo guardar el nombre';

  @override
  String get saved => 'Guardado';

  @override
  String get enterValidName => 'Introduce un nombre válido';

  @override
  String get failedToSaveNotification => 'No se pudo guardar la notificación';

  @override
  String get failedToSaveLanguage => 'No se pudo guardar el idioma';

  @override
  String get failedToLoadProfile => 'Error al cargar el perfil';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get loading => 'Cargando';

  @override
  String get pleaseWait => 'Espere por favor';

  @override
  String get challenge => 'Desafío';

  @override
  String get hintTapToReload => 'Toca para recargar';

  @override
  String get loadNewChallenge => 'Cargar nuevo desafío';

  @override
  String get challengeIntro =>
      'Recibe desafíos cortos y atractivos para mejorar tus habilidades.';

  @override
  String get leaderboard => 'Clasificación';

  @override
  String get limited => 'Limitado';

  @override
  String get category_history => 'Historia';

  @override
  String get category_science => 'Ciencia';

  @override
  String get category_art => 'Arte';

  @override
  String get category_sports => 'Deportes';

  @override
  String get category_technology => 'Tecnología';

  @override
  String get category_cinema_tv => 'Cine y TV';

  @override
  String get category_music => 'Música';

  @override
  String get category_nature_animals => 'Naturaleza y Animales';

  @override
  String get category_geography_travel => 'Geografía y Viajes';

  @override
  String get category_mythology => 'Mitología';

  @override
  String get category_philosophy => 'Filosofía';

  @override
  String get category_literature => 'Literatura';

  @override
  String get category_space_astronomy => 'Espacio y Astronomía';

  @override
  String get category_health_fitness => 'Salud y Fitness';

  @override
  String get category_economics_finance => 'Economía y Finanzas';

  @override
  String get category_architecture => 'Arquitectura';

  @override
  String get category_video_games => 'Videojuegos';

  @override
  String get category_general_culture => 'Cultura General';

  @override
  String get category_fun_facts => 'Datos Curiosos';

  @override
  String get performance_title => 'Rendimiento';

  @override
  String get performance_subtitle => 'Sigue tu progreso y mejóralo.';

  @override
  String get overall_score => 'Puntuación global';

  @override
  String get category_breakdown => 'Desglose por categoría';

  @override
  String get no_data_available_yet => 'Aún no hay datos disponibles';

  @override
  String get correct_label => 'Correcto';

  @override
  String get excellent_job => '¡Excelente! 🚀';

  @override
  String get keep_pushing => '¡Sigue así! 💪';
}
