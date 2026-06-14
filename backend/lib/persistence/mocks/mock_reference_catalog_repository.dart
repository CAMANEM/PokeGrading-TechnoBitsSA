import '../../domain/b2b/b2b_models.dart';
import '../b2b_data_provider/reference_catalog_repository.dart';

class MockReferenceCatalogRepository implements ReferenceCatalogRepository {
  final List<ReferenceCard> _cards;

  MockReferenceCatalogRepository({List<ReferenceCard>? cards})
      : _cards = cards ?? _defaultCards();

  static List<ReferenceCard> _defaultCards() {
    final now = DateTime.now().toUtc();
    return [
      ReferenceCard(
        id: '1',
        identity: const B2bCardIdentity(
          set: 'SVP',
          number: '1',
          edition: 'FIRST_EDITION',
          language: 'EN',
          finish: 'HOLO',
        ),
        modificationDate: now,
      ),
      ReferenceCard(
        id: '2',
        identity: const B2bCardIdentity(
          set: 'SVP',
          number: '2',
          edition: 'FIRST_EDITION',
          language: 'EN',
          finish: 'HOLO',
        ),
        modificationDate: now,
      ),
      ReferenceCard(
        id: '3',
        identity: const B2bCardIdentity(
          set: 'SVP',
          number: '2',
          edition: 'UNLIMITED',
          language: 'EN',
          finish: 'NORMAL',
        ),
        modificationDate: now,
      ),
    ];
  }

  @override
  Future<List<ReferenceCard>> findActiveMatches({
    required String set,
    required String number,
    String? edition,
    String? languageLookupName,
    String? finish,
  }) async {
    final normalizedSet = set.trim().toLowerCase();
    final cardNumber = int.tryParse(number.trim());
    if (cardNumber == null) return [];

    final matches = _cards.where((card) {
      final refNumber = int.tryParse(card.identity.number);
      if (card.identity.set.toLowerCase() != normalizedSet) return false;
      if (refNumber != cardNumber) return false;

      if (edition != null && edition.isNotEmpty) {
        if (card.identity.edition.toLowerCase() != edition.trim().toLowerCase()) {
          return false;
        }
      }

      if (languageLookupName != null && languageLookupName.isNotEmpty) {
        final code = _lookupToCode(languageLookupName);
        if (card.identity.language != code) return false;
      }

      if (finish != null && finish.isNotEmpty) {
        if (card.identity.finish.toLowerCase() != finish.trim().toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    matches.sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
    return matches;
  }

  String _lookupToCode(String lookupName) {
    final lower = lookupName.toLowerCase();
    if (lower == 'english') return 'EN';
    if (lower == 'spanish' || lower == 'español') return 'ES';
    if (lower == 'japanese') return 'JP';
    return lookupName;
  }
}
