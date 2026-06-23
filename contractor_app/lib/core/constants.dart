/// App-wide constants for IRAMS Contractor App
/// This file centralizes all magic strings and numbers for better maintainability

// FIRESTORE COLLECTION NAMES

class FirestoreCollections {
  static const String contractors = 'Contractor'; // PascalCase to match admin
  static const String jobs = 'Jobs';
  static const String invoices = 'JobInvoice';
  static const String users = 'Users';
}

//FIRESTORE FIELD NAMES (PascalCase to match admin panel)

class ContractorFields {
  static const String contractorId = 'ContractorID';
  static const String fullName = 'FullName';
  static const String email = 'Email';
  static const String phoneNumber = 'PhoneNumber';
  static const String companyName = 'CompanyName';
  static const String companyContactPhone = 'CompanyContactPhone';
  static const String location = 'Location';
  static const String accountStatus = 'AccountStatus';
  static const String verificationStatus = 'VerificationStatus';
  static const String status = 'Status';
  static const String rating = 'Rating';
  static const String totalJobs = 'TotalJobs';
  static const String registrationDate = 'RegistrationDate';
  static const String lastLogin = 'LastLogin';
  static const String serviceTypes = 'ServiceTypes';
  static const String distance = 'Distance';
  
  // Extra fields (won't break admin)
  static const String isAvailable = 'isAvailable';
  static const String lastLocation = 'LastLocation';
  static const String lastLocationAt = 'LastLocationAt';
  static const String fcmToken = 'fcmToken';
  static const String fcmTokenUpdatedAt = 'FcmTokenUpdatedAt';
}

class JobFields {
  static const String jobId = 'JobID';
  static const String serviceType = 'ServiceType';
  static const String status = 'Status';
  static const String totalCost = 'TotalCost';
  static const String userLocation = 'UserLocation';
  static const String userId = 'UserID';
  static const String contractorAssigned = 'ContractorAssigned';
  static const String dateRequested = 'DateRequested';
  static const String dateAccepted = 'DateAccepted';
  static const String dateRejected = 'DateRejected';
  static const String dateOnTheWay = 'DateOnTheWay';
  static const String dateArrived = 'DateArrived';
  static const String dateInProgress = 'DateInProgress';
  static const String dateCompleted = 'DateCompleted';
  static const String dateCancelled = 'DateCancelled';
  static const String userGeo = 'UserGeo';
  static const String userName = 'UserName';
  static const String userPhone = 'UserPhone';
}

class ChatFields {
  static const String senderId = 'SenderId';
  static const String text = 'Text';
  static const String createdAt = 'CreatedAt';
}

// STATUS VALUES (Match admin panel)

class JobStatusValues {
  static const String pending = 'Pending';
  static const String accepted = 'Accepted';
  static const String onTheWay = 'On The Way';
  static const String arrived = 'Arrived';
  static const String inProgress = 'In Progress';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String rejected = 'Rejected';
}

class ContractorStatusValues {
  static const String available = 'Available';
  static const String unavailable = 'Unavailable';
  static const String busy = 'Busy';
  static const String offline = 'Offline';
}

class VerificationStatusValues {
  static const String pendingUpload = 'pending_upload';
  static const String underReview = 'under_review';
  static const String approved = 'approved';
  static const String rejected = 'rejected';

  static const List<String> all = [
    pendingUpload,
    underReview,
    approved,
    rejected,
  ];
}

class AccountStatusValues {
  static const String active = 'Active';
  static const String suspended = 'Suspended';
  static const String inactive = 'Inactive';
}

// VALIDATION CONSTANTS

class ValidationConstants {
  static const int minPasswordLength = 6;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;
  static const int maxNameLength = 100;
  static const int maxCompanyNameLength = 150;
  static const int maxLocationLength = 200;
  static const int maxChatMessageLength = 500;
  
  // Malaysian phone format: +60123456789
  static const String phonePattern = r'^\+?60\d{9,10}$';
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
}

// APP LIMITS & PAGINATION

class AppLimits {
  static const int maxJobsToLoad = 50;
  static const int maxMessagesToLoad = 200;
  static const int maxInvoicesPerMonth = 1000;
  static const int locationUpdateInterval = 10; // seconds
  static const int routeUpdateInterval = 30; // seconds
}

// MAP & LOCATION CONSTANTS

class MapConstants {
  static const double defaultZoom = 14.0;
  static const double maxZoom = 19.0;
  static const double minZoom = 5.0;
  static const double defaultLatitude = 3.139; // Kuala Lumpur
  static const double defaultLongitude = 101.6869;
  static const int routeStrokeWidth = 5;
  static const int markerSize = 44;
}

// UI CONSTANTS

class UIConstants {
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 999.0;
  static const double inputBorderRadius = 12.0;
  static const double padding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 48.0;
  static const double iconSizeXLarge = 80.0;
}

// ERROR MESSAGES

class ErrorMessages {
  // Auth Errors
  static const String emailRequired = 'Email is required';
  static const String invalidEmail = 'Invalid email format';
  static const String passwordRequired = 'Password is required';
  static const String passwordTooShort = 'Password must be at least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';
  static const String userNotFound = 'No account found with this email';
  static const String wrongPassword = 'Incorrect password';
  static const String userDisabled = 'This account has been disabled';
  static const String tooManyRequests = 'Too many failed attempts. Try again later';
  static const String invalidCredential = 'Invalid email or password';
  
  // Form Errors
  static const String nameRequired = 'Name is required';
  static const String phoneRequired = 'Phone is required';
  static const String invalidPhone = 'Enter valid phone number';
  static const String locationRequired = 'Location is required';
  static const String serviceTypeRequired = 'Service type is required';
  
  // Network Errors
  static const String networkError = 'Network connection failed';
  static const String timeoutError = 'Request timed out';
  static const String unknownError = 'An unexpected error occurred';
  
  // Permission Errors
  static const String locationPermissionDenied = 'Location permission denied';
  static const String locationServicesDisabled = 'Location services are disabled';
  static const String notificationPermissionDenied = 'Notification permission denied';
}

// SUCCESS MESSAGES

class SuccessMessages {
  static const String registrationSuccess = 'Registration successful! ✓';
  static const String loginSuccess = 'Login successful!';
  static const String profileUpdated = 'Profile updated successfully';
  static const String jobAccepted = 'Job accepted! ✓';
  static const String jobRejected = 'Job rejected';
  static const String jobCompleted = 'Job completed successfully! ✓';
  static const String messageSent = 'Message sent';
  static const String passwordResetSent = 'Password reset email sent';
  static const String availabilityUpdated = 'Availability updated';
}

// ROUTE NAMES

class Routes {
  static const String login = '/login';
  static const String register = '/register';
  static const String mfa = '/mfa';
  static const String home = '/';
  static const String jobDetails = '/job-details';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String earnings = '/earnings';
  static const String history = '/history';
}

// ASSET PATHS (for future use)

class Assets {
  static const String logo = 'assets/images/logo.png';
  static const String emptyJobsIcon = 'assets/images/empty_jobs.svg';
  static const String noInternetIcon = 'assets/images/no_internet.svg';
}

// API ENDPOINTS

class ApiEndpoints {
  static const String osrmRouting = 'https://router.project-osrm.org/route/v1/driving';
  static const String openStreetMapTiles = 'https://tile.openstreetmap.org';
}

// MISC CONSTANTS

class MiscConstants {
  static const String appName = 'IRAMS Contractor';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@irams.com.my';
  static const String supportPhone = '+60123456789';
  static const String currency = 'RM';
  static const String countryCode = '+60';
}
