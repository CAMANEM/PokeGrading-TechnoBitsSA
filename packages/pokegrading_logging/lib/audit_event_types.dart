/// Named constants for mandatory security and operational audit log events.
abstract final class AuditEventTypes {
  static const userRegister = 'user.register';
  static const userLogin = 'user.login';
  static const catalogPropose = 'catalog.propose';
  static const catalogValidate = 'catalog.validate';
  static const configChange = 'config.change';
  static const b2bApiKeyRevoke = 'b2b.api_key.revoke';
  static const b2bCatalogConsult = 'b2b.catalog.consult';
  static const securityPolyglotDetected = 'security.polyglot_detected';
}
