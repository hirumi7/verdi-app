class DomainException implements Exception {
  final String code;
  const DomainException(this.code);

  @override
  String toString() => 'DomainException($code)';
}
