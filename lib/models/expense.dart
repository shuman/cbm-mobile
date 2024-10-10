class Expense {
  final String id;
  final double amount;
  final DateTime date;

  Expense({required this.id, required this.amount, required this.date});

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
    );
  }
}
