import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AttendanceHistoryView extends StatefulWidget {
  @override
  _AttendanceHistoryViewState createState() => _AttendanceHistoryViewState();
}

class _AttendanceHistoryViewState extends State<AttendanceHistoryView> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> attendanceList = [];

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    final dbPath = await getDatabasesPath();
    final database = await openDatabase(join(dbPath, 'person.db'));
    
    final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      'SELECT a.*, p.faceJpg FROM attendance a LEFT JOIN person p ON a.name = p.name WHERE a.date = ? ORDER BY a.time DESC',
      [dateStr]
    );

    setState(() {
      attendanceList = maps;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _fetchAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Attendance History', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.deepPurpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Selected Date",
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                    ),
                  ],
                ),
                Material(
                  color: Colors.white.withOpacity(0.2),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.edit_calendar, color: Colors.white),
                    onPressed: () => _selectDate(context),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: attendanceList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text("No attendance records found.", 
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: attendanceList.length,
                    itemBuilder: (context, index) {
                      final item = attendanceList[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(item['name'] ?? 'Unknown', textAlign: TextAlign.center),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item['faceJpg'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(50.0),
                                        child: Image.memory(
                                          item['faceJpg'],
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.person, size: 100, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(
                                      (item['designation'] != null && item['designation'] != '') 
                                        ? item['designation'] 
                                        : 'No Designation',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Time: ${item['time'] ?? ''}', style: TextStyle(color: Colors.grey.shade400)),
                                    const SizedBox(height: 12),
                                    const Text('Status: Present', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 18)),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            backgroundImage: item['faceJpg'] != null ? MemoryImage(item['faceJpg']) : null,
                            child: item['faceJpg'] == null ? const Icon(Icons.person, color: Colors.lightBlueAccent, size: 28) : null,
                          ),
                          title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(item['designation'] ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item['time'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.greenAccent),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
