import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class SplitScreen extends StatefulWidget {
  final String hubId;
  final String hubName;
  final bool isEmbedded;

  const SplitScreen({
    super.key, 
    required this.hubId, 
    required this.hubName,
    this.isEmbedded = false,
  });

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  
  List<dynamic> _events = [];
  List<dynamic> _members = [];
  String? _selectedEventId;
  bool _isLoading = true;
  bool _isCreating = false;

  String _splitType = 'Equal'; // 'Equal' or 'Custom'
  final Map<String, TextEditingController> _customControllers = {};
  double _remainingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _amountController.addListener(_updateRemainingAmount);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateRemainingAmount);
    _amountController.dispose();
    _descController.dispose();
    _customControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final members = await ApiService.getHubMembers(widget.hubId);
      final events = await ApiService.getHubEvents(widget.hubId);
      setState(() {
        _members = members;
        _events = events;
        if (_events.isNotEmpty) _selectedEventId = _events.first['id'];
        
        // Initialize controllers for custom split amounts
        for (var member in _members) {
          final controller = TextEditingController(text: '0.00');
          controller.addListener(_updateRemainingAmount);
          _customControllers[member['id']] = controller;
        }
        
        _isLoading = false;
      });
      _updateRemainingAmount();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _updateRemainingAmount() {
    final total = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (_splitType == 'Equal') {
      setState(() {
        _remainingAmount = 0.0;
      });
      return;
    }

    double allocated = 0.0;
    for (var controller in _customControllers.values) {
      allocated += double.tryParse(controller.text.trim()) ?? 0.0;
    }

    setState(() {
      _remainingAmount = total - allocated;
    });
  }

  Future<void> _createSplit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _selectedEventId == null || _members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount and ensure an event exists.')),
      );
      return;
    }
    
    final totalAmount = double.tryParse(amountText) ?? 0.0;
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount.')));
      return;
    }

    List<Map<String, dynamic>> participantsData = [];

    if (_splitType == 'Equal') {
      final perPerson = totalAmount / _members.length;
      participantsData = _members.map((m) => {
        'userId': m['id'],
        'amountOwed': perPerson
      }).toList();
    } else {
      double allocatedSum = 0.0;
      for (var member in _members) {
        final userId = member['id'];
        final val = double.tryParse(_customControllers[userId]?.text.trim() ?? '') ?? 0.0;
        allocatedSum += val;
        participantsData.add({
          'userId': userId,
          'amountOwed': val
        });
      }

      // Allow small float precision difference (e.g. 0.01)
      if ((allocatedSum - totalAmount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Total custom splits (₹${allocatedSum.toStringAsFixed(2)}) must match the total bill amount (₹${totalAmount.toStringAsFixed(2)}).')),
        );
        return;
      }
    }

    setState(() => _isCreating = true);
    try {
      final splitData = {
        'eventId': _selectedEventId,
        'totalAmount': totalAmount,
        'type': _splitType,
        'participants': participantsData,
      };

      await ApiService.createSplit(splitData);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill Split Created Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating split: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: widget.isEmbedded ? null : AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: const Text('Create Split', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hub: ${widget.hubName}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  if (_events.isEmpty)
                    const Text('No events in this Hub. Create an event first to split a bill.', style: TextStyle(color: Colors.red))
                  else ...[
                    DropdownButtonFormField<String>(
                      value: _selectedEventId,
                      decoration: const InputDecoration(labelText: 'Select Event'),
                      items: _events.map((event) {
                        return DropdownMenuItem<String>(
                          value: event['id'],
                          child: Text(event['title']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedEventId = val),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Amount (INR)',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Split Method:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(value: 'Equal', label: Text('Equally')),
                          ButtonSegment<String>(value: 'Custom', label: Text('Custom')),
                        ],
                        selected: {_splitType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _splitType = newSelection.first;
                          });
                          _updateRemainingAmount();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_splitType == 'Custom') ...[
                    Text(
                      _remainingAmount == 0.0
                          ? 'All amounts fully allocated.'
                          : _remainingAmount > 0
                              ? 'Remaining to allocate: ₹${_remainingAmount.toStringAsFixed(2)}'
                              : 'Over-allocated by: ₹${(-_remainingAmount).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingAmount == 0.0 ? Colors.green : (_remainingAmount > 0 ? Colors.orange : Colors.red),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final userId = member['id'];
                        final total = double.tryParse(_amountController.text.trim()) ?? 0.0;
                        final share = _splitType == 'Equal'
                            ? (total / _members.length).toStringAsFixed(2)
                            : null;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: ClosioTheme.surfaceContainer,
                            backgroundImage: member['avatarUrl'] != null ? NetworkImage(member['avatarUrl']) : null,
                            child: member['avatarUrl'] == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(member['username'] ?? 'User'),
                          trailing: _splitType == 'Equal'
                              ? Text('₹$share', style: const TextStyle(fontWeight: FontWeight.w600))
                              : SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _customControllers[userId],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.end,
                                    decoration: const InputDecoration(
                                      prefixText: '₹ ',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isCreating || _events.isEmpty) ? null : _createSplit,
                      icon: _isCreating ? const SizedBox() : const Icon(Icons.receipt),
                      label: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Bill Split'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
