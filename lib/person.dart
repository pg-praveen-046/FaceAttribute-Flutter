import 'dart:typed_data';

class Person {
  final String name;
  final String designation;
  final String email;
  final String contact;
  final String inTime;
  final String outTime;
  final Uint8List faceJpg;
  final Uint8List templates;

  const Person({
    required this.name,
    this.designation = '',
    this.email = '',
    this.contact = '',
    this.inTime = '09:00 AM',
    this.outTime = '06:00 PM',
    required this.faceJpg,
    required this.templates,
  });

  factory Person.fromMap(Map<String, dynamic> data) {
    return Person(
      name: data['name'] ?? '',
      designation: data['designation'] ?? '',
      email: data['email'] ?? '',
      contact: data['contact'] ?? '',
      inTime: data['inTime'] ?? '09:00 AM',
      outTime: data['outTime'] ?? '06:00 PM',
      faceJpg: data['faceJpg'],
      templates: data['templates'],
    );
  }

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'designation': designation,
      'email': email,
      'contact': contact,
      'inTime': inTime,
      'outTime': outTime,
      'faceJpg': faceJpg,
      'templates': templates,
    };
  }
}
