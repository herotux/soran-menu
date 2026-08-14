import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/menu_models.dart';
import '../services/github_service.dart';
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
  final ImagePicker picker = ImagePicker();

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController phoneController;
  late final TextEditingController mobileController;
  late final TextEditingController addressController;
  late final TextEditingController instagramController;
  late final TextEditingController telegramController;

  XFile? selectedLogo;
  late String logoPath;

  bool saving = false;
  bool uploadingLogo = false;

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

    logoPath = restaurant.logo;
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

  Future<void> _pickLogo() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() {
        selectedLogo = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('انتخاب لوگو ناموفق بود:\n$e'),
        ),
      );
    }
  }

  Future<String> _uploadLogo() async {
    final image = selectedLogo;

    if (image == null) {
      return logoPath;
    }

    setState(() {
      uploadingLogo = true;
    });

    try {
      final bytes = await image.readAsBytes();

      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';

      final uploadedPath = await GitHubService.uploadImage(
        fileName: 'restaurant_logo.$extension',
        bytes: bytes,
      );

      return uploadedPath;
    } finally {
      if (mounted) {
        setState(() {
          uploadingLogo = false;
        });
      }
    }
  }

  Widget _logoPreview() {
    if (selectedLogo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(selectedLogo!.path),
          width: 180,
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    }

    if (logoPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          logoPath,
          width: 180,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: 180,
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFF5F6368)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.broken_image_outlined,
                size: 56,
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: 180,
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFF5F6368)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.restaurant,
        size: 64,
      ),
    );
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      saving = true;
    });

    try {
      final restaurant = widget.menu.restaurant;

      final finalLogo = await _uploadLogo();

      restaurant.name = nameController.text.trim();
      restaurant.description = descriptionController.text.trim();
      restaurant.phone = phoneController.text.trim();
      restaurant.mobile = mobileController.text.trim();
      restaurant.address = addressController.text.trim();
      restaurant.instagram = instagramController.text.trim();
      restaurant.telegram = telegramController.text.trim();
      restaurant.logo = finalLogo;

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
          content: Text(
            'خطا در ذخیره اطلاعات رستوران:\n$e',
          ),
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
                style: TextStyle(color: Color(0xFF5F6368)),
              ),

              const SizedBox(height: 24),

              Center(
                child: _logoPreview(),
              ),

              const SizedBox(height: 14),

              Center(
                child: OutlinedButton.icon(
                  onPressed: saving || uploadingLogo
                      ? null
                      : _pickLogo,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('انتخاب لوگوی رستوران'),
                ),
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
