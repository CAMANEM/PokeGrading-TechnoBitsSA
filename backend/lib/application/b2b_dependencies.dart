/// @file
/// @brief B2B persistence wiring container for server bootstrap.

/// B2B persistence dependencies wired from server bootstrap.
class B2bDependencies {
  final dynamic apiKeyRepository;
  final dynamic referenceCatalogRepository;
  final dynamic auditRepository;
  final dynamic idempotencyRepository;
  final dynamic rateLimitRepository;

  const B2bDependencies({
    required this.apiKeyRepository,
    required this.referenceCatalogRepository,
    required this.auditRepository,
    required this.idempotencyRepository,
    required this.rateLimitRepository,
  });
}
