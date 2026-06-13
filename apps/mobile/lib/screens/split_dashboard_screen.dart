import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/api_service.dart';

class SplitDashboardScreen extends StatefulWidget {
  const SplitDashboardScreen({super.key});

  @override
  State<SplitDashboardScreen> createState() => _SplitDashboardScreenState();
}

class _SplitDashboardScreenState extends State<SplitDashboardScreen> {
  List<dynamic> _splits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSplits();
  }

  Future<void> _fetchSplits() async {
    try {
      final splits = await ApiService.getUserSplits();
      setState(() {
        _splits = splits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payWithUpi(double amount, String upiId, String note) async {
    // UPI Intent URL format
    final upiUrl = 'upi://pay?pa=$upiId&pn=ClosioUser&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}';
    final uri = Uri.parse(upiUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI app found on this device.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: const Text('My Pending Splits', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _splits.isEmpty
              ? const Center(child: Text('You have no pending splits!'))
              : ListView.separated(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: _splits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final participation = _splits[index];
                    final split = participation['split'];
                    final event = split['event'];
                    final amountOwed = participation['amountOwed'];

                    return Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: ClosioTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ClosioTheme.surfaceContainer, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['title'] ?? 'Unknown Event',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'You Owe: ₹${amountOwed.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // Ask for UPI ID since we haven't built profile UPI saving yet
                                  _showPayDialog(amountOwed, event['title']);
                                },
                                child: const Text('Pay'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _showPayDialog(double amount, String eventName) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pay ₹${amount.toStringAsFixed(2)}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Receiver UPI ID (e.g. user@bank)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final upiId = controller.text.trim();
                if (upiId.isNotEmpty) {
                  Navigator.pop(context);
                  _payWithUpi(amount, upiId, 'Split for $eventName');
                }
              },
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }
}
