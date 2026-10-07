class TransactionModel {
  final String id;
  final double amount;
  final String category;
  final String type; // "Income" or "Expense"
  final String note;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.type,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'type': type,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] ?? '',
      type: json['type'] ?? 'Expense',
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
    );
  }
}
