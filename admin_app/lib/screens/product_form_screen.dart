import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/menu_models.dart';

class ProductFormScreen extends StatefulWidget {
  final MenuItemModel? item;

  const ProductFormScreen({
    super.key,
    this.item,
  });

  @override
  State<ProductFormScreen> createState() =>
      _ProductFormScreenState();
}

class _ProductFormScreenState
    extends State<ProductFormScreen> {
  final formKey = GlobalKey<FormState>();
  final ImagePicker picker = ImagePicker();

  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController oldPrice;

  late bool available;

  File? selectedImage;
  String imagePath = '';

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
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
      imagePath = image.path;
    });
  }

  void save() {
    if (!formKey.currentState!.validate()) {
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

    Navigator.pop(
      context,
      MenuItemModel(
        id: widget.item?.id ?? const Uuid().v4(),
        name: name.text.trim(),
        description: description.text.trim(),
        price: parsedPrice,
        oldPrice: parsedOldPrice,
        image: imagePath,
        available: available,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            editing
                ? 'ویرایش محصول'
                : 'افزودن محصول',
          ),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildImagePicker(),
              const SizedBox(height: 20),

              TextFormField(
                controller: name,
                textInputAction:
                    TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'نام محصول',
                  hintText: 'مثلاً سیب پنیری',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.fastfood_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
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
                  hintText:
                      'مواد تشکیل‌دهنده و توضیحات محصول',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.description_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: price,
                keyboardType:
                    TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'قیمت',
                  hintText: 'مثلاً 250000',
                  suffixText: 'تومان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                ),
                validator: (value) {
                  final number = int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (number == null ||
                      number < 0) {
                    return 'قیمت معتبر نیست';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: oldPrice,
                keyboardType:
                    TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'قیمت قبلی',
                  hintText:
                      'اختیاری؛ برای نمایش تخفیف',
                  suffixText: 'تومان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.local_offer_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return null;
                  }

                  final number = int.tryParse(
                    value.trim(),
                  );

                  if (number == null ||
                      number < 0) {
                    return 'قیمت قبلی معتبر نیست';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 8),

              Card(
                child: SwitchListTile(
                  title: const Text(
                    'محصول موجود است',
                  ),
                  subtitle: Text(
                    available
                        ? 'محصول در سایت نمایش داده می‌شود'
                        : 'محصول به عنوان ناموجود نمایش داده می‌شود',
                  ),
                  value: available,
                  onChanged: (value) {
                    setState(() {
                      available = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: save,
                  icon: const Icon(
                    Icons.save_outlined,
                  ),
                  label: Text(
                    editing
                        ? 'ذخیره تغییرات'
                        : 'افزودن محصول',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'تصویر محصول',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        GestureDetector(
          onTap: pickImage,
          child: Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade400,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImageContent(),
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: pickImage,
            icon: const Icon(
              Icons.photo_library_outlined,
            ),
            label: const Text(
              'انتخاب تصویر از گوشی',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent() {
    if (selectedImage != null) {
      return Image.file(
        selectedImage!,
        fit: BoxFit.cover,
      );
    }

    if (imagePath.isNotEmpty &&
        imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _emptyImage();
        },
      );
    }

    if (imagePath.isNotEmpty &&
        imagePath.startsWith('/')) {
      return _emptyImage(
        label: 'تصویر فعلی محصول',
      );
    }

    return _emptyImage();
  }

  Widget _emptyImage({
    String label = 'تصویری انتخاب نشده',
  }) {
    return Column(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 52,
          color: Colors.grey.shade500,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
