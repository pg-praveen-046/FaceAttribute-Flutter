import 'package:flutter/material.dart';
import 'person.dart';
import 'main.dart';

// ignore: must_be_immutable
class PersonView extends StatefulWidget {
  final List<Person> personList;
  final MyHomePageState homePageState;

  const PersonView(
      {super.key, required this.personList, required this.homePageState});

  @override
  _PersonViewState createState() => _PersonViewState();
}

class _PersonViewState extends State<PersonView> {
  deletePerson(int index) async {
    await widget.homePageState.deletePerson(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.personList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: Theme.of(context).hintColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No staff enrolled yet', style: TextStyle(color: Theme.of(context).hintColor)),
          ],
        ),
      );
    }

    return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: widget.personList.length,
        itemBuilder: (BuildContext context, int index) {
          final person = widget.personList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                _showPersonDetails(context, person);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: MemoryImage(person.faceJpg),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (person.designation.isNotEmpty)
                            Text(
                              person.designation,
                              style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      onPressed: () => deletePerson(index),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  void _showPersonDetails(BuildContext context, Person person) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.primaryColor, width: 3),
                ),
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: MemoryImage(person.faceJpg),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                person.name,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  person.designation.isNotEmpty ? person.designation.toUpperCase() : 'STAFF MEMBER',
                  style: TextStyle(fontSize: 12, color: theme.primaryColor, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 32),
              Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
              const SizedBox(height: 24),
              _buildInfoRow(context, Icons.email_outlined, 'Email', person.email.isNotEmpty ? person.email : 'N/A'),
              _buildInfoRow(context, Icons.phone_outlined, 'Contact', person.contact.isNotEmpty ? person.contact : 'N/A'),
              _buildInfoRow(context, Icons.access_time, 'Shift Time', '${person.inTime} - ${person.outTime}'),
              _buildInfoRow(context, Icons.location_on_outlined, 'Location', 'IDL'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black54),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45)),
              Text(value, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }
}
