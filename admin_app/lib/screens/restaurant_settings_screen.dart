import 'package:flutter/material.dart';

import '../models/menu_models.dart';
import '../services/menu_repository.dart';

class RestaurantSettingsScreen extends StatefulWidget {
  final MenuData menu;
  final MenuRepository repository;

  const RestaurantSettingsScreen({
    super.key,
    required this.menu,
    required this.repository,
  });

  @override
  State<RestaurantSettingsScreen> createState() =>
      _RestaurantSettingsScreenState();
}

class _RestaurantSettingsScreenState
    extends State<RestaurantSettingsScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController phoneController;
  late final TextEditingController mobileController;
  late final TextEditingController addressController;
  late final TextEditingController instagramController;
  late final TextEditingController telegramController;
  late final TextEditingController logoController;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    final restaurant = widget.menu.restaurant;

    nameController = TextEditingController(text: restaurant.name);
    descriptionController =
        TextEditingController(text: restaurant.description);
    phoneController = TextEditingController(text: restaurant.phone);
    mobileController = TextEditingController(text: restaurant.mobile);
    addressController = TextEditingController(text: restaurant.address);
    instagramController =
        TextEditingController(text: restaurant.instagram);
    telegramController =
        TextEditingController(text: restaurant.telegram);
    logoController = TextEditingController(text: restaurant.logo);
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    mobileController.dispose();
    addressController.dispose();
    instagramController.dispose();
    telegramController.dispose();
    logoController.dispose();
    super.dispose();
  }

  InputDecoration decoration(
    String label, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      saving = true;
    });

    try {
      final restaurant = widget.menu.restaurant;

      restaurant.name = nameController.text.trim();
      restaurant.description = descriptionController.text.trim();
      restaurant.phone = phoneController.text.trim();
      restaurant.mobile = mobileController.text.trim();
      restaurant.address = addressController.text.trim();
      restaurant.instagram = instagramController.text.trim();
      restaurant.telegram = telegramController.text.trim();
      restaurant.logo = logoController.text.trim();

      await widget.repository.save(widget.menu);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اطلاعات رستوران با موفقیت ذخیره شد'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ذخیره اطلاعات رستوران:\n$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اطلاعات رستوران'),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'مشخصات رستوران',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'این اطلاعات مستقیماً در menu.json ذخیره می‌شوند.',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: nameController,
                decoration: decoration('نام رستوران'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'نام رستوران را وارد کنید';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: decoration('توضیحات رستوران'),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: decoration('شماره تلفن'),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: decoration('شماره موبایل'),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: addressController,
                maxLines: 3,
                decoration: decoration('آدرس'),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: instagramController,
                textDirection: TextDirection.ltr,
                decoration: decoration(
                  'Instagram',
                  hint: 'https://instagram.com/...',
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: telegramController,
                textDirection: TextDirection.ltr,
                decoration: decoration(
                  'Telegram',
                  hint: 'https://t.me/...',
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: logoController,
                textDirection: TextDirection.ltr,
                decoration: decoration(
                  'آدرس لوگو',
                  hint: 'مسیر یا URL لوگو',
                ),
              ),

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    saving
                        ? 'در حال ذخیره...'
                        : 'ذخیره اطلاعات رستوران',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
