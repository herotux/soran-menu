import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_models.dart';

class ProductFormScreen extends StatefulWidget {
  final MenuItemModel? item;
  const ProductFormScreen({super.key, this.item});

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

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    name = TextEditingController(text: item?.name ?? '');
    description = TextEditingController(text: item?.description ?? '');
    price = TextEditingController(text: item?.price.toString() ?? '');
    oldPrice = TextEditingController(text: item?.oldPrice?.toString() ?? '');
    available = item?.available ?? true;
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
    if (!formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      MenuItemModel(
        id: widget.item?.id ?? const Uuid().v4(),
        name: name.text.trim(),
        description: description.text.trim(),
        price: int.parse(price.text),
        oldPrice: oldPrice.text.trim().isEmpty ? null : int.tryParse(oldPrice.text),
        image: widget.item?.image ?? '',
        available: available,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'افزودن محصول' : 'ویرایش محصول')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'نام محصول', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'نام محصول را وارد کنید' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'قیمت (هزار تومان)', border: OutlineInputBorder()),
              validator: (v) => int.tryParse(v ?? '') == null ? 'قیمت معتبر نیست' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: oldPrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'قیمت قبلی (اختیاری)', border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('محصول موجود است'),
              value: available,
              onChanged: (v) => setState(() => available = v),
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