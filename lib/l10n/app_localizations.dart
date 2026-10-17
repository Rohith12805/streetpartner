import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @homeDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Dashboard'**
  String get homeDashboardTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @firebaseConfigurationMissing.
  ///
  /// In en, this message translates to:
  /// **'Firebase Configuration Missing'**
  String get firebaseConfigurationMissing;

  /// No description provided for @allAiNetworksFailedPleaseCheck.
  ///
  /// In en, this message translates to:
  /// **'All AI networks failed. Please check internet connection.'**
  String get allAiNetworksFailedPleaseCheck;

  /// No description provided for @iAmAnAiNotADoctorCallEmergency.
  ///
  /// In en, this message translates to:
  /// **'I am an AI, not a doctor. Call emergency services immediately for severe medical emergencies.'**
  String get iAmAnAiNotADoctorCallEmergency;

  /// No description provided for @aiNetworksRacing.
  ///
  /// In en, this message translates to:
  /// **'AI networks racing...'**
  String get aiNetworksRacing;

  /// No description provided for @locationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Location not found.'**
  String get locationNotFound;

  /// No description provided for @areaSafetyIndex.
  ///
  /// In en, this message translates to:
  /// **'Area Safety Index'**
  String get areaSafetyIndex;

  /// No description provided for @noCommunityRatingsYetForThisAr.
  ///
  /// In en, this message translates to:
  /// **'No community ratings yet for this area. Be the first to rate it and help others stay safe!'**
  String get noCommunityRatingsYetForThisAr;

  /// No description provided for @topReportedIssues.
  ///
  /// In en, this message translates to:
  /// **'Top Reported Issues:'**
  String get topReportedIssues;

  /// No description provided for @readReviews.
  ///
  /// In en, this message translates to:
  /// **'Read Reviews'**
  String get readReviews;

  /// No description provided for @rateThisArea.
  ///
  /// In en, this message translates to:
  /// **'Rate This Area'**
  String get rateThisArea;

  /// No description provided for @noSpecificIssuesReported.
  ///
  /// In en, this message translates to:
  /// **'No specific issues reported.'**
  String get noSpecificIssuesReported;

  /// No description provided for @simulatedOngoingCall.
  ///
  /// In en, this message translates to:
  /// **'Simulated Ongoing Call'**
  String get simulatedOngoingCall;

  /// No description provided for @editScheduledFakeCall.
  ///
  /// In en, this message translates to:
  /// **'Edit Scheduled Fake Call'**
  String get editScheduledFakeCall;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get save;

  /// No description provided for @fakeCallGenerator.
  ///
  /// In en, this message translates to:
  /// **'Fake Call Generator'**
  String get fakeCallGenerator;

  /// No description provided for @fakeCallSchedule.
  ///
  /// In en, this message translates to:
  /// **'Fake Call Schedule'**
  String get fakeCallSchedule;

  /// No description provided for @scheduleASimulatedCallToSafely.
  ///
  /// In en, this message translates to:
  /// **'Schedule a simulated call to safely exit uncomfortable situations.'**
  String get scheduleASimulatedCallToSafely;

  /// No description provided for @callerInformation.
  ///
  /// In en, this message translates to:
  /// **'Caller Information'**
  String get callerInformation;

  /// No description provided for @selectDelaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Select Delay / Schedule'**
  String get selectDelaySchedule;

  /// No description provided for @upcomingFakeCalls.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Fake Calls'**
  String get upcomingFakeCalls;

  /// No description provided for @scheduleFakeCall.
  ///
  /// In en, this message translates to:
  /// **'Schedule Fake Call'**
  String get scheduleFakeCall;

  /// No description provided for @noUpcomingFakeCallsScheduled.
  ///
  /// In en, this message translates to:
  /// **'No upcoming fake calls scheduled'**
  String get noUpcomingFakeCallsScheduled;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @cancel1.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel1;

  /// No description provided for @simulatedIncomingCall.
  ///
  /// In en, this message translates to:
  /// **'Simulated Incoming Call'**
  String get simulatedIncomingCall;

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call...'**
  String get incomingCall;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @fencing.
  ///
  /// In en, this message translates to:
  /// **'Fencing'**
  String get fencing;

  /// No description provided for @selectTheTypeOfSafetyPerimeter.
  ///
  /// In en, this message translates to:
  /// **'Select the type of safety perimeter you want to create.'**
  String get selectTheTypeOfSafetyPerimeter;

  /// No description provided for @mapOrientedNorth.
  ///
  /// In en, this message translates to:
  /// **'Map oriented North 🧭'**
  String get mapOrientedNorth;

  /// No description provided for @geoFencingSafety.
  ///
  /// In en, this message translates to:
  /// **'Geo Fencing Safety'**
  String get geoFencingSafety;

  /// No description provided for @selectGuardRadius.
  ///
  /// In en, this message translates to:
  /// **'Select Guard Radius:'**
  String get selectGuardRadius;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'APPLY'**
  String get apply;

  /// No description provided for @disableGuard.
  ///
  /// In en, this message translates to:
  /// **'DISABLE GUARD'**
  String get disableGuard;

  /// No description provided for @enableGeofenceGuard.
  ///
  /// In en, this message translates to:
  /// **'ENABLE GEOFENCE GUARD'**
  String get enableGeofenceGuard;

  /// No description provided for @sosAlertAlarmSirenCancelled.
  ///
  /// In en, this message translates to:
  /// **'SOS Alert & Alarm Siren cancelled.'**
  String get sosAlertAlarmSirenCancelled;

  /// No description provided for @activeProtectionModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Active Protection Mode Enabled.'**
  String get activeProtectionModeEnabled;

  /// No description provided for @activeProtectionModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Active Protection Mode Disabled.'**
  String get activeProtectionModeDisabled;

  /// No description provided for @cancelEmergency.
  ///
  /// In en, this message translates to:
  /// **'Cancel Emergency?'**
  String get cancelEmergency;

  /// No description provided for @areYouSureYouWantToStopSharing.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop sharing your live location and cancel the SOS alert?'**
  String get areYouSureYouWantToStopSharing;

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop Sharing'**
  String get stopSharing;

  /// No description provided for @reroute.
  ///
  /// In en, this message translates to:
  /// **'REROUTE'**
  String get reroute;

  /// No description provided for @reroutingFetchingNewDirections.
  ///
  /// In en, this message translates to:
  /// **'Rerouting... Fetching new directions.'**
  String get reroutingFetchingNewDirections;

  /// No description provided for @routeUpdatedResumingRouteGuard.
  ///
  /// In en, this message translates to:
  /// **'Route updated! Resuming Route Guard.'**
  String get routeUpdatedResumingRouteGuard;

  /// No description provided for @emergencyDispatchedLiveLocatio.
  ///
  /// In en, this message translates to:
  /// **'Emergency dispatched! Live location active.'**
  String get emergencyDispatchedLiveLocatio;

  /// No description provided for @liveLocationTrackingStopped.
  ///
  /// In en, this message translates to:
  /// **'Live location tracking stopped.'**
  String get liveLocationTrackingStopped;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @telugu.
  ///
  /// In en, this message translates to:
  /// **'Telugu'**
  String get telugu;

  /// No description provided for @tamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get tamil;

  /// No description provided for @malayalam.
  ///
  /// In en, this message translates to:
  /// **'Malayalam'**
  String get malayalam;

  /// No description provided for @kannada.
  ///
  /// In en, this message translates to:
  /// **'Kannada'**
  String get kannada;

  /// No description provided for @liveLocationSafetyIndex.
  ///
  /// In en, this message translates to:
  /// **'LIVE LOCATION & SAFETY INDEX'**
  String get liveLocationSafetyIndex;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @liveLocationActive.
  ///
  /// In en, this message translates to:
  /// **'Live Location Active'**
  String get liveLocationActive;

  /// No description provided for @yourLocationIsBeingSharedWithE.
  ///
  /// In en, this message translates to:
  /// **'Your location is being shared with emergency contacts.'**
  String get yourLocationIsBeingSharedWithE;

  /// No description provided for @activeProtectionMode.
  ///
  /// In en, this message translates to:
  /// **'Active Protection Mode'**
  String get activeProtectionMode;

  /// No description provided for @keepSosReadyInBackgroundViaNot.
  ///
  /// In en, this message translates to:
  /// **'Keep SOS ready in background with shake-to-trigger detection when outdoors.'**
  String get keepSosReadyInBackgroundViaNot;

  /// No description provided for @quickFeatures.
  ///
  /// In en, this message translates to:
  /// **'Quick Features'**
  String get quickFeatures;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My Location'**
  String get myLocation;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @proactiveProtectionSosEmergenc.
  ///
  /// In en, this message translates to:
  /// **'Proactive Protection & SOS Emergency Network'**
  String get proactiveProtectionSosEmergenc;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @signInToAccessYourSecurityDash.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your security dashboard'**
  String get signInToAccessYourSecurityDash;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @myReviews.
  ///
  /// In en, this message translates to:
  /// **'My Reviews'**
  String get myReviews;

  /// No description provided for @notAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// No description provided for @mySafetyReviews.
  ///
  /// In en, this message translates to:
  /// **'My Safety Reviews'**
  String get mySafetyReviews;

  /// No description provided for @databaseIndexRequired.
  ///
  /// In en, this message translates to:
  /// **'Database Index Required'**
  String get databaseIndexRequired;

  /// No description provided for @toViewAllYourReviewsAcrossDiff.
  ///
  /// In en, this message translates to:
  /// **'To view all your reviews across different areas, a Firestore index needs to be created. Check your console logs for the direct creation link.'**
  String get toViewAllYourReviewsAcrossDiff;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteReview.
  ///
  /// In en, this message translates to:
  /// **'Delete Review?'**
  String get deleteReview;

  /// No description provided for @areYouSureYouWantToDeleteThisS.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this safety review?'**
  String get areYouSureYouWantToDeleteThisS;

  /// No description provided for @reviewDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Review deleted successfully.'**
  String get reviewDeletedSuccessfully;

  /// No description provided for @nearbyEmergencyServices.
  ///
  /// In en, this message translates to:
  /// **'Nearby Emergency Services'**
  String get nearbyEmergencyServices;

  /// No description provided for @findingTopNearestEmergencyStat.
  ///
  /// In en, this message translates to:
  /// **'Finding top nearest emergency stations...'**
  String get findingTopNearestEmergencyStat;

  /// No description provided for @backToDashboard.
  ///
  /// In en, this message translates to:
  /// **'BACK TO DASHBOARD'**
  String get backToDashboard;

  /// No description provided for @exitInappNavigation.
  ///
  /// In en, this message translates to:
  /// **'EXIT IN-APP NAVIGATION'**
  String get exitInappNavigation;

  /// No description provided for @inappNav.
  ///
  /// In en, this message translates to:
  /// **'IN-APP NAV'**
  String get inappNav;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @uploadingPicture.
  ///
  /// In en, this message translates to:
  /// **'Uploading picture...'**
  String get uploadingPicture;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get profilePictureUpdated;

  /// No description provided for @profileManagement.
  ///
  /// In en, this message translates to:
  /// **'Profile Management'**
  String get profileManagement;

  /// No description provided for @sessionExpiredPleaseLogInAgain.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again.'**
  String get sessionExpiredPleaseLogInAgain;

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get profileNotFound;

  /// No description provided for @viewAndDeleteYourPreviousAreaR.
  ///
  /// In en, this message translates to:
  /// **'View and delete your previous area ratings'**
  String get viewAndDeleteYourPreviousAreaR;

  /// No description provided for @verifiedUser.
  ///
  /// In en, this message translates to:
  /// **'Verified User'**
  String get verifiedUser;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get personalInfo;

  /// No description provided for @bloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get bloodGroup;

  /// No description provided for @emergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get emergencyContacts;

  /// No description provided for @minimum1EmergencyContactIsRequ.
  ///
  /// In en, this message translates to:
  /// **'Minimum 1 emergency contact is required.'**
  String get minimum1EmergencyContactIsRequ;

  /// No description provided for @addEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Add Emergency Contact'**
  String get addEmergencyContact;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @editEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Edit Emergency Contact'**
  String get editEmergencyContact;

  /// No description provided for @save1.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save1;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takeAPhoto;

  /// No description provided for @pleaseFillAllMandatoryFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all mandatory fields.'**
  String get pleaseFillAllMandatoryFields;

  /// No description provided for @pleaseProvideAtLeastOneEmergen.
  ///
  /// In en, this message translates to:
  /// **'Please provide at least one emergency contact.'**
  String get pleaseProvideAtLeastOneEmergen;

  /// No description provided for @createYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Create your profile'**
  String get createYourProfile;

  /// No description provided for @setUpYourSafetyProfileSoWeCanA.
  ///
  /// In en, this message translates to:
  /// **'Set up your safety profile so we can assist you better in an emergency.'**
  String get setUpYourSafetyProfileSoWeCanA;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @text91.
  ///
  /// In en, this message translates to:
  /// **'+91'**
  String get text91;

  /// No description provided for @selectBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Select Blood Group'**
  String get selectBloodGroup;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyContact;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get completeProfile;

  /// No description provided for @failedToFetchRoute.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch route.'**
  String get failedToFetchRoute;

  /// No description provided for @pleaseSelectADestinationAndCal.
  ///
  /// In en, this message translates to:
  /// **'Please select a destination and calculate a route first.'**
  String get pleaseSelectADestinationAndCal;

  /// No description provided for @routeGuardActiveDiverting100mF.
  ///
  /// In en, this message translates to:
  /// **'Route Guard Active! Diverting 100m from this path will trigger SOS.'**
  String get routeGuardActiveDiverting100mF;

  /// No description provided for @routeFencing.
  ///
  /// In en, this message translates to:
  /// **'Route Fencing'**
  String get routeFencing;

  /// No description provided for @stopFencing.
  ///
  /// In en, this message translates to:
  /// **'STOP FENCING'**
  String get stopFencing;

  /// No description provided for @startRouteGuard.
  ///
  /// In en, this message translates to:
  /// **'START ROUTE GUARD'**
  String get startRouteGuard;

  /// No description provided for @pleaseSelectAStarRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a star rating.'**
  String get pleaseSelectAStarRating;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @safetyRatingSubmittedSuccessfu.
  ///
  /// In en, this message translates to:
  /// **'Safety rating submitted successfully!'**
  String get safetyRatingSubmittedSuccessfu;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @rateAreaSafety.
  ///
  /// In en, this message translates to:
  /// **'Rate Area Safety'**
  String get rateAreaSafety;

  /// No description provided for @selectAnyIssuesPresentOptional.
  ///
  /// In en, this message translates to:
  /// **'Select any issues present (Optional)'**
  String get selectAnyIssuesPresentOptional;

  /// No description provided for @describeYourExperienceOptional.
  ///
  /// In en, this message translates to:
  /// **'Describe your experience (Optional)'**
  String get describeYourExperienceOptional;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @areaReviews.
  ///
  /// In en, this message translates to:
  /// **'Area Reviews'**
  String get areaReviews;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @homeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Home Dashboard'**
  String get homeDashboard;

  /// No description provided for @emptyKey.
  ///
  /// In en, this message translates to:
  /// **'ಕನ್ನಡ'**
  String get emptyKey;

  /// No description provided for @sosTriggerDesc.
  ///
  /// In en, this message translates to:
  /// **'Press to trigger a 10-second emergency countdown.\nAlerts trusted contacts & sounds a siren.'**
  String get sosTriggerDesc;

  /// No description provided for @fencingFeature.
  ///
  /// In en, this message translates to:
  /// **'Fencing'**
  String get fencingFeature;

  /// No description provided for @fencingFeatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Geo & Route\nperimeters.'**
  String get fencingFeatureDesc;

  /// No description provided for @fakeCallFeature.
  ///
  /// In en, this message translates to:
  /// **'Fake Call'**
  String get fakeCallFeature;

  /// No description provided for @fakeCallFeatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Schedule a simulated\nincoming call.'**
  String get fakeCallFeatureDesc;

  /// No description provided for @emergencyFeature.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergencyFeature;

  /// No description provided for @emergencyFeatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick access to\npolice and fire.'**
  String get emergencyFeatureDesc;

  /// No description provided for @geoFencingTitle.
  ///
  /// In en, this message translates to:
  /// **'Geo Fencing'**
  String get geoFencingTitle;

  /// No description provided for @geoFencingDesc.
  ///
  /// In en, this message translates to:
  /// **'Set a circular safe zone around a specific location. Triggers SOS if you leave the area.'**
  String get geoFencingDesc;

  /// No description provided for @routeFencingTitle.
  ///
  /// In en, this message translates to:
  /// **'Route Fencing'**
  String get routeFencingTitle;

  /// No description provided for @routeFencingDesc.
  ///
  /// In en, this message translates to:
  /// **'Set a safe travel corridor to a destination. Triggers SOS if you deviate from the path.'**
  String get routeFencingDesc;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @locationEnabled.
  ///
  /// In en, this message translates to:
  /// **'Location Enabled'**
  String get locationEnabled;

  /// No description provided for @gpsTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'GPS Turned Off'**
  String get gpsTurnedOff;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location Permission Required'**
  String get locationPermissionRequired;

  /// No description provided for @enableLocationToShare.
  ///
  /// In en, this message translates to:
  /// **'Enable location to share your position'**
  String get enableLocationToShare;

  /// No description provided for @enableDeviceLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable device location to share your position'**
  String get enableDeviceLocation;

  /// No description provided for @tapToGrantGpsPermission.
  ///
  /// In en, this message translates to:
  /// **'Tap to grant permission for safety features'**
  String get tapToGrantGpsPermission;

  /// No description provided for @locatingViaGps.
  ///
  /// In en, this message translates to:
  /// **'Locating via GPS...'**
  String get locatingViaGps;

  /// No description provided for @fetchingHighAccuracyCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Fetching high-accuracy coordinates'**
  String get fetchingHighAccuracyCoordinates;

  /// No description provided for @actionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Action Needed'**
  String get actionNeeded;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @pressToTriggerCountdown.
  ///
  /// In en, this message translates to:
  /// **'Press to trigger a 10-second emergency countdown.'**
  String get pressToTriggerCountdown;

  /// No description provided for @alertsTrustedContactsAndSiren.
  ///
  /// In en, this message translates to:
  /// **'Alerts trusted contacts and sounds a siren.'**
  String get alertsTrustedContactsAndSiren;

  /// No description provided for @sosAlertActive.
  ///
  /// In en, this message translates to:
  /// **'🚨 SOS ALERT ACTIVE'**
  String get sosAlertActive;

  /// No description provided for @pressAgainToCancelOrStop.
  ///
  /// In en, this message translates to:
  /// **'Press again to cancel or stop sharing location.'**
  String get pressAgainToCancelOrStop;

  /// No description provided for @keepSosReadyInBackground.
  ///
  /// In en, this message translates to:
  /// **'Keep SOS ready in the background.'**
  String get keepSosReadyInBackground;

  /// No description provided for @staySafeStayStrong.
  ///
  /// In en, this message translates to:
  /// **'Stay Safe, Stay Strong'**
  String get staySafeStayStrong;

  /// No description provided for @yourSafetyMatters.
  ///
  /// In en, this message translates to:
  /// **'Your safety matters. We\'\'re with you always.'**
  String get yourSafetyMatters;

  /// No description provided for @safetyFeatures.
  ///
  /// In en, this message translates to:
  /// **'Safety Features'**
  String get safetyFeatures;

  /// No description provided for @toolsToHelpYouStaySafe.
  ///
  /// In en, this message translates to:
  /// **'Tools to help you stay safe, wherever you go.'**
  String get toolsToHelpYouStaySafe;

  /// No description provided for @geoFencing.
  ///
  /// In en, this message translates to:
  /// **'Geo Fencing'**
  String get geoFencing;

  /// No description provided for @geoFencingShortDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a safe perimeter around a location.'**
  String get geoFencingShortDesc;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @navigationShortDesc.
  ///
  /// In en, this message translates to:
  /// **'Access safe routes and directions.'**
  String get navigationShortDesc;

  /// No description provided for @fakeCall.
  ///
  /// In en, this message translates to:
  /// **'Fake Call'**
  String get fakeCall;

  /// No description provided for @fakeCallShortDesc.
  ///
  /// In en, this message translates to:
  /// **'Schedule a simulated incoming call.'**
  String get fakeCallShortDesc;

  /// No description provided for @emergencyServices.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergencyServices;

  /// No description provided for @emergencyServicesShortDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick access to emergency services.'**
  String get emergencyServicesShortDesc;

  /// No description provided for @emergencyNumbers.
  ///
  /// In en, this message translates to:
  /// **'Emergency Numbers'**
  String get emergencyNumbers;

  /// No description provided for @quickAccessToHelp.
  ///
  /// In en, this message translates to:
  /// **'Quick access to help when you need it.'**
  String get quickAccessToHelp;

  /// No description provided for @searchEmergencyService.
  ///
  /// In en, this message translates to:
  /// **'Search service or number (e.g., Police, 112)...'**
  String get searchEmergencyService;

  /// No description provided for @allInOneEmergency.
  ///
  /// In en, this message translates to:
  /// **'All-in-One Emergency'**
  String get allInOneEmergency;

  /// No description provided for @allInOneDesc.
  ///
  /// In en, this message translates to:
  /// **'National single emergency response for Police, Fire & Medical distress.'**
  String get allInOneDesc;

  /// No description provided for @police.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get police;

  /// No description provided for @policeDesc.
  ///
  /// In en, this message translates to:
  /// **'Immediate police intervention, crime reporting & law enforcement assistance.'**
  String get policeDesc;

  /// No description provided for @ambulance.
  ///
  /// In en, this message translates to:
  /// **'Ambulance'**
  String get ambulance;

  /// No description provided for @ambulanceDesc.
  ///
  /// In en, this message translates to:
  /// **'24/7 free emergency medical services and patient transportation.'**
  String get ambulanceDesc;

  /// No description provided for @fireServices.
  ///
  /// In en, this message translates to:
  /// **'Fire Services'**
  String get fireServices;

  /// No description provided for @fireServicesDesc.
  ///
  /// In en, this message translates to:
  /// **'Immediate fire brigade dispatch and disaster rescue operations.'**
  String get fireServicesDesc;

  /// No description provided for @womenHelpline.
  ///
  /// In en, this message translates to:
  /// **'Women Helpline'**
  String get womenHelpline;

  /// No description provided for @womenHelplineDesc.
  ///
  /// In en, this message translates to:
  /// **'24/7 emergency response, crisis intervention & support for women.'**
  String get womenHelplineDesc;

  /// No description provided for @childHelpline.
  ///
  /// In en, this message translates to:
  /// **'Child Helpline'**
  String get childHelpline;

  /// No description provided for @childHelplineDesc.
  ///
  /// In en, this message translates to:
  /// **'National 24-hour toll-free emergency care & protection for children.'**
  String get childHelplineDesc;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @couldNotOpenDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not open phone dialer for'**
  String get couldNotOpenDialer;

  /// No description provided for @failedToInitiateCall.
  ///
  /// In en, this message translates to:
  /// **'Failed to initiate call:'**
  String get failedToInitiateCall;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get userName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editName;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Confirm Log Out'**
  String get confirmLogout;

  /// No description provided for @areYouSureYouWantToLogOut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get areYouSureYouWantToLogOut;

  /// No description provided for @deleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete Contact'**
  String get deleteContact;

  /// No description provided for @areYouSureDeleteContact.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this emergency contact?'**
  String get areYouSureDeleteContact;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'hi',
    'kn',
    'ml',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
