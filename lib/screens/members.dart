import 'package:flutter/material.dart';
import '../services/drift_service.dart';
import 'package:sinking_fund_app/screens/add_member.dart';

const primaryBlue = Color(0xFF1E3A8A);
const secondaryBlue = Color(0xFF2563EB);

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> items = [];

  bool isLoading = false;
  bool isInitialLoading = false;
  bool hasMore = true;

  int? lastId;

  int total = 0;
  int active = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    initLoad();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> initLoad() async {
    if (isInitialLoading) return;

    setState(() => isInitialLoading = true);

    await loadMore();

    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore || !mounted) return;

    isLoading = true;

    try {

      final data = await DriftService.getMembers(
        limit: 20,
        lastId: lastId,
      );

      if (!mounted) return;

      if (data.isEmpty) {
        hasMore = false;
      } else {

        lastId = data.last['id'] as int;

        items.addAll(data);

        if (data.length < 20) {
          hasMore = false;
        }
      }

      total = items.length;
      active = items.length;

      setState(() {});

    } catch (e) {

      debugPrint("loadMore error: $e");

    } finally {

      isLoading = false;
    }
  }

  Future<void> refresh() async {
    setState(() {
      items.clear();
      lastId = null;
      hasMore = true;
      isInitialLoading = true;
    });

    await loadMore();

    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
      ),

      body: Column(
        children: [

          /// HEADER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, secondaryBlue],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCard("Total", total.toString()),
                _statCard("Active", active.toString()),
              ],
            ),
          ),

          /// LIST
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: isInitialLoading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : items.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 50,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 10),
                    Text("No members yet"),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: items.length + (hasMore ? 1 : 0),

                itemBuilder: (_, i) {

                  if (i >= items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final m = items[i];

                  final name = (m['name'] as String?) ?? "";

                  final initial =
                  name.isNotEmpty
                      ? name[0].toUpperCase()
                      : "?";

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Text(initial),
                      ),

                      title: Text(
                        name.isNotEmpty
                            ? name
                            : "Unknown",
                      ),

                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMemberScreen(
                              memberId: m['id'] as int,
                              initialName: m['name'] as String?,
                            ),
                          ),
                        );

                        if (result == true) {
                          refresh();
                        }
                      },

                      onLongPress: () => _showActions(m),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddMemberScreen(),
            ),
          );

          if (result == true) {
            refresh();
          }
        },

        child: const Icon(Icons.add),
      ),
    );
  }

  void _showActions(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),

      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const SizedBox(height: 10),

              /// EDIT
              ListTile(
                leading: const Icon(
                  Icons.edit,
                  color: Colors.blue,
                ),

                title: const Text("Edit Member"),

                onTap: () async {
                  Navigator.pop(context);

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMemberScreen(
                        memberId: m['id'] as int,
                        initialName: m['name'] as String?,
                      ),
                    ),
                  );

                  if (result == true) {
                    refresh();
                  }
                },
              ),

              /// DELETE
              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),

                title: const Text("Delete Member"),

                onTap: () async {
                  Navigator.pop(context);

                  final confirm = await showDialog(
                    context: context,

                    builder: (_) => AlertDialog(
                      title: const Text("Confirm Delete"),

                      content: Text(
                        "Delete '${m['name'] ?? 'this member'}'?",
                      ),

                      actions: [

                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),

                          child: const Text("Cancel"),
                        ),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),

                          onPressed: () =>
                              Navigator.pop(context, true),

                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await DriftService.deleteMember(m['id']);

                    if (!mounted) return;

                    setState(() {
                      items.removeWhere(
                            (e) => e['id'] == m['id'],
                      );

                      total = items.length;
                      active = items.length;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Member deleted"),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value) {
    return Column(
      children: [

        Text(
          value,

          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        Text(
          label,

          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}