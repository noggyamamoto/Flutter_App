enum FeedbackType {
  correto,
  aproximado,
  incorreto,
}

class Feedback {
  final int noteMidi;
  final FeedbackType type;

  const Feedback({
    required this.noteMidi,
    required this.type,
  });
}