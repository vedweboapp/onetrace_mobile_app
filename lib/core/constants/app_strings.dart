class AppStrings {
  const AppStrings._();

  static const appName = 'Red5';
  static const splashTagline = 'The Precision Engine';
  static const splashLoadingText = 'Initializing Systems';
  static const loginTitle = 'Sign In';
  static const loginOnboardingTitle = 'Track Site Work';
  static const loginOnboardingSubtitle =
      'Monitor tasks across locations in \nreal time';
  static const loginOnboarding2Title = 'Manage Drawings';
  static const loginOnboarding2Subtitle =
      'Place and track jobs directly on floor plans';
  static const loginOnboarding3Title = 'Mark Up In The Field';
  static const loginOnboarding3Subtitle =
      'Highlight scope and notes directly on your plans';
  static const loginWelcomeBack = 'Welcome back';
  static const loginWelcomeSubtitle = 'Enter your details to continue';
  static const loginEmailHintRegistered = 'Enter registered email';
  static const loginPasswordHintShort = 'Enter Password';
  static const loginSignInLower = 'Sign in';
  static const loginSignInWithOtp = 'Sign in with OTP';
  static const loginSignInWithPassword = 'Sign in with Password';
  static const loginOtpHeadline = 'Sign in with OTP';
  static const loginOtpSubtitle =
      "We'll send a one-time code to your email to verify it's you.";
  static const loginSendOtpCode = 'Send code';
  static const loginBackToPasswordSignIn = 'Sign in with password';
  static const loginNoAccountQuestion = "Don't Have An Account?";
  static const loginRequestAccessArrow = 'Request Access →';
  static const otpVerifyTitle = 'Enter Code';
  /// Forgot-password OTP step (same sheet as sign-in OTP, different labels).
  static const otpForgotPasswordVerifyTitle = 'Verify Code';
  static const otpVerifySubtitle =
      'Enter your code to reset your password';
  static const otpVerifyOtpButton = 'Verify OTP';
  static const otpLabel = 'OTP';
  static const otpResendLead = "Didn't receive the code? ";
  static const otpResendInPrefix = 'Resend in ';
  static const otpResendCta = 'Resend';
  static const emailLabel = 'Email Address';
  static const passwordLabel = 'Password';
  static const rememberMe = 'Remember me';
  static const forgotPassword = 'Forgot Password?';
  static const forgotPasswordScreenTitle = 'Forgot Password';
  static const forgotPasswordScreenSubtitle =
      'Enter your email to reset your password';
  static const forgotPasswordSendResetOtp = 'Send Reset OTP';
  static const forgotPasswordBackToLogin = 'Back to Login';
  static const forgotPasswordOnboardingTitle = 'Approve & Report';
  static const forgotPasswordOnboardingSubtitle =
      'Review work and generate client-ready reports';
  static const noAccount = "Don't have an account?";
  static const requestAccess = 'Request Access';
  static const resetPasswordScreenTitle = 'Reset Password';
  static const resetPasswordScreenSubtitle =
      'Create a strong password for your account';
  static const resetPasswordNewLabel = 'New Password';
  static const resetPasswordConfirmLabel = 'Confirm Password';
  static const resetPasswordNewHint = 'Enter new password';
  static const resetPasswordButton = 'Reset Password';
  static const passwordRuleMinLength = 'At least 8 characters';
  static const passwordRuleUppercase = 'At least one uppercase letter (A-Z)';
  static const passwordRuleLowercase = 'At least one lowercase letter (a-z)';
  static const passwordRuleNumber = 'At least one number (0-9)';
  static const passwordRuleSpecial =
      'At least one special character (!@#\$%^&*)';
  static const passwordStrengthWeak = 'WEAK';
  static const passwordStrengthFair = 'FAIR';
  static const passwordStrengthGood = 'GOOD';
  static const passwordStrengthStrong = 'STRONG';
  static const dashboardTitle = 'Dashboard';

  // --- API / network (user-visible) ---
  static const apiErrorNetwork =
      'No internet connection. Check your network and try again.';
  static const apiErrorTimeout =
      'The request took too long. Please try again.';
  static const apiErrorBadCertificate =
      'A secure connection could not be verified.';
  static const apiErrorCancelled = 'Request was cancelled.';
  static const apiErrorBadRequest =
      'We couldn\'t process that request. Please check your input.';
  static const apiErrorUnauthorized =
      'Please sign in again to continue.';
  static const apiErrorForbidden =
      'You don\'t have permission to perform this action.';
  static const apiErrorNotFound =
      'Nothing was found for this request.';
  static const apiErrorConflict =
      'This action conflicts with the current server state.';
  static const apiErrorValidation =
      'Validation failed. Check the highlighted fields.';
  static const apiErrorRateLimited =
      'Too many requests. Wait a moment and try again.';
  static const apiErrorServer =
      'Something went wrong on the server. Please try again.';
  static const apiErrorServiceUnavailable =
      'The service is unavailable. Please try again later.';
  /// When no backend message and no clearer status phrase applies.
  static const apiErrorGenericDetailFallback =
      'Something went wrong. Please try again.';
  static const apiErrorSignInFailed = 'Sign in failed';
  static const apiErrorLoadQuotes = 'Could not load quotes.';
  static const apiErrorLoadQuote = 'Could not load this quote.';
  static const apiErrorOpenCreateQuote =
      'Could not open Create Quote.';
}
