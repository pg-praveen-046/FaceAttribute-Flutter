import 'package:flutter/material.dart';
import 'person.dart';
import 'dart:typed_data';

class StaffEnrollmentView extends StatefulWidget {
  final Uint8List faceJpg;
  final Uint8List templates;
  final Function(Person) onEnroll;

  const StaffEnrollmentView({
    super.key,
    required this.faceJpg,
    required this.templates,
    required this.onEnroll,
  });

  @override
  State<StaffEnrollmentView> createState() => _StaffEnrollmentViewState();
}

class _StaffEnrollmentViewState extends State<StaffEnrollmentView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();

  TimeOfDay _inTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _outTime = const TimeOfDay(hour: 18, minute: 0);

  Future<void> _selectTime(BuildContext context, bool isInTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isInTime ? _inTime : _outTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.indigoAccent,
              onPrimary: Colors.white,
              surface: const Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isInTime) {
          _inTime = picked;
        } else {
          _outTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? "AM" : "PM";
    return "${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Staff Enrollment'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Preview
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.indigoAccent, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: MemoryImage(widget.faceJpg),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionHeader('Personal Information'),
              _buildTextField(_nameController, 'Full Name', Icons.person_outline,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Name is required' : null),
              _buildTextField(_designationController, 'Designation', Icons.work_outline),
              _buildTextField(_emailController, 'Email Address', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              _buildTextField(_contactController, 'Contact Number', Icons.phone_outlined,
                  keyboardType: TextInputType.phone),

              const SizedBox(height: 24),
              _buildSectionHeader('Shift Timings'),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeTile('In Time', _inTime, () => _selectTime(context, true)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeTile('Out Time', _outTime, () => _selectTime(context, false)),
                  ),
                ],
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final person = Person(
                        name: _nameController.text.trim(),
                        designation: _designationController.text.trim(),
                        email: _emailController.text.trim(),
                        contact: _contactController.text.trim(),
                        inTime: _formatTimeOfDay(_inTime),
                        outTime: _formatTimeOfDay(_outTime),
                        faceJpg: widget.faceJpg,
                        templates: widget.templates,
                      );
                      widget.onEnroll(person);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Complete Enrollment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Colors.white.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.indigoAccent.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.indigoAccent),
                const SizedBox(width: 8),
                Text(
                  _formatTimeOfDay(time),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
