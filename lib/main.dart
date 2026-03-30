// ============================================================
// TASK MANAGER APP — SINGLE FILE VERSION
// ============================================================
// HOW TO RUN:
//
// STEP 1: Create project
//   flutter create task_manager_app
//   cd task_manager_app
//
// STEP 2: Replace pubspec.yaml dependencies section with this:
//
//   dependencies:
//     flutter:
//       sdk: flutter
//     flutter_riverpod: ^2.5.1
//     shared_preferences: ^2.2.3
//     uuid: ^4.4.0
//
//   Then run: flutter pub get
//
// STEP 3: Delete everything inside lib/main.dart
//         and paste THIS ENTIRE FILE into it.
//
// STEP 4: flutter run
//
// That's it. No build_runner. No extra files.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ============================================================
// MODEL
// ============================================================

enum TaskStatus { todo, inProgress, done }

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final String? blockedBy;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.blockedBy,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    String? blockedBy,
    bool clearBlockedBy = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      blockedBy: clearBlockedBy ? null : (blockedBy ?? this.blockedBy),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'status': status.index,
        'blockedBy': blockedBy,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        dueDate: DateTime.parse(json['dueDate']),
        status: TaskStatus.values[json['status']],
        blockedBy: json['blockedBy'],
      );
}

// ============================================================
// STORAGE SERVICE
// ============================================================

class StorageService {
  static const _tasksKey = 'tasks';
  static const _draftTitleKey = 'draft_title';
  static const _draftDescKey = 'draft_description';

  static Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Task.fromJson(e)).toList();
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_tasksKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  static Future<String> getDraftTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_draftTitleKey) ?? '';
  }

  static Future<String> getDraftDesc() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_draftDescKey) ?? '';
  }

  static Future<void> saveDraftTitle(String v) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_draftTitleKey, v);
  }

  static Future<void> saveDraftDesc(String v) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_draftDescKey, v);
  }

  static Future<void> clearDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_draftTitleKey);
    prefs.remove(_draftDescKey);
  }
}

// ============================================================
// RIVERPOD STATE
// ============================================================

class TaskNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    return StorageService.loadTasks();
  }

  Future<void> addTask(Task task) async {
    final current = state.value ?? [];
    final updated = [...current, task];
    await StorageService.saveTasks(updated);
    state = AsyncData(updated);
  }

  Future<void> updateTask(Task updatedTask) async {
    final current = state.value ?? [];
    final updated = current.map((t) => t.id == updatedTask.id ? updatedTask : t).toList();
    await StorageService.saveTasks(updated);
    state = AsyncData(updated);
  }

  Future<void> deleteTask(String id) async {
    final current = state.value ?? [];
    final updated = current.where((t) => t.id != id).toList();
    await StorageService.saveTasks(updated);
    state = AsyncData(updated);
  }
}

final taskProvider = AsyncNotifierProvider<TaskNotifier, List<Task>>(TaskNotifier.new);

// ============================================================
// HELPERS
// ============================================================

bool isTaskBlocked(Task task, List<Task> allTasks) {
  if (task.blockedBy == null || task.blockedBy!.isEmpty) return false;
  try {
    final blocker = allTasks.firstWhere((t) => t.id == task.blockedBy);
    return blocker.status != TaskStatus.done;
  } catch (_) {
    return false;
  }
}

Color statusColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.done:      return Colors.green;
    case TaskStatus.inProgress: return Colors.orange;
    case TaskStatus.todo:      return Colors.blue;
  }
}

String statusLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.done:       return 'Done';
    case TaskStatus.inProgress: return 'In Progress';
    case TaskStatus.todo:       return 'To-Do';
  }
}

String statusEmoji(TaskStatus status) {
  switch (status) {
    case TaskStatus.done:       return '🟢';
    case TaskStatus.inProgress: return '🟠';
    case TaskStatus.todo:       return '🔵';
  }
}

Widget buildHighlightedText(String text, String query, {TextStyle? baseStyle}) {
  if (query.isEmpty) return Text(text, style: baseStyle);
  final matchIndex = text.toLowerCase().indexOf(query.toLowerCase());
  if (matchIndex == -1) return Text(text, style: baseStyle);

  return RichText(
    text: TextSpan(
      style: baseStyle ?? const TextStyle(color: Colors.black87, fontSize: 15),
      children: [
        TextSpan(text: text.substring(0, matchIndex)),
        TextSpan(
          text: text.substring(matchIndex, matchIndex + query.length),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.yellow,
            color: Colors.black,
          ),
        ),
        TextSpan(text: text.substring(matchIndex + query.length)),
      ],
    ),
  );
}

// ============================================================
// MAIN + APP
// ============================================================

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  String _filterStatus = 'All';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value);
    });
  }

  List<Task> _filteredTasks(List<Task> tasks) {
    final q = _searchQuery.toLowerCase();
    return tasks.where((task) {
      final matchSearch = task.title.toLowerCase().contains(q) ||
          task.description.toLowerCase().contains(q);
      final matchFilter = _filterStatus == 'All' ||
          (_filterStatus == 'To-Do' && task.status == TaskStatus.todo) ||
          (_filterStatus == 'In Progress' && task.status == TaskStatus.inProgress) ||
          (_filterStatus == 'Done' && task.status == TaskStatus.done);
      return matchSearch && matchFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text('📋 Task Manager',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterStatus,
                dropdownColor: Colors.deepPurple.shade700,
                iconEnabledColor: Colors.white,
                items: ['All', 'To-Do', 'In Progress', 'Done']
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filterStatus = val);
                },
              ),
            ),
          ),
        ],
      ),
      body: taskAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          final filtered = _filteredTasks(tasks);
          return Column(
            children: [
              // Stats bar
              Container(
                color: Colors.deepPurple,
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 14, top: 2),
                child: Row(
                  children: [
                    _statChip(tasks.where((t) => t.status == TaskStatus.todo).length,
                        'To-Do', Colors.blue.shade200),
                    const SizedBox(width: 8),
                    _statChip(
                        tasks.where((t) => t.status == TaskStatus.inProgress).length,
                        'In Progress',
                        Colors.orange.shade200),
                    const SizedBox(width: 8),
                    _statChip(tasks.where((t) => t.status == TaskStatus.done).length,
                        'Done', Colors.green.shade200),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.deepPurple),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Colors.deepPurple, width: 2),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} task${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Task list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt,
                                size: 72,
                                color: Colors.deepPurple.withOpacity(0.18)),
                            const SizedBox(height: 16),
                            const Text('No tasks found',
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 18)),
                            const SizedBox(height: 6),
                            const Text('Tap + to add your first task',
                                style: TextStyle(
                                    color: Colors.black26, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          return _TaskCard(
                            task: task,
                            allTasks: tasks,
                            searchQuery: _searchQuery,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TaskFormScreen(existingTask: task),
                              ),
                            ),
                            onDelete: () => _confirmDelete(context, task),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskFormScreen()),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task?'),
        content: Text(
            'Are you sure you want to delete "${task.title}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(taskProvider.notifier).deleteTask(task.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _statChip(int count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TASK CARD WIDGET
// ============================================================

class _TaskCard extends StatelessWidget {
  final Task task;
  final List<Task> allTasks;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.allTasks,
    required this.searchQuery,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = isTaskBlocked(task, allTasks);

    return Opacity(
      opacity: blocked ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 2,
        shadowColor: Colors.black12,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: blocked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status color bar
                Container(
                  width: 5,
                  height: 65,
                  decoration: BoxDecoration(
                    color:
                        blocked ? Colors.grey : statusColor(task.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: buildHighlightedText(
                              task.title,
                              searchQuery,
                              baseStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: blocked
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (blocked)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.lock,
                                  size: 15, color: Colors.grey),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      buildHighlightedText(
                        task.description.isEmpty
                            ? 'No description'
                            : task.description,
                        searchQuery,
                        baseStyle: TextStyle(
                          fontSize: 13,
                          color: task.description.isEmpty
                              ? Colors.black26
                              : Colors.black54,
                          fontStyle: task.description.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (blocked
                                      ? Colors.grey
                                      : statusColor(task.status))
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              blocked
                                  ? '🔒 Blocked'
                                  : '${statusEmoji(task.status)} ${statusLabel(task.status)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: blocked
                                    ? Colors.grey
                                    : statusColor(task.status),
                              ),
                            ),
                          ),
                          Text(
                            'Due: ${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black38),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Delete task',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TASK FORM SCREEN (ADD + EDIT)
// ============================================================

class TaskFormScreen extends ConsumerStatefulWidget {
  final Task? existingTask;
  const TaskFormScreen({super.key, this.existingTask});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TaskStatus _status = TaskStatus.todo;
  String? _blockedById;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final task = widget.existingTask;
    if (task != null) {
      _titleController.text = task.title;
      _descController.text = task.description;
      setState(() {
        _dueDate = task.dueDate;
        _status = task.status;
        _blockedById = task.blockedBy;
      });
    } else {
      // Load saved drafts
      final draftTitle = await StorageService.getDraftTitle();
      final draftDesc = await StorageService.getDraftDesc();
      _titleController.text = draftTitle;
      _descController.text = draftDesc;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Colors.deepPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // ⏳ Mandatory 2-second simulated async delay
    await Future.delayed(const Duration(seconds: 2));

    final isEditing = widget.existingTask != null;
    final task = Task(
      id: isEditing ? widget.existingTask!.id : const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      dueDate: _dueDate,
      status: _status,
      blockedBy: _blockedById,
    );

    if (isEditing) {
      await ref.read(taskProvider.notifier).updateTask(task);
    } else {
      await ref.read(taskProvider.notifier).addTask(task);
      await StorageService.clearDrafts();
    }

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _inputDeco(String hint, {IconData? icon}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.deepPurple)
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      );

  String _statusLabel(TaskStatus s) =>
      '${statusEmoji(s)} ${statusLabel(s)}';

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskProvider);
    final allTasks = taskAsync.value ?? [];
    final otherTasks =
        allTasks.where((t) => t.id != widget.existingTask?.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        title: Text(
          widget.existingTask == null ? '➕ New Task' : '✏️ Edit Task',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                      color: Colors.deepPurple, strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text(
                    widget.existingTask == null
                        ? 'Creating task...'
                        : 'Updating task...',
                    style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  const Text('Please wait',
                      style: TextStyle(
                          color: Colors.black38, fontSize: 13)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Title *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      onChanged: (v) => StorageService.saveDraftTitle(v),
                      decoration:
                          _inputDeco('Enter task title', icon: Icons.title),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    _label('Description'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      onChanged: (v) => StorageService.saveDraftDesc(v),
                      decoration: _inputDeco('Enter description (optional)',
                          icon: Icons.description),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),

                    _label('Due Date *'),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 20, color: Colors.deepPurple),
                            const SizedBox(width: 12),
                            Text(
                              '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right,
                                color: Colors.black38),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _label('Status *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<TaskStatus>(
                      value: _status,
                      decoration: _inputDeco(''),
                      items: TaskStatus.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(_statusLabel(s)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                    const SizedBox(height: 18),

                    _label('Blocked By (optional)'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: _blockedById,
                      decoration:
                          _inputDeco('Select a blocking task'),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text('None — not blocked')),
                        ...otherTasks.map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.title,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) =>
                          setState(() => _blockedById = val),
                    ),

                    if (_blockedById != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This task will be blocked until the selected task is marked as Done.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveTask,
                        icon: Icon(widget.existingTask == null
                            ? Icons.add_task
                            : Icons.save),
                        label: Text(
                          widget.existingTask == null
                              ? 'Create Task'
                              : 'Update Task',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.black87),
      );
}
