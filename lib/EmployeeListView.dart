// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' hide context;
import 'person.dart';

class EmployeeListView extends StatefulWidget {
  const EmployeeListView({super.key});

  @override
  State<EmployeeListView> createState() => _EmployeeListViewState();
}

class _EmployeeListViewState extends State<EmployeeListView> {
  List<Person> _employeeList = [];
  int _totalCount = 0;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _getDB() async {
    return openDatabase(
      join(await getDatabasesPath(), 'person.db'),
    );
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final db = await _getDB();

      // Get total count from DB
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM person');
      final total = Sqflite.firstIntValue(countResult) ?? 0;

      // Get all employees
      final List<Map<String, dynamic>> maps = await db.query(
        'person',
        orderBy: 'name ASC',
      );

      final employees = List.generate(maps.length, (i) {
        return Person.fromMap(maps[i]);
      });

      setState(() {
        _totalCount = total;
        _employeeList = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Person> get _filteredList {
    if (_searchQuery.isEmpty) return _employeeList;
    return _employeeList
        .where((p) =>
            (p.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p.designation ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Employee List',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadEmployees,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Total Count Card ──
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_alt_rounded,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      // Count info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Employees',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_totalCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Showing filtered count badge
                      if (_searchQuery.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredList.length} found',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Search Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by name or designation...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor:
                          Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Section label ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        _searchQuery.isEmpty
                            ? 'All Employees'
                            : 'Search Results',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigoAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_filteredList.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.indigoAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Employee List ──
                Expanded(
                  child: _filteredList.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _filteredList.length,
                          itemBuilder: (context, index) {
                            return _buildEmployeeCard(
                                _filteredList[index], index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmployeeCard(Person person, int index) {
    final name = person.name ?? 'Unknown';
    final designation = person.designation ?? '';
    final email = person.email ?? '';
    final contact = person.contact ?? '';

    // Avatar initials
    final initials = name.trim().split(' ').take(2).map((w) {
      return w.isNotEmpty ? w[0].toUpperCase() : '';
    }).join();

    // Avatar color based on name
    final colors = [
      Colors.indigo,
      Colors.teal,
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.pink,
    ];
    final avatarColor = colors[name.codeUnitAt(0) % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: avatarColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar — photo or initials
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: person.faceJpg != null
                ? Image.memory(
                    person.faceJpg!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildInitialsAvatar(initials, avatarColor),
                  )
                : _buildInitialsAvatar(initials, avatarColor),
          ),

          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (designation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.work_outline_rounded,
                          size: 13, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        designation,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.email_outlined,
                          size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          email,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white38),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        contact,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Index number badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: avatarColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: avatarColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String initials, Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 72, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No employees enrolled yet'
                : 'No results for "$_searchQuery"',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white54,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Add employees using "Add Employee" button',
              style: TextStyle(fontSize: 13, color: Colors.white30),
            ),
          ],
        ],
      ),
    );
  }
}