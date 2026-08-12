import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/menu_models.dart';

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

  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController oldPrice;

  late bool available;
  String? categoryId;

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

  void save() {
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

    final result = ProductFormResult(
      categoryId: categoryId!,
      item: MenuItemModel(
        id: widget.item?.id ?? const Uuid().v4(),
        name: name.text.trim(),
        description: description.text.trim(),
        price: parsedPrice,
        oldPrice: parsedOldPrice,
        image: widget.item?.image ?? '',
        available: available,
      ),
    );

    Navigator.pop(
      context,
      result,
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
            const SizedBox(height: 14),
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
              onPressed: save,
              icon: const Icon(Icons.save),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('ذخیره محصول'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
