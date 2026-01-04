import 'dart:typed_data';

class Person {
  final String name;
  final String designation;
  final Uint8List faceJpg;
  final Uint8List templates;

  const Person({
    required this.name,
    this.designation = '',
    required this.faceJpg,
    required this.templates,
  });

  factory Person.fromMap(Map<String, dynamic> data) {
    return Person(
      name: data['name'] ?? '',
      designation: data['designation'] ?? '',
      faceJpg: data['faceJpg'],
      templates: data['templates'],
    );
  }

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      'name': name,
      'designation': designation,
      'faceJpg': faceJpg,
      'templates': templates,
    };
    return map;
  }
}
