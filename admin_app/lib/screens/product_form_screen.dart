import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/menu_models.dart';
import '../services/github_service.dart';

class ProductFormResult {
  final MenuItemModel item;
  final String categoryId;

  ProductFormResult({
    required this.item,
    required this.categoryId,
  });
}

class ProductFormScreen extends StatefulWidget {
  final MenuItemModel? item;
  final List<MenuCategory> categories;
  final String? initialCategoryId;

  const ProductFormScreen({
    super.key,
    required this.categories,
    this.item,
    this.initialCategoryId,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final formKey = GlobalKey<FormState>();
  final ImagePicker picker = ImagePicker();

  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController oldPrice;

  late bool available;
  String? categoryId;

  XFile? selectedImage;
  String imagePath = '';
  bool uploadingImage = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    name = TextEditingController(
      text: item?.name ?? '',
    );

    description = TextEditingController(
      text: item?.description ?? '',
    );

    price = TextEditingController(
      text: item?.price.toString() ?? '',
    );

    oldPrice = TextEditingController(
      text: item?.oldPrice?.toString() ?? '',
    );

    available = item?.available ?? true;
    imagePath = item?.image ?? '';

    categoryId = widget.initialCategoryId;

    if (categoryId == null && widget.categories.isNotEmpty) {
      categoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    oldPrice.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('انتخاب عکس ناموفق بود:\n$e'),
        ),
      );
    }
  }

  Future<String?> uploadSelectedImage() async {
    final image = selectedImage;

    if (image == null) {
      return imagePath;
    }

    setState(() {
      uploadingImage = true;
    });

    try {
      final bytes = await image.readAsBytes();

      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';

      final id = widget.item?.id ?? const Uuid().v4();

      final fileName = '$id.$extension';

      final uploadedPath = await GitHubService.uploadImage(
        fileName: fileName,
        bytes: bytes,
      );

      imagePath = uploadedPath;

      return uploadedPath;
    } finally {
      if (mounted) {
        setState(() {
          uploadingImage = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً دسته‌بندی را انتخاب کنید.'),
        ),
      );
      return;
    }

    final parsedPrice = int.tryParse(
      price.text.trim(),
    );

    final parsedOldPrice = oldPrice.text.trim().isEmpty
        ? null
        : int.tryParse(oldPrice.text.trim());

    if (parsedPrice == null) {
      return;
    }

    if (oldPrice.text.trim().isNotEmpty &&
        parsedOldPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('قیمت قبلی معتبر نیست.'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final finalImagePath = await uploadSelectedImage();

      final result = ProductFormResult(
        categoryId: categoryId!,
        item: MenuItemModel(
          id: widget.item?.id ?? const Uuid().v4(),
          name: name.text.trim(),
          description: description.text.trim(),
          price: parsedPrice,
          oldPrice: parsedOldPrice,
          image: finalImagePath ?? '',
          available: available,
        ),
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        result,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('آپلود عکس ناموفق بود:\n$e'),
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

  Widget buildImagePreview() {
    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          FileImage(
            selectedImage!,
          ).file,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imagePath,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              height: 220,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image,
                size: 64,
              ),
            );
          },
        ),
      );
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey,
        ),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 56,
          ),
          SizedBox(height: 8),
          Text('عکسی انتخاب نشده است'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'ویرایش محصول'
              : 'افزودن محصول',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: categoryId,
              decoration: const InputDecoration(
                labelText: 'دسته‌بندی',
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  categoryId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'دسته‌بندی را انتخاب کنید';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            const Text(
              'عکس محصول',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            buildImagePreview(),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: uploadingImage || saving
                  ? null
                  : pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Padding(
                padding: EdgeInsets.all(10),
                child: Text('انتخاب عکس از گالری'),
              ),
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'نام محصول',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'نام محصول را وارد کنید';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'توضیحات',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'قیمت (هزار تومان)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final value = int.tryParse(
                  v?.trim() ?? '',
                );

                if (value == null || value < 0) {
                  return 'قیمت معتبر نیست';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: oldPrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'قیمت قبلی (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('محصول موجود است'),
              subtitle: Text(
                available
                    ? 'در سایت نمایش داده می‌شود'
                    : 'در سایت غیرفعال است',
              ),
              value: available,
              onChanged: (value) {
                setState(() {
                  available = value;
                });
              },
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: saving ? null : save,
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
                      ? uploadingImage
                          ? 'در حال آپلود عکس...'
                          : 'در حال ذخیره...'
                      : 'ذخیره محصول',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
