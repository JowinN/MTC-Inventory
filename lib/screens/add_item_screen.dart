import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/database_service.dart';
import '../models/item.dart';
import '../utils/qr_downloader.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService.instance;

  String _category = 'Audio'; // Audio or Video
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();

  bool _isSaving = false;

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    // Generate unique ID based on category prefix + timestamp
    final prefix = _category == 'Audio' ? 'AUD' : 'VID';
    final randomId = '$prefix-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final now = DateTime.now();

    final newItem = Item(
      id: randomId,
      name: _nameController.text.trim(),
      category: _category,
      brand: _brandController.text.trim(),
      model: _modelController.text.trim(),
      serialNumber: _serialController.text.trim(),
      status: 'Available',
      lastAudited: now,
      nextAuditDue: now.add(const Duration(days: 30)),
      addedDate: now,
    );

    await _databaseService.addItem(newItem);

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      _showSuccessDialog(newItem);
    }
  }

  void _showSuccessDialog(Item item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Asset Registered!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 12),
            Text(
              '${item.name} has been added to the ${item.category} inventory.',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: item.id,
                version: QrVersions.auto,
                size: 140.0,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  const Text('QR Label ID',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    item.id,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 4),
                  const Text('Print or save QR using the button below',
                      style: TextStyle(
                          color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Capture messenger BEFORE popping — context invalid after pop
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              Navigator.pop(context);
              try {
                final path = await saveAndDownloadQr(item.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('QR saved! Find it at:\n$path'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 6),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Save failed: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Add New Equipment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Card Selector
              const Text('Category', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _category = 'Audio'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _category == 'Audio' ? Colors.teal.withOpacity(0.15) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _category == 'Audio' ? Colors.tealAccent : const Color(0xFF334155),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.volume_up, color: _category == 'Audio' ? Colors.tealAccent : const Color(0xFF94A3B8), size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Audio Equipment',
                              style: TextStyle(
                                color: _category == 'Audio' ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _category = 'Video'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _category == 'Video' ? Colors.purple.withOpacity(0.15) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _category == 'Video' ? Colors.purpleAccent : const Color(0xFF334155),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.videocam, color: _category == 'Video' ? Colors.purpleAccent : const Color(0xFF94A3B8), size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Video Equipment',
                              style: TextStyle(
                                color: _category == 'Video' ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Inputs
              _buildTextField(
                controller: _nameController,
                label: 'Item Name',
                hint: 'e.g., Shure SM58 Wireless Vocal Mic',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Item name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _brandController,
                      label: 'Brand',
                      hint: 'e.g., Shure',
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Brand is required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _modelController,
                      label: 'Model',
                      hint: 'e.g., SM58-G4',
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Model is required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _serialController,
                label: 'Serial Number (S/N)',
                hint: 'e.g., SN-190284019',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Serial number is required';
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Asset & Generate QR',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
