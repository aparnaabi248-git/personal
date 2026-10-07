import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/finance_provider.dart';
import '../widgets/app_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isSaving = false;

  late final FinanceProvider _provider;

  /// Set once the stored profile has been copied into the fields, so a later
  /// provider notification cannot overwrite what the user is typing.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<FinanceProvider>();
    // The provider loads asynchronously, so the saved profile may not be
    // available on the first frame. Listening means the fields fill in as soon
    // as the value arrives, instead of staying blank.
    _provider.addListener(_prefillFromStore);
    _prefillFromStore();
  }

  void _prefillFromStore() {
    if (_prefilled) return;
    final UserModel user = _provider.user;
    if (user.name.isEmpty && user.email.isEmpty) return;
    _prefilled = true;
    _nameController.text = user.name;
    _emailController.text = user.email;
    _phoneController.text = user.phone;
    _addressController.text = user.address;
  }

  @override
  void dispose() {
    _provider.removeListener(_prefillFromStore);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final FinanceProvider provider = context.read<FinanceProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);

    await provider.saveUser(
      UserModel(
        id: provider.user.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      ),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Profile updated'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final UserModel user = provider.user;

    return AppShell(
      title: 'Profile',
      activeRoute: '/profile',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.green,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (user.name.isNotEmpty)
                Text(
                  user.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),

              if (user.email.isNotEmpty)
                Text(
                  user.email,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),

              const SizedBox(height: 30),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (String? v) {
                  final String text = (v ?? '').trim();
                  if (text.isEmpty) return 'Email cannot be empty';
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (String? v) {
                  final String digits =
                      (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.isNotEmpty && digits.length < 7) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _updateProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text(
                    'Update Profile',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Lifetime stats
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: const Text('Total Transactions'),
                      trailing: Text(
                        '${provider.transactions.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.trending_up, color: Colors.green),
                      title: const Text('Total Income'),
                      trailing: Text(
                        provider.moneyShort(provider.totalIncome),
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.trending_down, color: Colors.red),
                      title: const Text('Total Expense'),
                      trailing: Text(
                        provider.moneyShort(provider.totalExpense),
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.savings,
                        color: provider.balance >= 0 ? Colors.blue : Colors.red,
                      ),
                      title: const Text('Current Balance'),
                      trailing: Text(
                        provider.moneyShort(provider.balance),
                        style: TextStyle(
                          color: provider.balance >= 0 ? Colors.blue : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}