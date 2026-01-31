/// 애플리케이션 에러 코드
enum ErrorCode {
  // 인증 관련
  authInvalidCredentials('AUTH_INVALID_CREDENTIALS'),
  authTokenExpired('AUTH_TOKEN_EXPIRED'),
  authTokenInvalid('AUTH_TOKEN_INVALID'),
  authUnauthorized('AUTH_UNAUTHORIZED'),

  // 데이터 검증 관련
  validationFailed('VALIDATION_FAILED'),
  validationMissingField('VALIDATION_MISSING_FIELD'),
  validationInvalidFormat('VALIDATION_INVALID_FORMAT'),

  // 데이터 동기화 관련
  syncProductNotFound('SYNC_PRODUCT_NOT_FOUND'),
  syncCategoryNotFound('SYNC_CATEGORY_NOT_FOUND'),
  syncDataOutdated('SYNC_DATA_OUTDATED'),
  syncRequired('SYNC_REQUIRED'),

  // 판매/결제 관련
  saleProductNotFound('SALE_PRODUCT_NOT_FOUND'),
  saleProductInactive('SALE_PRODUCT_INACTIVE'),
  saleInsufficientStock('SALE_INSUFFICIENT_STOCK'),
  saleInvalidAmount('SALE_INVALID_AMOUNT'),
  saleDuplicate('SALE_DUPLICATE'),

  // 리소스 관련
  resourceNotFound('RESOURCE_NOT_FOUND'),
  resourceAlreadyExists('RESOURCE_ALREADY_EXISTS'),
  resourceConflict('RESOURCE_CONFLICT'),

  // 데이터베이스 관련
  dbConstraintViolation('DB_CONSTRAINT_VIOLATION'),
  dbForeignKeyViolation('DB_FOREIGN_KEY_VIOLATION'),
  dbUniqueViolation('DB_UNIQUE_VIOLATION'),
  dbConnectionError('DB_CONNECTION_ERROR'),

  // 서버 관련
  serverInternalError('SERVER_INTERNAL_ERROR'),
  serverTimeout('SERVER_TIMEOUT'),
  serverUnavailable('SERVER_UNAVAILABLE'),

  // 알 수 없는 오류
  unknownError('UNKNOWN_ERROR');

  const ErrorCode(this.code);
  final String code;

  static ErrorCode fromString(String code) {
    return ErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ErrorCode.unknownError,
    );
  }
}

/// 권장 조치 액션 타입
enum SuggestedAction {
  none('NONE'),
  retry('RETRY'),
  syncMasterData('SYNC_MASTER_DATA'),
  refreshToken('REFRESH_TOKEN'),
  reLogin('RE_LOGIN'),
  contactSupport('CONTACT_SUPPORT'),
  checkNetwork('CHECK_NETWORK'),
  updateApp('UPDATE_APP');

  const SuggestedAction(this.action);
  final String action;

  static SuggestedAction fromString(String action) {
    return SuggestedAction.values.firstWhere(
      (e) => e.action == action,
      orElse: () => SuggestedAction.none,
    );
  }
}
