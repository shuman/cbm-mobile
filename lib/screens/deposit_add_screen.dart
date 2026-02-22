import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DepositAddScreen extends StatefulWidget {
  const DepositAddScreen({super.key});

  @override
  State<DepositAddScreen> createState() => _DepositAddScreenState();
}

class _DepositAddScreenState extends State<DepositAddScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMember;
  String? _selectedType;
  String? _description;
  double? _amount;

  List<dynamic> _members = [];
  List<dynamic> _depositTypes = [];
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final results = await Future.wait([
        ApiService.fetchMembers(),
        ApiService.fetchDepositTypes(),
      ]);

      if (!mounted) return;
      setState(() {
        _members = results[0]['items'] ?? [];
        _depositTypes = results[1]['items'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load form data: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    if (!mounted) return;
    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await ApiService.depositAdd({
        'member_id': _selectedMember,
        'deposit_type_id': _selectedType,
        'amount': _amount,
        'description': _description ?? '',
      });

      if (!mounted) return;
      setState(() {
        isSubmitting = false;
      });

      if (response['status_code'] == 200 || response['status'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['status_message'] ?? 'Deposit added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to add deposit'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Deposit'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedMember,
                      decoration: const InputDecoration(
                        labelText: 'Member',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _members.map<DropdownMenuItem<String>>((member) {
                        return DropdownMenuItem<String>(
                          value: member['id'].toString(),
                          child: Text(member['name'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMember = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a member' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Deposit Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _depositTypes.map<DropdownMenuItem<String>>((type) {
                        return DropdownMenuItem<String>(
                          value: type['id'].toString(),
                          child: Text(type['name'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a deposit type' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSaved: (value) {
                        _amount = double.tryParse(value ?? '0');
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: Icon(Icons.notes),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      onSaved: (value) {
                        _description = value;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Add Deposit'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
