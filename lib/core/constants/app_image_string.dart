class AppImageString {
  static const String _baseImagePath = "assets/images/";

  /// Builds an icon asset path from assets/images.
  /// Example: AppImageString.icon("delete") -> assets/images/delete.png
  static String icon(String iconName, {String extension = "png"}) =>
      "$_baseImagePath$iconName.$extension";

  /// Builds any image path from assets/images.
  static String image(String fileName) => "$_baseImagePath$fileName";

  static const String siteWorkPng = "assets/images/site_work.png";
  static const String mapSiteWorkPng = "assets/images/map_locator.png";
  static const String editPenPng = "assets/images/edit_pen.png";
  static const String pinPng = "assets/images/pin.png";
  static const String googlePng = "assets/images/google.png";
  static const String microsoftPng = "assets/images/microsoft.png";
  static const String facebookPng = "assets/images/facebook.png";

  // Icon asset helpers
  static String get crossIconPng => icon("cross_icon");
  static String get pointIconPng => icon("point_icon");
  static String get pdfIconPng => icon("pdf_icon");
  static String get shareIconPng => icon("share");
  static String get locationIconPng => icon("location");
  static String get editIconPng => icon("edit_icon");
  static String get selectAreaToolsIconPng => icon("select_area_tools_icons");
  static String get lineSelectionIconPng => icon("line_selection");
  static String get deleteIconPng => icon("delete");
  static String get editFillIconPng => icon("edit-fill");
  static String get hammerPng => icon("hammer");
} 