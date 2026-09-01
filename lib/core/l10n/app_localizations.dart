import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Supported locales
// ─────────────────────────────────────────────────────────────────────────────

const kSupportedLocales = [Locale('en'), Locale('es')];

// ─────────────────────────────────────────────────────────────────────────────
// String tables
// ─────────────────────────────────────────────────────────────────────────────

const _en = <String, String>{
  // General
  'appTitle': 'Fight Task',
  'back': 'Back',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'close': 'Close',
  'error': 'Error',
  'loading': 'Loading…',
  'required': 'Required',

  // Home
  'myLeagues': 'My Leagues',
  'noLeaguesYet': 'No leagues yet',
  'noLeaguesSubtitle': 'Create or join a league to start fighting!',
  'createLeague': 'Create',
  'joinLeague': 'Join',
  'newLeague': 'New League',
  'joinLeagueBtn': 'Join League',
  'syncingCalendar': 'Syncing Google Calendar…',
  'syncingCalendarSub':
      'Connecting your tasks to Google Calendar.\nThis only takes a moment.',
  'fighters': 'fighters',
  'fighter': 'fighter',
  'language': 'Language',

  // League home
  'navigate': 'NAVIGATE',
  'arena': 'Arena',
  'tasks': 'Tasks',
  'history': 'History',
  'members': 'Members',
  'weeklyCompetition': 'Weekly Competition',
  'monthlyCompetition': 'Monthly Competition',
  'inviteCode': 'Invite Code',
  'inviteToLeague': 'Invite to League',
  'inviteShareText':
      'Share this code with friends so they can join your league:',
  'copyCode': 'Copy Code',
  'inviteCopied': 'Invite code copied!',

  // Tasks — tabs & buttons
  'myTasks': 'My Tasks',
  'leagueTasks': 'League Tasks',
  'newTask': 'New Task',
  'upcoming': 'Upcoming',
  'upcomingTasks': 'Upcoming tasks',
  'previewToday': 'Today',
  'previewTomorrow': 'Tomorrow',
  'previewOverdueDays': 'Overdue {days}d',
  'previewInDays': 'In {days}d',
  'previewOverdueCount': '{count} overdue',
  'previewTodayCount': '{count} today',
  'goToTasks': 'Go to Tasks →',
  'seeAllTasks': 'See all {count} tasks →',
  'recurring': 'Recurring',
  'noTasksAssigned': 'No tasks assigned to you yet.',
  'noTasksAssignedSub':
      'Assign a league task to yourself\nor ask someone to assign one.',
  'noTasksForDay': 'No tasks scheduled for this day.',
  'noTasksMatch': 'No tasks match your filters.',
  'noTasksMatchSub': 'Try adjusting the filters.',
  'noUnassignedTasks': 'No unassigned tasks yet.',
  'noUnassignedTasksSub': 'Create a task or assign one to yourself.',
  'assignToMe': 'Assign to me',
  'assignToMeA': 'Assign to me a',
  'doneForOccurrence': '⚡ Done for this occurrence!',
  'done': '⚡ Done!',
  'searchTasks': 'Search tasks…',
  'showAssigned': 'Show assigned',
  'anyAssignee': 'Any assignee',
  'allMembers': 'All members',
  'assignedTo': 'Assigned to',
  'returnToLeagueTasks': 'Return to League Tasks',
  'clearFilters': 'Clear filters',

  // Tasks — edit/create form
  'editTask': 'Edit Task',
  'taskTitle': 'Task title',
  'description': 'Description (optional)',
  'effortDamage': 'Effort / Damage',
  'repeat': 'Repeat',
  'assignedToLabel': 'Assigned to',
  'noAssignee': 'No assignee (league task)',
  'scheduled': 'Scheduled',
  'dueDate': 'Due date',
  'scheduledDateTime': 'Scheduled date & time',
  'dueDateDateTime': 'Due date & time',
  'tapToSelect': 'Tap to select',
  'reminder': 'Reminder',
  'saveChanges': 'Save changes',
  'deleteTask': 'Delete task',
  'viewList': 'List',
  'viewCalendar': 'Calendar',
  'switchView': 'Switch view',
  'calendarWeek': 'Week',
  'calendarMonth': 'Month',
  'deleteTaskConfirm': 'Delete "{title}"? This cannot be undone.',
  'taskDeleted': '🗑️ "{title}" deleted',
  'taskMoved': '✅ "{title}" moved to My Tasks',
  'taskReturned': '↩️ "{title}" returned to League Tasks',
  'createTask': 'New Task',
  'createTaskBtn': 'Create Task',
  'pleaseSetScheduled': 'Please set a scheduled date & time.',
  'pleaseSetDue': 'Please set a due date for this task.',
  'enterTitle': 'Enter a title',

  // Schedule line
  'everyDay': 'Every day',
  'everyMonth': 'Every month · day',
  'scheduleTimeDue': 'due',
  'scheduleTimeAt': 'at',
  'schedulePrefix': 'Every',
  'scheduleLabelDue': 'Due',
  'scheduleLabelScheduled': 'Scheduled',
  // Repeat dropdown
  'repeatNone': 'None',
  'repeatDaily': 'Daily',
  'repeatWeekly': 'Weekly',
  'repeatMonthly': 'Monthly',
  // Reminder dropdown
  'reminderNone': 'No reminder',
  'reminder15': '15 min before',
  'reminder30': '30 min before',
  'reminder60': '1 hour before',
  'reminder120': '2 hours before',
  'reminder1440': '1 day before',
  'reminder2880': '2 days before',
  // Reminder label units (for dynamic reminder display)
  'reminderMinUnit': 'min before',
  'reminderHourUnit': 'h before',
  'reminderDayUnit': 'd before',
  // Occurrence picker
  'occurrenceModeOccurrence': 'occurrence',
  'occurrenceModeDue': 'due date',
  'whichOccurrence': 'Which {repeat} occurrence?',
  'whichDueDate': 'Which {repeat} due date?',
  'oneTimeCopyOf': 'A one-time copy of "{title}" will be assigned to you.',
  'occurrenceAdded': '✅ "{title}" on {date} added to My Tasks',
  'oneTime': 'One-time',
  // Complete / attack
  'completeTask': '⚔️ Complete "{title}"',
  'complete': 'Complete',
  'thisOccurrence': 'This occurrence · -1 HP · +🪙1 coin',
  'dealsEarns': 'Deals 1 HP damage · Earns 🪙1 coin',
  'chooseTarget': 'Choose a target (optional):',
  'noOtherMembers':
      'No other members in this league yet. Invite someone to attack!',
  'confirmAttack': 'Confirm & Attack!',
  'doneOccurrence': 'Done for this occurrence!',
  'skipOccurrence': 'Skip this time (nobody did it)',
  'skipOccurrenceTitle': 'Skip this occurrence?',
  'skipOccurrenceMessage':
      'This moves "{title}" to the next date without anyone completing it. No coins, no damage, no history.',
  'skipConfirm': 'Skip',
  'skippedToast': 'Skipped - moved to the next date',

  // History
  'historyTitle': 'History',
  'searchHistory': 'Search history…',
  'filterByMember': 'Filter by member',
  'noHistory': 'No events yet.',
  'noHistoryMatch': 'No events match your filters.',

  // Members
  'membersTitle': 'Members',
  'owner': 'Owner',
  'hp': 'HP',

  // Leave league
  'leaveLeague': 'Leave League',
  'leaveLeagueConfirmTitle': 'Leave league?',
  'leaveLeagueConfirmBody':
      'You will be removed from "{name}". You can rejoin with the invite code.',
  'leaveLeagueOwnerError':
      'The league owner cannot leave. Transfer ownership first.',
  'leaveLeagueSuccess': 'You have left "{name}".',
  'leaveLeagueError': 'Could not leave the league. Try again.',

  // Daily coins banner
  'coinsExhausted': 'No coins left today',
  'coinsToday': '{earned}/{max} 🪙 today',

  // Nav card subtitles
  'arenaSubtitle': 'Fight & rankings',
  'tasksSubtitle': 'Your task list',
  'historySubtitle': 'Attack log',
  'statisticsSubtitle': 'Rankings & performance',

  // Period / attacks
  'periodResetsIn': 'Resets in {days}d {hours}h',
  'periodResetsToday': 'Resets today!',
  'periodResetsInDays': 'Resets in {days}d',
  'periodResetsInHours': 'Resets in {hours}h',
  'attacksLeft': '{n} attacks left today',
  'attacksExhausted': 'No attacks left today',
  'attacksLeftFull': 'All {max} attacks available',
  'attackCapReached':
      '⚠️ You\'ve used all {max} attacks for today. Come back tomorrow!',

  // Arena attack flow
  'attackFighter': 'Attack {name}',
  'selectTaskToAttack': 'Choose a task to complete and attack with:',
  'noTasksToAttack': 'No tasks available',
  'noTasksToAttackSub':
      'You have no tasks assigned. Go to the Tasks screen to assign one first.',
  'attackWith': 'Attack with this task',
  'arenaAttackSuccess': '✅ +🪙1 coin\n💥 -{dmg} HP to {name}',
  'whoDidIt': 'Who did it?',
  'youTag': 'You',
  'whoToAttack': 'Who do you want to attack?',
  'selectOpponentOrComplete':
      'Select an opponent or complete without attacking.',
  'noAttacksLeftEarnCoins': 'No attacks left today - you can still earn coins.',
  'allKoComplete': 'All opponents are K.O.! Complete to earn coins.',
  'noOneJustEarn': 'No one - just earn coins & XP',
  'completeNoDamage': 'Complete the task without dealing damage',
  'creditsOnlyFor': 'Give credit to {name} (coins & XP only)',
  'noLiveOpponents': 'No live opponents available.',
  'attackCapUnlockTomorrow': 'Attack cap reached - attacks unlock tomorrow.',
  'shieldActive': '🛡️ Shield active',
  'watchAdToAttack': 'Watch an ad for +1 coin',
  'adAttackUnlocked': '+1 coin earned!',
  'resultCoins': '+🪙{coins} coin',
  'resultNoCoinsToday': 'Daily coin limit reached - no more coins today',
  'resultNoDamageCap': 'attack cap reached, no damage dealt',
  'resultDamage': '-{dmg} HP to {name}',
  'resultKO': 'Task logged - you are K.O., no coins or damage dealt',

  // Arena
  'hpFull': 'Full HP',
  'hpInjured': 'Injured',
  'hpCritical': 'Critical',
  // Arena tabs & misc
  'arenaTabRing': 'Ring',
  'arenaTabPlayers': 'Players',
  'arenaTabRanking': 'Ranking',
  'leagueNotFound': 'League not found.',
  'noFightersYet': 'No fighters yet.',
  'periodThisWeek': 'This week',
  'periodThisMonth': 'This month',
  'periodLastWeek': 'Last week',
  'periodLastMonth': 'Last month',
  'periodSince': '{label} · since {date}',
  'periodResultsLastWeek': 'Last week\'s results',
  'periodResultsLastMonth': 'Last month\'s results',
  'rankingTabCurrent': 'Current',
  'rankingTabPrevious': 'Last period',
  'tapToSeeResults': 'Tap to see the full ranking',
  'noResultsYet': 'No results for this period yet.',
  'shieldBlockedMsg':
      '🛡️ {name} has a shield active for {time} — your attack will be blocked!',
  'attackAnyway': 'Attack anyway',
  'otherFighters': 'OTHER FIGHTERS',
  'attackBadge': 'ATTACK',
  'completeBadge': 'COMPLETE',
  'buyShieldShort': 'Buy shield',
  'buyShieldTitle': 'Buy a Shield',
  'buyShieldDesc':
      'Protect yourself from attacks for a limited time.\nYou have 🪙{coins} coins.',
  'shieldActiveFor': '🛡️ Shield active for {duration}!',
  'notEnoughCoins': 'Not enough coins.',
  'noAttacksComeBack': 'No attacks left today — come back tomorrow!',
  'attackHintTap':
      'Tap the opponent or press ATTACK, then pick a task to complete.',
  'allKoKeepEarning':
      'All opponents K.O.! Complete tasks to keep earning coins & XP.',
  'allKoTitle': 'All opponents are K.O.!',
  'allKoSubtitle':
      'Complete a task to earn coins & XP.\nNo damage will be dealt.',
  'completeWithoutAttacking':
      'Complete a task without attacking (earn coins only)',
  'continueBtn': 'Continue',
  'preparing': 'Preparing...',
  'completing': 'Completing...',
  'attacking': 'Attacking!',
  'hit': 'Hit!',

  // Profile
  'profile': 'Profile',
  'signOut': 'Sign Out',
  'deleteAccount': 'Delete account',
  'deleteAccountTitle': 'Delete account?',
  'deleteAccountMessage':
      'This will permanently delete your account, your progress and remove you from all leagues. This action cannot be undone.',
  'deleteAccountConfirm': 'Delete',
  'deleteAccountReauth':
      'For security, please sign out and sign in again before deleting your account.',
  'deleteAccountError': 'Could not delete your account. Please try again.',
  'chooseFighter': 'Choose your fighter',
  'unlockFightersWithCoins': 'Unlock new fighters with 🪙 coins',
  'profileCoins': 'coins',
  'profileToday': 'today',
  'watchAdForCoins': 'Watch ad +{coins} coins ({left} left)',
  'watchAdCapReached': 'No more ad rewards today',
  'watchAdNotReady': 'No ad available right now - try again shortly.',
  'watchAdRewarded': '+{coins} coins earned!',
  'watchAdBonusCoin': 'Watch ad · +1 🪙 bonus',
  'bonusCoinAdded': '+1 🪙 bonus added!',

  // Statistics
  'statistics': 'Statistics',
  'statsThisMonth': 'This month',
  'statsLastMonth': 'Last month',
  'statsLast3Months': 'Last 3 months',
  'statsAllTime': 'All time',
  'statsByMember': 'Tasks by member',
  'statsTopTasks': 'Most completed tasks',
  'statsMemberBreakdown': 'Member breakdown',
  'statsTaskBreakdown': 'TASKS',
  'statsTasks': 'tasks',
  'statsDmg': 'dmg',
  'statsCoins': 'coins',
  'statsTotalTasks': 'Total tasks',
  'statsTotalDamage': 'Total damage',
  'statsTotalCoins': 'Total coins',
  'statsNoData': 'No tasks completed yet.',
  'statsNoDataPeriod': 'No activity in this period.',
  'statsNoDataSub': 'Complete tasks to see stats here.',
  'statsCustomRange': 'Custom range',
  'statsPickRange': 'Pick date range',

  // Login / Register screen
  'signIn': 'Sign In',
  'register': 'Register',
  'fighterName': 'Fighter name',
  'email': 'Email',
  'password': 'Password',
  'forgotPassword': 'Forgot password?',
  'createAccount': 'Create Account',
  'continueWithGoogle': 'Continue with Google',
  'loginTagline': 'Complete tasks. Deal damage. Win the league.',
  'orDivider': 'or',
  'enterName': 'Enter your name',
  'enterValidEmail': 'Enter a valid email',
  'minChars': 'Min 6 characters',
  'enterEmailFirst': 'Enter your email first to reset password.',
  'passwordResetSent': '✅ Password reset email sent!',
  'errUserNotFound': 'No account found with this email.',
  'errWrongPassword': 'Incorrect password.',
  'errEmailInUse': 'This email is already registered. Sign in instead.',
  'errWeakPassword': 'Password must be at least 6 characters.',
  'errInvalidEmail': 'Please enter a valid email address.',
  'errTooManyRequests': 'Too many attempts. Please try again later.',
  'errGeneric': 'An error occurred. Please try again.',

  // Quota / free-plan limit alert
  'quotaAlertTitle': 'Service temporarily unavailable',
  'quotaAlertMessage':
      'The app reached its daily usage limit. Some actions cannot be completed right now. Please contact the administrator - quota limit exceeded.',
  'quotaAlertButton': 'OK',

  // Maintenance mode
  'maintenanceTitle': 'We will be right back',
  'maintenanceMessage':
      'We are applying some updates to improve your experience. Please check back in a little while.',
  'maintenanceHint': 'Thanks for your patience.',
};

const _es = <String, String>{
  // General
  'appTitle': 'Fight Task',
  'back': 'Atrás',
  'cancel': 'Cancelar',
  'save': 'Guardar',
  'delete': 'Eliminar',
  'close': 'Cerrar',
  'error': 'Error',
  'loading': 'Cargando…',
  'required': 'Obligatorio',

  // Home
  'myLeagues': 'Mis ligas',
  'noLeaguesYet': 'Aún no tienes ligas',
  'noLeaguesSubtitle': '¡Crea o únete a una liga para empezar a luchar!',
  'createLeague': 'Crear',
  'joinLeague': 'Unirse',
  'newLeague': 'Nueva liga',
  'joinLeagueBtn': 'Unirse a liga',
  'syncingCalendar': 'Sincronizando Google Calendar…',
  'syncingCalendarSub':
      'Conectando tus tareas con Google Calendar.\nSolo tomará un momento.',
  'fighters': 'luchadores',
  'fighter': 'luchador',
  'language': 'Idioma',

  // League home
  'navigate': 'NAVEGAR',
  'arena': 'Arena',
  'tasks': 'Tareas',
  'history': 'Historial',
  'members': 'Miembros',
  'weeklyCompetition': 'Competición semanal',
  'monthlyCompetition': 'Competición mensual',
  'inviteCode': 'Código de invitación',
  'inviteToLeague': 'Invitar a la liga',
  'inviteShareText':
      'Comparte este código con amigos para que se unan a tu liga:',
  'copyCode': 'Copiar código',
  'inviteCopied': '¡Código copiado!',

  // Tasks — tabs & buttons
  'myTasks': 'Mis tareas',
  'leagueTasks': 'Tareas de la liga',
  'newTask': 'Nueva tarea',
  'upcoming': 'Próximas',
  'upcomingTasks': 'Próximas tareas',
  'previewToday': 'Hoy',
  'previewTomorrow': 'Mañana',
  'previewOverdueDays': 'Vencida hace {days}d',
  'previewInDays': 'En {days}d',
  'previewOverdueCount': '{count} vencidas',
  'previewTodayCount': '{count} hoy',
  'goToTasks': 'Ir a Tareas →',
  'seeAllTasks': 'Ver las {count} tareas →',
  'recurring': 'Recurrentes',
  'noTasksAssigned': 'Aún no tienes tareas asignadas.',
  'noTasksAssignedSub':
      'Asígnate una tarea de la liga\no pide a alguien que te asigne una.',
  'noTasksForDay': 'No hay tareas programadas para este día.',
  'noTasksMatch': 'Ninguna tarea coincide con los filtros.',
  'noTasksMatchSub': 'Prueba a ajustar los filtros.',
  'noUnassignedTasks': 'No hay tareas sin asignar.',
  'noUnassignedTasksSub': 'Crea una tarea o asígnatela.',
  'assignToMe': 'Asignarme',
  'assignToMeA': 'Asignarme una',
  'doneForOccurrence': '⚡ ¡Hecho para esta vez!',
  'done': '⚡ ¡Hecho!',
  'searchTasks': 'Buscar tareas…',
  'showAssigned': 'Ver asignadas',
  'anyAssignee': 'Cualquier miembro',
  'allMembers': 'Todos los miembros',
  'assignedTo': 'Asignada a',
  'returnToLeagueTasks': 'Devolver a tareas de la liga',
  'clearFilters': 'Limpiar filtros',

  // Tasks — edit/create form
  'editTask': 'Editar tarea',
  'taskTitle': 'Título de la tarea',
  'description': 'Descripción (opcional)',
  'effortDamage': 'Esfuerzo / Daño',
  'repeat': 'Repetición',
  'assignedToLabel': 'Asignada a',
  'noAssignee': 'Sin asignar (tarea de liga)',
  'scheduled': 'Programada',
  'dueDate': 'Fecha límite',
  'scheduledDateTime': 'Fecha y hora programadas',
  'dueDateDateTime': 'Fecha y hora límite',
  'tapToSelect': 'Toca para seleccionar',
  'reminder': 'Recordatorio',
  'saveChanges': 'Guardar cambios',
  'deleteTask': 'Eliminar tarea',
  'viewList': 'Lista',
  'viewCalendar': 'Calendario',
  'switchView': 'Cambiar vista',
  'calendarWeek': 'Semana',
  'calendarMonth': 'Mes',
  'deleteTaskConfirm': '¿Eliminar "{title}"? Esta acción no se puede deshacer.',
  'taskDeleted': '🗑️ "{title}" eliminada',
  'taskMoved': '✅ "{title}" movida a Mis tareas',
  'taskReturned': '↩️ "{title}" devuelta a Tareas de la liga',
  'createTask': 'Nueva tarea',
  'createTaskBtn': 'Crear tarea',
  'pleaseSetScheduled': 'Por favor, indica la fecha y hora programadas.',
  'pleaseSetDue': 'Por favor, indica la fecha límite.',
  'enterTitle': 'Escribe un título',
  // Schedule line
  'everyDay': 'Cada día',
  'everyMonth': 'Cada mes · día',
  'scheduleTimeDue': 'límite',
  'scheduleTimeAt': 'a las',
  'schedulePrefix': 'Cada',
  'scheduleLabelDue': 'Límite',
  'scheduleLabelScheduled': 'Programada',
  // Repeat dropdown
  'repeatNone': 'Sin repetición',
  'repeatDaily': 'Diaria',
  'repeatWeekly': 'Semanal',
  'repeatMonthly': 'Mensual',
  // Reminder dropdown
  'reminderNone': 'Sin recordatorio',
  'reminder15': '15 min antes',
  'reminder30': '30 min antes',
  'reminder60': '1 hora antes',
  'reminder120': '2 horas antes',
  'reminder1440': '1 día antes',
  'reminder2880': '2 días antes',
  // Reminder label units (for dynamic reminder display)
  'reminderMinUnit': 'min antes',
  'reminderHourUnit': 'h antes',
  'reminderDayUnit': 'd antes',
  // Occurrence picker
  'occurrenceModeOccurrence': 'repetición',
  'occurrenceModeDue': 'fecha límite',
  'whichOccurrence': '¿Qué repetición {repeat}?',
  'whichDueDate': '¿Qué fecha límite {repeat}?',
  'oneTimeCopyOf': 'Se creará una copia única de "{title}" asignada a ti.',
  'occurrenceAdded': '✅ "{title}" el {date} añadida a Mis tareas',
  'oneTime': 'Única',
  // Complete / attack
  'completeTask': '⚔️ Completar "{title}"',
  'complete': 'Completar',
  'thisOccurrence': 'Esta vez · -1 HP · +🪙1 moneda',
  'dealsEarns': 'Causa 1 HP de daño · Gana 🪙1 moneda',
  'chooseTarget': 'Elige un objetivo (opcional):',
  'noOtherMembers': 'Aún no hay más miembros. ¡Invita a alguien para atacar!',
  'confirmAttack': '¡Confirmar y atacar!',
  'doneOccurrence': '¡Hecho para esta vez!',
  'skipOccurrence': 'Saltar esta vez (nadie la hizo)',
  'skipOccurrenceTitle': '¿Saltar esta vez?',
  'skipOccurrenceMessage':
      'Esto mueve "{title}" a la siguiente fecha sin que nadie la complete. Sin monedas, sin daño, sin historial.',
  'skipConfirm': 'Saltar',
  'skippedToast': 'Saltada - movida a la siguiente fecha',

  // History
  'historyTitle': 'Historial',
  'searchHistory': 'Buscar historial…',
  'filterByMember': 'Filtrar por miembro',
  'noHistory': 'Aún no hay eventos.',
  'noHistoryMatch': 'Ningún evento coincide.',

  // Members
  'membersTitle': 'Miembros',
  'owner': 'Propietario',
  'hp': 'PV',

  // Leave league
  'leaveLeague': 'Abandonar liga',
  'leaveLeagueConfirmTitle': '¿Abandonar la liga?',
  'leaveLeagueConfirmBody':
      'Serás eliminado de "{name}". Puedes volver a unirte con el código de invitación.',
  'leaveLeagueOwnerError': 'El propietario no puede abandonar la liga.',
  'leaveLeagueSuccess': 'Has abandonado "{name}".',
  'leaveLeagueError': 'No se pudo abandonar la liga. Inténtalo de nuevo.',

  // Daily coins banner
  'coinsExhausted': 'Sin monedas hoy',
  'coinsToday': '{earned}/{max} 🪙 hoy',

  // Nav card subtitles
  'arenaSubtitle': 'Peleas y ranking',
  'tasksSubtitle': 'Tu lista de tareas',
  'historySubtitle': 'Registro de ataques',
  'statisticsSubtitle': 'Ranking y rendimiento',

  // Period / attacks
  'periodResetsIn': 'Reinicia en {days}d {hours}h',
  'periodResetsToday': '¡Reinicia hoy!',
  'periodResetsInDays': 'Reinicia en {days}d',
  'periodResetsInHours': 'Reinicia en {hours}h',
  'attacksLeft': '{n} ataques restantes hoy',
  'attacksExhausted': 'Sin ataques hoy',
  'attacksLeftFull': 'Los {max} ataques disponibles',
  'attackCapReached': '⚠️ Has usado los {max} ataques de hoy. ¡Vuelve mañana!',

  // Arena attack flow
  'attackFighter': 'Atacar a {name}',
  'selectTaskToAttack': 'Elige una tarea para completar y atacar:',
  'noTasksToAttack': 'Sin tareas disponibles',
  'noTasksToAttackSub':
      'No tienes tareas asignadas. Ve a Tareas para asignarte una primero.',
  'attackWith': 'Atacar con esta tarea',
  'arenaAttackSuccess': '✅ +🪙1 moneda\n💥 -{dmg} PV a {name}',
  'whoDidIt': '¿Quién la hizo?',
  'youTag': 'Tú',
  'whoToAttack': '¿A quién quieres atacar?',
  'selectOpponentOrComplete': 'Elige un rival o completa sin atacar.',
  'noAttacksLeftEarnCoins': 'Sin ataques hoy - aún puedes ganar monedas.',
  'allKoComplete':
      '¡Todos los rivales están K.O.! Completa para ganar monedas.',
  'noOneJustEarn': 'Nadie - solo gana monedas y XP',
  'completeNoDamage': 'Completa la tarea sin causar daño',
  'creditsOnlyFor': 'Dar el mérito a {name} (solo monedas y XP)',
  'noLiveOpponents': 'No hay rivales disponibles.',
  'attackCapUnlockTomorrow': 'Límite de ataques alcanzado - se renueva mañana.',
  'shieldActive': '🛡️ Escudo activo',
  'watchAdToAttack': 'Ver un anuncio por +1 moneda',
  'adAttackUnlocked': '¡+1 moneda ganada!',
  'resultCoins': '+🪙{coins} moneda',
  'resultNoCoinsToday': 'Límite de monedas alcanzado - no ganas más hoy',
  'resultNoDamageCap': 'límite de ataques alcanzado, sin daño',
  'resultDamage': '-{dmg} PV a {name}',
  'resultKO': 'Tarea registrada - estás K.O., sin monedas ni daño',

  // Arena
  'hpFull': 'PV completos',
  'hpInjured': 'Herido',
  'hpCritical': 'Crítico',
  // Arena tabs & misc
  'arenaTabRing': 'Ring',
  'arenaTabPlayers': 'Jugadores',
  'arenaTabRanking': 'Ranking',
  'leagueNotFound': 'Liga no encontrada.',
  'noFightersYet': 'Aún no hay luchadores.',
  'periodThisWeek': 'Esta semana',
  'periodThisMonth': 'Este mes',
  'periodLastWeek': 'La semana pasada',
  'periodLastMonth': 'El mes pasado',
  'periodSince': '{label} · desde {date}',
  'periodResultsLastWeek': 'Resultados de la semana pasada',
  'periodResultsLastMonth': 'Resultados del mes pasado',
  'rankingTabCurrent': 'Actual',
  'rankingTabPrevious': 'Periodo anterior',
  'tapToSeeResults': 'Toca para ver el ranking completo',
  'noResultsYet': 'Aún no hay resultados de este periodo.',
  'shieldBlockedMsg':
      '🛡️ {name} tiene un escudo activo durante {time} — ¡tu ataque será bloqueado!',
  'attackAnyway': 'Atacar igualmente',
  'otherFighters': 'OTROS LUCHADORES',
  'attackBadge': 'ATACAR',
  'completeBadge': 'COMPLETAR',
  'buyShieldShort': 'Comprar escudo',
  'buyShieldTitle': 'Comprar un escudo',
  'buyShieldDesc':
      'Protégete de los ataques durante un tiempo limitado.\nTienes 🪙{coins} monedas.',
  'shieldActiveFor': '🛡️ ¡Escudo activo durante {duration}!',
  'notEnoughCoins': 'Monedas insuficientes.',
  'noAttacksComeBack': 'Sin ataques hoy — ¡vuelve mañana!',
  'attackHintTap':
      'Toca al rival o pulsa ATACAR, luego elige una tarea para completar.',
  'allKoKeepEarning':
      '¡Todos los rivales K.O.! Completa tareas para seguir ganando monedas y XP.',
  'allKoTitle': '¡Todos los rivales están K.O.!',
  'allKoSubtitle':
      'Completa una tarea para ganar monedas y XP.\nNo se causará daño.',
  'completeWithoutAttacking':
      'Completa una tarea sin atacar (solo ganas monedas)',
  'continueBtn': 'Continuar',
  'preparing': 'Preparando...',
  'completing': 'Completando...',
  'attacking': '¡Atacando!',
  'hit': '¡Golpe!',

  // Profile
  'profile': 'Perfil',
  'signOut': 'Cerrar sesión',
  'deleteAccount': 'Eliminar cuenta',
  'deleteAccountTitle': '¿Eliminar cuenta?',
  'deleteAccountMessage':
      'Esto eliminará permanentemente tu cuenta, tu progreso y te sacará de todas las ligas. Esta acción no se puede deshacer.',
  'deleteAccountConfirm': 'Eliminar',
  'deleteAccountReauth':
      'Por seguridad, cierra sesión y vuelve a iniciar sesión antes de eliminar tu cuenta.',
  'deleteAccountError': 'No se pudo eliminar tu cuenta. Inténtalo de nuevo.',
  'chooseFighter': 'Elige tu luchador',
  'unlockFightersWithCoins': 'Desbloquea nuevos luchadores con 🪙 monedas',
  'profileCoins': 'monedas',
  'profileToday': 'hoy',
  'watchAdForCoins': 'Ver anuncio +{coins} monedas ({left} rest.)',
  'watchAdCapReached': 'No hay más recompensas hoy',
  'watchAdBonusCoin': 'Ver anuncio · +1 🪙 extra',
  'bonusCoinAdded': '¡+1 🪙 extra añadida!',
  'watchAdNotReady':
      'No hay anuncio disponible ahora - inténtalo en un momento.',
  'watchAdRewarded': '¡+{coins} monedas conseguidas!',

  // Statistics
  'statistics': 'Estadísticas',
  'statsThisMonth': 'Este mes',
  'statsLastMonth': 'Mes anterior',
  'statsLast3Months': 'Últimos 3 meses',
  'statsAllTime': 'Todo el tiempo',
  'statsByMember': 'Tareas por miembro',
  'statsTopTasks': 'Tareas más completadas',
  'statsMemberBreakdown': 'Detalle por miembro',
  'statsTaskBreakdown': 'TAREAS',
  'statsTasks': 'tareas',
  'statsDmg': 'daño',
  'statsCoins': 'monedas',
  'statsTotalTasks': 'Tareas totales',
  'statsTotalDamage': 'Daño total',
  'statsTotalCoins': 'Monedas totales',
  'statsNoData': 'Aún no hay tareas completadas.',
  'statsNoDataPeriod': 'Sin actividad en este período.',
  'statsNoDataSub': 'Completa tareas para ver estadísticas.',
  'statsCustomRange': 'Rango personalizado',
  'statsPickRange': 'Elegir rango de fechas',

  // Login / Register screen
  'signIn': 'Iniciar sesión',
  'register': 'Registrarse',
  'fighterName': 'Nombre de luchador',
  'email': 'Correo electrónico',
  'password': 'Contraseña',
  'forgotPassword': '¿Olvidaste tu contraseña?',
  'createAccount': 'Crear cuenta',
  'continueWithGoogle': 'Continuar con Google',
  'loginTagline': 'Completa tareas. Inflige daño. Gana la liga.',
  'orDivider': 'o',
  'enterName': 'Escribe tu nombre',
  'enterValidEmail': 'Escribe un correo válido',
  'minChars': 'Mínimo 6 caracteres',
  'enterEmailFirst':
      'Introduce tu correo primero para restablecer la contraseña.',
  'passwordResetSent': '✅ ¡Correo de restablecimiento enviado!',
  'errUserNotFound': 'No se encontró ninguna cuenta con este correo.',
  'errWrongPassword': 'Contraseña incorrecta.',
  'errEmailInUse': 'Este correo ya está registrado. Inicia sesión.',
  'errWeakPassword': 'La contraseña debe tener al menos 6 caracteres.',
  'errInvalidEmail': 'Por favor introduce un correo válido.',
  'errTooManyRequests': 'Demasiados intentos. Inténtalo más tarde.',
  'errGeneric': 'Ha ocurrido un error. Inténtalo de nuevo.',

  // Quota / free-plan limit alert
  'quotaAlertTitle': 'Servicio no disponible temporalmente',
  'quotaAlertMessage':
      'La app alcanzó su límite de uso diario. Algunas acciones no se pueden completar ahora mismo. Contacta al administrador - se superó el límite de cuota.',
  'quotaAlertButton': 'Entendido',

  // Maintenance mode
  'maintenanceTitle': 'Volvemos enseguida',
  'maintenanceMessage':
      'Estamos aplicando algunas actualizaciones para mejorar tu experiencia. Vuelve a intentarlo en un momento.',
  'maintenanceHint': 'Gracias por tu paciencia.',
};

// ─────────────────────────────────────────────────────────────────────────────
// AppLocalizations class
// ─────────────────────────────────────────────────────────────────────────────

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  Map<String, String> get _strings => locale.languageCode == 'es' ? _es : _en;

  String tr(String key) => _strings[key] ?? key;

  String trArgs(String key, Map<String, String> args) {
    var result = tr(key);
    for (final e in args.entries) {
      result = result.replaceAll('{${e.key}}', e.value);
    }
    return result;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => kSupportedLocales
      .map((l) => l.languageCode)
      .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => l10n.tr(key);
  String trArgs(String key, Map<String, String> args) => l10n.trArgs(key, args);
}
