import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'split_screen.dart';

class HubSplitsTab extends StatefulWidget {
  final String hubId;
  final String hubName;

  const HubSplitsTab({super.key, required this.hubId, required this.hubName});

  @override
  State<HubSplitsTab> createState() => _HubSplitsTabState();
}

class _HubSplitsTabState extends State<HubSplitsTab> {
  List<dynamic> _splits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSplits();
  }

  Future<void> _fetchSplits() async {
    try {
      final splits = await ApiService.getHubSplits(widget.hubId);
      setState(() {
        _splits = splits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading splits: $e')));
      }
    }
  }

  Future<void> _togglePaid(String participantId, bool currentStatus) async {
    try {
      await ApiService.settleParticipantSplit(participantId, !currentStatus);
      _fetchSplits();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(currentStatus ? 'Marked as unpaid' : 'Marked as paid!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating payment status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SplitScreen(
                hubId: widget.hubId,
                hubName: widget.hubName,
              ),
            ),
          ).then((_) => _fetchSplits());
        },
        backgroundColor: ClosioTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _splits.isEmpty
              ? const Center(child: Text('No bill splits in this Hub.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: _splits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final split = _splits[index];
                    final event = split['event'];
                    final participants = split['participants'] as List<dynamic>? ?? [];

                    double totalSettled = 0;
                    for (var p in participants) {
                      if (p['isPaid'] == true) {
                        totalSettled += p['amountOwed'];
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: ClosioTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ClosioTheme.surfaceContainer),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  event?['title'] ?? 'Split bill',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Text(
                                '₹${split['totalAmount'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ClosioTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Settled: ₹${totalSettled.toStringAsFixed(2)} of ₹${split['totalAmount'].toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          const Text(
                            'Participants:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ClosioTheme.secondaryColor),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: participants.length,
                            itemBuilder: (context, pIndex) {
                              final p = participants[pIndex];
                              final user = p['user'];
                              final isPaid = p['isPaid'] ?? false;
                              final amount = p['amountOwed'] as num? ?? 0.0;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: ClosioTheme.surfaceContainer,
                                  backgroundImage: user?['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
                                  child: user?['avatarUrl'] == null ? const Icon(Icons.person, color: ClosioTheme.secondaryColor) : null,
                                ),
                                title: Text(user?['username'] ?? 'User'),
                                subtitle: Text('Owes: ₹${amount.toStringAsFixed(2)}'),
                                trailing: TextButton.icon(
                                  onPressed: () => _togglePaid(p['id'], isPaid),
                                  icon: Icon(
                                    isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isPaid ? Colors.green : Colors.grey,
                                  ),
                                  label: Text(
                                    isPaid ? 'Paid' : 'Mark Paid',
                                    style: TextStyle(
                                      color: isPaid ? Colors.green : Colors.grey,
                                      fontWeight: isPaid ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
