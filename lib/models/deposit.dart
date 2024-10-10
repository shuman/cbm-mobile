class Deposit {
  final String id;
  final double amount;
  final DateTime date;

  Deposit({required this.id, required this.amount, required this.date});

  factory Deposit.fromJson(Map<String, dynamic> json) {
    return Deposit(
      id: json['id'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
    );
  }
}
