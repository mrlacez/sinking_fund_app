import 'package:flutter/material.dart';
import '../services/drift_service.dart';
import 'add_non_member.dart';

const primaryBlue = Color(0xFF4A80F0);
const secondaryBlue = Color(0xFF6EA8FF);

class NonMembersScreen extends StatefulWidget {
  const NonMembersScreen({super.key});

  @override
  State<NonMembersScreen> createState() => _NonMembersScreenState();
}

class _NonMembersScreenState extends State<NonMembersScreen> {

  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> items = [];

  int? lastId;

  bool hasMore = true;
  bool isLoading = false;
  bool isInitialLoading = false;

  int total = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    initLoad();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

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
    if (!hasMore || isLoading) return;

    setState(() => isLoading = true);

    try {

      final data = await DriftService.getNonMembers(
        limit: 20,
        lastId: lastId,
      );

      if (data.isEmpty || data.length < 20) {
        hasMore = false;
      }

      if (data.isNotEmpty) {
        lastId = data.last['id'] as int;
      }

      if (!mounted) return;

      setState(() {
        items.addAll(data);

        total = items.length;

        isLoading = false;
      });

    } catch (e) {

      debugPrint("loadMore error: $e");

      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> refresh() async {

    setState(() {
      items.clear();

      lastId = null;

      hasMore = true;

      isInitialLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    await loadMore();

    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Non-Members"),
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

              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statCard("Total", total.toString()),
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
                      Icons.person_outline,
                      size: 50,
                      color: Colors.grey,
                    ),

                    SizedBox(height: 10),

                    Text("No non-members yet"),
                  ],
                ),
              )

                  : ListView.builder(

                physics: const AlwaysScrollableScrollPhysics(),

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

                  final n = items[i];

                  final name =
                      (n['name'] as String?) ?? "";

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
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),

                        child: Text(initial),
                      ),

                      title: Text(name),

                      onTap: () async {

                        final result =
                        await Navigator.push(

                          context,

                          MaterialPageRoute(
                            builder: (_) => AddNonMemberScreen(
                              nonMemberId:
                              n['id'] as int,

                              initialName:
                              n['name'] as String?,
                            ),
                          ),
                        );

                        if (result == true) {
                          refresh();
                        }
                      },

                      onLongPress: () => _showActions(n),
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
              builder: (_) =>
              const AddNonMemberScreen(),
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

  void _showActions(Map<String, dynamic> n) {

    if (!mounted) return;

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

                title: const Text("Edit"),

                onTap: () async {

                  Navigator.pop(context);

                  final result =
                  await Navigator.push(

                    context,

                    MaterialPageRoute(
                      builder: (_) => AddNonMemberScreen(
                        nonMemberId:
                        n['id'] as int,

                        initialName:
                        n['name'] as String?,
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

                title: const Text("Delete"),

                onTap: () async {

                  Navigator.pop(context);

                  final confirm = await showDialog(

                    context: context,

                    builder: (_) => AlertDialog(

                      title: const Text(
                        "Confirm Delete",
                      ),

                      content: Text(
                        "Delete '${n['name']}'?",
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

                    await DriftService.deleteNonMember(
                      n['id'],
                    );

                    if (!mounted) return;

                    setState(() {

                      items.removeWhere(
                            (e) => e['id'] == n['id'],
                      );

                      total = items.length;
                    });

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Deleted"),
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