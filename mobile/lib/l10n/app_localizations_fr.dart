// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Agent terrain Gaz';

  @override
  String get appSubtitle => 'OTP · arabe / français';

  @override
  String get login => 'Connexion';

  @override
  String get phone => 'Téléphone';

  @override
  String get requestOtp => 'Demander le code';

  @override
  String get otpCode => 'Code OTP';

  @override
  String get verify => 'Vérifier';

  @override
  String get devCode => 'Code dev';

  @override
  String get permissions => 'Autorisations';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get vehicleCheck => 'Contrôle véhicule avant départ';

  @override
  String get preTripTitle => 'Sécurité & chargement avant départ';

  @override
  String get acceptLoad => 'Accepter la charge / Démarrer le shift';

  @override
  String get starting => 'Démarrage…';

  @override
  String get assignedVehicle => 'Véhicule assigné';

  @override
  String get check1 => 'Extincteur : jauge verte, étiquette valide';

  @override
  String get check2 => 'Sangles / barres de arrimage présentes et conformes';

  @override
  String get check3 => 'Empilement conforme (soupapes protégées)';

  @override
  String get check4 => 'Pas de sifflement / odeur de mercaptan';

  @override
  String get check5 => 'Gilet haute visibilité, triangles, cales de roue';

  @override
  String get checklistMustPass => 'Tous les points de la liste doivent passer';

  @override
  String get shiftStarted => 'Shift démarré';

  @override
  String get routeMap => 'Carte itinéraire';

  @override
  String get routeArrivalTitle => 'Itinéraire & arrivée';

  @override
  String get enRoute => 'En route';

  @override
  String get arrival => 'Arrivée';

  @override
  String get confirmArrival => 'Confirmer l\'arrivée';

  @override
  String get arrived => 'Arrivé';

  @override
  String get retryGps => 'Réessayer GPS';

  @override
  String get noGps => 'Pas de fix GPS — réessayer';

  @override
  String get noRoutes => 'Aucune tournée assignée';

  @override
  String get stops => 'Arrêts';

  @override
  String get stop => 'Arrêt';

  @override
  String get tel => 'Tél';

  @override
  String get geofence => 'Géofence';

  @override
  String get distance => 'Distance';

  @override
  String get openDelivery => 'Ouvrir livraison / retours / paiement';

  @override
  String get stopSummary => 'Résumé du point';

  @override
  String get delivery => 'Livraison';

  @override
  String get returns => 'Retours';

  @override
  String get payment => 'Paiement';

  @override
  String get proof => 'Preuve / signature';

  @override
  String get reviewStop => 'Réviser le point';

  @override
  String get exception => 'Exception';

  @override
  String get deliveryTitle => 'Livraison / Retours / Paiement';

  @override
  String get recipientName => 'Nom du destinataire (preuve)';

  @override
  String get deliveredFull => 'Livrées pleines';

  @override
  String get returnedEmpty => 'Retournées vides';

  @override
  String get defective => 'Défectueuses';

  @override
  String get totalDue => 'Total dû (dépôt net inclus)';

  @override
  String get cashCollected => 'Montant encaissé (MAD)';

  @override
  String get overrideCode => 'Code manager (si crédit bloqué)';

  @override
  String get creditLocked => 'Crédit bloqué - factures impayées';

  @override
  String get noStopSelected => 'Aucun arrêt sélectionné';

  @override
  String get enterQty => 'Saisir au moins une quantité';

  @override
  String get recipientRequired => 'Nom du destinataire requis (preuve)';

  @override
  String get savedOffline =>
      'Enregistré hors ligne — sync dès le retour du réseau';

  @override
  String get finalizeStop => 'Finaliser l\'arrêt';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get receipt => 'Reçu';

  @override
  String get total => 'Total';

  @override
  String get balance => 'Solde';

  @override
  String get safetyReport => 'Signalement sécurité';

  @override
  String get safetyIncident => 'Incident sécurité';

  @override
  String get incidentType => 'Type d\'incident';

  @override
  String get severity => 'Sévérité';

  @override
  String get low => 'Faible';

  @override
  String get high => 'Élevée';

  @override
  String get critical => 'Critique';

  @override
  String get description => 'Description (fait, actions entreprises)';

  @override
  String get descriptionRequired => 'Description requise';

  @override
  String get noActiveShift => 'Aucun shift actif — démarrer d\'abord';

  @override
  String get criticalAlert =>
      'Une sévérité CRITIQUE déclenche une alerte immédite au dépôt.';

  @override
  String get submitIncident => 'Enregistrer l\'incident';

  @override
  String get submitting => 'Envoi…';

  @override
  String get incidentRecorded => 'Incident enregistré';

  @override
  String get typeLeak => 'Fuite';

  @override
  String get typeFire => 'Incendie';

  @override
  String get typeCylinderDamage => 'Bouteille endommagée';

  @override
  String get typeVehicleIncident => 'Incident véhicule';

  @override
  String get typeNearMiss => 'Quasi-accident';

  @override
  String get typeOther => 'Autre';

  @override
  String get reconciliation => 'Clôture de shift';

  @override
  String get reconciliationTitle => 'Rapprochement & déchargement';

  @override
  String get unloadDepot => 'Déchargement dépôt (par état)';

  @override
  String get full => 'Plein';

  @override
  String get empty => 'Vide';

  @override
  String get declaredCash => 'Espèces déclarées (MAD)';

  @override
  String get closeoutHelp =>
      'Remise physique + deux photos exigées pour finaliser la caisse.';

  @override
  String get noActiveShiftClose => 'Aucun shift actif';

  @override
  String get finalizeCloseout => 'Finaliser clôture / déchargement';

  @override
  String get closing => 'Clôture…';

  @override
  String get closeoutComplete => 'Clôture terminée';

  @override
  String get closeoutQueued =>
      'Enregistré hors ligne — sync dès le retour du réseau';

  @override
  String get movements => 'Mouvements';

  @override
  String get logout => 'Déconnexion';

  @override
  String get syncPending => 'Sync en attente';

  @override
  String get syncOk => 'Synchronisé';

  @override
  String get homeVehicleCheck => 'Contrôle véhicule / charge';

  @override
  String get homeRoute => 'Carte itinéraire & arrêts';

  @override
  String get homeDelivery => 'Livraison / retours / paiement';

  @override
  String get homeSafety => 'Signalement sécurité';

  @override
  String get homeReconciliation => 'Clôture & déchargement';

  @override
  String get readyPermissions => 'Prêt à demander les autorisations';

  @override
  String get enableLocation =>
      'Activer la localisation dans les paramètres système';

  @override
  String get locationDenied => 'Autorisation de localisation refusée';

  @override
  String get permissionsGranted => 'Autorisations accordées';

  @override
  String get consentTitle => 'Consentement';

  @override
  String get consentBody =>
      'La géolocalisation n\'est collectée que pendant votre shift actif.';

  @override
  String get consentNotice =>
      'La géolocalisation est collectée uniquement pendant le shift actif (démarrage → clôture). Rétention : GPS 90 jours, données commerciales 10 ans, journaux d\'audit 3 ans.';

  @override
  String get permissionsBody =>
      'Localisation avant/arrière (fenêtre de shift uniquement),\ncaméra pour photos preuve, stockage pour le mode hors ligne.';

  @override
  String get grantPermissions => 'Accorder les autorisations';

  @override
  String get ok => 'OK';

  @override
  String get langToggle => 'العربية';

  @override
  String get status_PENDING => 'En attente';

  @override
  String get status_EN_ROUTE => 'En route';

  @override
  String get status_NEARBY => 'À proximité';

  @override
  String get status_ARRIVED => 'Arrivé';

  @override
  String get status_IN_SERVICE => 'En service';

  @override
  String get status_COMPLETED => 'Terminé';

  @override
  String get status_EXCEPTION => 'Exception';

  @override
  String get status_ACTIVE => 'Actif';

  @override
  String get status_DRAFT => 'Brouillon';

  @override
  String get apiError => 'Erreur API';
}
