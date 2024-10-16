import 'package:flutter/material.dart';
import '../services/api_service.dart';
import './widgets/custom_bottom_nav_bar.dart';
import './widgets/loading_screen.dart';

class DepositAddScreen extends StatefulWidget {
  const DepositAddScreen({super.key});

  @override
  _DepositAddScreenState createState() => _DepositAddScreenState();
}

class _DepositAddScreenState extends State<DepositAddScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMember;
  String? _selectedType;
  String? _description;
  double? _amount;

  List<dynamic> _members = [];
  List<dynamic> _depositTypes = [];
  bool _hasError = false;
  String? _resultMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPreData();
  }

  Future<void> loadPreData() async {
    await Future.wait([
      _loadMembers(),
      _loadDepositTypes(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadMembers() async {
    final response = await ApiService.fetchMembers();
    if (response['status_code'] == 200) {
      setState(() {
        _members =
            response['items']; // Assuming 'items' contains the member list
      });
    }
  }

  Future<void> _loadDepositTypes() async {
    final response = await ApiService.fetchDepositTypes();
    if (response['status_code'] == 200) {
      setState(() {
        _depositTypes = response[
            'items']; // Assuming 'items' contains the deposit types list
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        isLoading = true;
      });

      final response = await ApiService.depositAdd({
        'member_id': _selectedMember,
        'deposit_type_id': _selectedType,
        'amount': _amount,
        'description': _description,
      });

      setState(() {
        isLoading = false;

        if (response['status'] == 200 || response['status_code'] == 200) {
          // Success message
          if (response['status_code'] == 200) {
            _resultMessage = 'Success: ${response['status_message']}';
            _hasError = false;
          } else {
            _resultMessage = 'Error: ${response['status_message']}';
            _hasError = true;
          }
        } else {
          // Error message if status_code is not 200
          _resultMessage = 'Error: ${response['message']}';
          _hasError = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Deposit')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedMember,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedMember = newValue;
                        });
                      },
                      items: _members.map<DropdownMenuItem<String>>((member) {
                        return DropdownMenuItem<String>(
                          value: member[
                              'id'], // Assuming 'id' is the unique identifier
                          child: Text(member[
                              'name']), // Assuming 'name' is the member name
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        labelText: 'Select Member',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 253, 112, 20)),
                        ),
                      ),
                      validator: (value) =>
                          value == null ? 'Please select a member' : null,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedType = newValue;
                        });
                      },
                      items: _depositTypes.map<DropdownMenuItem<String>>((type) {
                        return DropdownMenuItem<String>(
                          value: type['id'], // Assuming 'id' is the unique identifier
                          child: Text(type['name']), // Assuming 'name' is the type name
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        labelText: 'Select Deposit Type',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 253, 112, 20)),
                        ),
                      ),
                      validator: (value) => value == null ? 'Please select a deposit type' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 253, 112, 20)),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (newValue) {
                        _amount = double.tryParse(newValue ?? '0');
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a valid amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Amount must be a number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Description',
                        focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Color.fromARGB(255, 253, 112, 20)),
                        ),
                      ),
                      maxLines: 3,
                      onSaved: (newValue) {
                        _description = newValue;
                      },
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end, // Align button to the right
                      children: [
                        ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color.fromARGB(255, 253, 112, 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (_resultMessage != null)
                      Text(
                        _resultMessage!,
                        style: TextStyle(
                          color: _hasError == false
                              ? Colors.green
                              : Colors.red,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/deposit');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/expense');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/account');
          } else if (index == 4) {
            Navigator.pushNamed(context, '/settings');
          }
        },
      ),
    );
  }
}
