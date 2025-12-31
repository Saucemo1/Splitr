import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bill_models.dart';
import '../services/gemini_service.dart';
import '../services/bill_processor.dart';
import '../widgets/alert_message.dart';
import '../widgets/upload_panel.dart';
import '../widgets/combined_total_row.dart';
import '../theme/person_colors.dart';
import '../ui/chips/app_chip.dart';

class BillSplitterScreen extends StatefulWidget {
  const BillSplitterScreen({super.key});

  @override
  State<BillSplitterScreen> createState() => _BillSplitterScreenState();
}

class _BillSplitterScreenState extends State<BillSplitterScreen> with WidgetsBindingObserver {
  late final ImagePicker _imagePicker;
  final TextEditingController _personNameController = TextEditingController();
  final FocusNode _personNameFocusNode = FocusNode();
  bool _isRefocusing = false;
  
  File? _imageFile;
  String? _error;
  
  ParsedBill? _parsedBill;
  List<Person> _people = [];
  String? _addPersonError;
  
  ItemAssignments _itemAssignments = {};
  
  // New interaction model state
  Map<String, bool> _itemUnitModes = {}; // Track which items are in Unit Mode
  Map<String, Map<String, int>> _unitAssignments = {}; // personId -> unit count per item
  bool _hasShownLongPressTip = false;
  
  List<SplitCalculation> _splitCalculations = [];
  List<String> _selectedForSumming = [];
  Set<String> _expandedSplitCards = {}; // Track which split cards are expanded
  double? _cachedSummedTotal; // Cache the summed total
  
  // Edit/Delete functionality
  Map<String, BillItem> _editedItems = {}; // Track edited items
  Set<String> _deletedItems = {}; // Track deleted items
  List<BillItem> _originalScannedItems = []; // Store original scanned items (never modified)
  
  
  UploadState _uploadState = UploadState.idle;

  String _generateId() {
    return Random().nextInt(1000000).toString();
  }

  /// Get the original scanned item by ID (never modified)
  BillItem? _getOriginalScannedItem(String itemId) {
    try {
      return _originalScannedItems.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  /// Calculate dynamic font size for item descriptions based on character count
  double _calculateDescriptionFontSize(String description) {
    final length = description.length;
    
    // Base font size from theme
    final baseFontSize = 22.0; // Use fixed base font size to avoid context issues
    
    // Adjust font size based on character count
    if (length <= 30) {
      return baseFontSize; // Keep original size for short descriptions
    } else if (length <= 50) {
      return baseFontSize * 0.95; // Slightly smaller
    } else if (length <= 70) {
      return baseFontSize * 0.9; // Smaller
    } else if (length <= 90) {
      return baseFontSize * 0.85; // Much smaller
    } else if (length <= 120) {
      return baseFontSize * 0.8; // Very small
    } else {
      return baseFontSize * 0.75; // Minimum size for very long descriptions
    }
  }

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    _personNameFocusNode.addListener(() {
      // Only clear error when field loses focus AND it's not due to programmatic refocusing
    WidgetsBinding.instance.addObserver(this);
      if (!_personNameFocusNode.hasFocus && _addPersonError != null && !_isRefocusing) {
        setState(() {
          _addPersonError = null;
        });
      }
      // Reset the refocusing flag
      if (_personNameFocusNode.hasFocus) {
        _isRefocusing = false;
      }
    });
  }

  @override
  void dispose() {
    // Cancel any running timers or async operations
    WidgetsBinding.instance.removeObserver(this);
    // This is critical to prevent startup issues after app closure
    _personNameController.dispose();
    _personNameFocusNode.dispose();
    super.dispose();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('BillSplitterScreen lifecycle state: $state');
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Force cleanup when app is being closed/paused
      print('Cleaning up BillSplitterScreen resources...');
    }
  }

  void _cleanupResources() {
    // Clear all state to prevent memory leaks
    _imageFile = null;
    _parsedBill = null;
    _people.clear();
    _itemAssignments.clear();
    _itemUnitModes.clear();
    _unitAssignments.clear();
    _splitCalculations.clear();
    _selectedForSumming.clear();
    _expandedSplitCards.clear();
    _editedItems.clear();
    _deletedItems.clear();
    _originalScannedItems.clear();
    _cachedSummedTotal = null;
    _error = null;
    _addPersonError = null;
    _uploadState = UploadState.idle;
    
    
    // Cleanup services
    GeminiService.cleanup();
    // Clear text controllers
    _personNameController.clear();
  }
      _cleanupResources();
  }


  Future<void> _handleScanBill(File file) async {
    if (!file.existsSync()) {
      setState(() {
        _error = "No file provided for scanning.";
      });
      return;
    }

    setState(() {
      _uploadState = UploadState.loading;
      _error = null;
      _parsedBill = null;
      _itemAssignments = {};
      _itemUnitModes = {};
      _unitAssignments = {};
      _hasShownLongPressTip = false;
      _selectedForSumming = [];
    });

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final billDetails = await GeminiService.extractBillDetails(base64Image);
      
      if (mounted) setState(() {
        _parsedBill = billDetails;
        _uploadState = UploadState.ready;
        
        // Store original scanned items (never modified)
        _originalScannedItems = List<BillItem>.from(billDetails.items);
        
        final initialAssignments = <String, dynamic>{};
        
        for (final item in billDetails.items) {
          initialAssignments[item.id] = <String>[];
        }
        
        _itemAssignments = initialAssignments;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _uploadState = UploadState.idle;
      });
    }
  }

  void _cancelScanning() {
    setState(() {
      _uploadState = UploadState.idle;
      _error = null;
      _parsedBill = null;
      _imageFile = null;
      _itemAssignments = {};
      _itemUnitModes = {};
      _unitAssignments = {};
      _hasShownLongPressTip = false;
      _selectedForSumming = [];
      _originalScannedItems = []; // Clear original scanned items
    });
  }

  Future<void> _handleImageChange(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final file = File(image.path);
        setState(() {
          _imageFile = file;
          _parsedBill = null;
          _error = null;
          _selectedForSumming = [];
          _uploadState = UploadState.idle;
        });
        
        await _handleScanBill(file);
      }
    } catch (error) {
      // Handle permission errors specifically
      if (error.toString().contains('camera') || error.toString().contains('permission')) {
        _showCameraPermissionDeniedDialog();
      } else {
        setState(() {
          _error = 'Error picking image: $error';
        });
      }
    }
  }

  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      // Request permission
      final result = await Permission.camera.request();
      if (result.isGranted) {
        return true;
      } else {
        _showCameraPermissionDeniedDialog();
        return false;
      }
    }
    
    if (status.isPermanentlyDenied) {
      _showCameraPermissionDeniedDialog();
      return false;
    }
    
    return false;
  }

  void _showCameraPermissionDeniedDialog() {
    // Safety check: only show dialog if widget is still mounted
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
            'To take photos of bills, please allow camera access in Settings.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _retryScan() {
    if (_imageFile != null) {
      _handleScanBill(_imageFile!);
    }
  }

  void _handleAddPerson() {
    final name = _personNameController.text.trim();
    
    if (name.isEmpty) {
      setState(() {
        _addPersonError = "Person's name cannot be empty.";
      });
      return;
    }
    
    if (_people.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      setState(() {
        _addPersonError = "A person with this name already exists.";
      });
      return;
    }
    
    final usedColors = _people.map((p) => p.color).toList();
    final availableColors = PersonColors.colorNames.where((c) => !usedColors.contains(c)).toList();
    
    String selectedColor;
    if (availableColors.isNotEmpty) {
      selectedColor = availableColors[Random().nextInt(availableColors.length)];
    } else {
      selectedColor = PersonColors.colorNames[Random().nextInt(PersonColors.colorNames.length)];
    }
    
    setState(() {
      _people.add(Person(
        id: _generateId(),
        name: name,
        color: selectedColor,
      ));
      _personNameController.clear();
      _addPersonError = null;
    });
    
    // Keep keyboard open for adding more people
    _isRefocusing = true;
    _personNameFocusNode.requestFocus();
    
    _updateSplitCalculations();
  }

  void _handleRemovePerson(String personId) {
    setState(() {
      _people.removeWhere((p) => p.id == personId);
      _selectedForSumming.removeWhere((id) => id == personId);
      
      final updatedAssignments = <String, dynamic>{};
      for (final entry in _itemAssignments.entries) {
        final assignment = entry.value;
        if (assignment is List) {
          updatedAssignments[entry.key] = (assignment as List<String>)
              .where((id) => id != personId)
              .toList();
        } else if (assignment is Map) {
          final newAssignment = Map<String, int>.from(assignment as Map<String, int>);
          newAssignment.remove(personId);
          updatedAssignments[entry.key] = newAssignment;
        }
      }
      _itemAssignments = updatedAssignments;
    });
    
    _updateSplitCalculations();
  }

  void _handlePersonChipTap(String itemId, String personId) {
    // Use effective items to get the current item (including edits)
    final effectiveItems = _getEffectiveItems();
    final item = effectiveItems.firstWhere((i) => i.id == itemId);
    if (item == null) return;

    print('DEBUG: Person chip tapped - itemId: $itemId, personId: $personId');
    print('DEBUG: Item unit mode: ${_itemUnitModes[itemId]}');
    print('DEBUG: Current unit assignments: ${_unitAssignments[itemId]}');

    // If item is in Unit Mode, handle unit assignment clearing
    if (_itemUnitModes[itemId] == true) {
      final currentUnits = _unitAssignments[itemId]?[personId] ?? 0;
      print('DEBUG: Person $personId has $currentUnits units assigned');
      
      // If person has units assigned, clear their assignment
      if (currentUnits > 0) {
        print('DEBUG: Clearing units for person $personId');
        setState(() {
          _unitAssignments[itemId]!.remove(personId);
          
          // If no one has units assigned, exit unit mode
          if (_getTotalAssignedUnits(itemId) == 0) {
            _itemUnitModes[itemId] = false;
            print('DEBUG: Exiting unit mode - no units assigned');
          }
        });
        _updateSplitCalculations();
        print('DEBUG: After clearing - unit assignments: ${_unitAssignments[itemId]}');
      } else {
        // If person has no units, check if they should get auto-assigned remaining units
        final totalQuantity = item.quantity;
        final totalAssigned = _getTotalAssignedUnits(itemId);
        final remainingUnits = totalQuantity - totalAssigned;
        
        // Find people who have NOT been assigned any units yet
        final unassignedPeople = _people.where((person) => 
          (_unitAssignments[itemId]?[person.id] ?? 0) == 0
        ).toList();
        
        print('DEBUG: Remaining units: $remainingUnits');
        print('DEBUG: Unassigned people: ${unassignedPeople.map((p) => p.name).toList()}');
        
        // If this person is the only one left unassigned and there are remaining units, auto-assign
        if (unassignedPeople.length == 1 && remainingUnits > 0) {
          print('DEBUG: Auto-assigning $remainingUnits units to last unassigned person: $personId');
          setState(() {
            _unitAssignments[itemId]![personId] = remainingUnits;
          });
          _updateSplitCalculations();
        } else {
          print('DEBUG: Opening unit selector for person $personId');
          // Otherwise, open unit selector
          _showUnitSelector(itemId, personId);
        }
      }
      return;
    }

    print('DEBUG: Not in unit mode, handling cost split assignment');
    // Otherwise, handle cost split assignment
    setState(() {
      final currentAssignment = (_itemAssignments[itemId] as List<String>?) ?? <String>[];
      final newSelectionArray = List<String>.from(currentAssignment);
      
      if (newSelectionArray.contains(personId)) {
        newSelectionArray.remove(personId);
      } else {
        newSelectionArray.add(personId);
      }
      
      _itemAssignments[itemId] = newSelectionArray;
    });
    
    _updateSplitCalculations();
  }

  void _handlePersonChipLongPress(String itemId, String personId) {
    // Use effective items to get the current quantity (including edits)
    final effectiveItems = _getEffectiveItems();
    final item = effectiveItems.firstWhere((i) => i.id == itemId);
    if (item == null || item.quantity <= 1) return;

    _showUnitSelector(itemId, personId);
  }

  void _showUnitSelector(String itemId, String personId) {
    // Use effective items to get the current quantity (including edits)
    final effectiveItems = _getEffectiveItems();
    final item = effectiveItems.firstWhere((i) => i.id == itemId);
    if (item == null) return;

    final initialUnits = _unitAssignments[itemId]?[personId] ?? 0;
    final totalAssigned = _getTotalAssignedUnits(itemId);
    final maxUnits = item.quantity - totalAssigned + initialUnits;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: Navigator.of(context),
      ),
      builder: (context) => _buildUnitSelector(itemId, personId, initialUnits, maxUnits),
    );
  }

  Widget _buildUnitSelector(String itemId, String personId, int initialUnits, int maxUnits) {
    // Use effective items to get the current item (including edits)
    final effectiveItems = _getEffectiveItems();
    final item = effectiveItems.firstWhere((i) => i.id == itemId);
    final person = _people.firstWhere((p) => p.id == personId);
    if (item == null) return const SizedBox.shrink();

    return _UnitSelectorModal(
      item: item,
      person: person,
      initialUnits: initialUnits,
      maxUnits: maxUnits,
      totalAssigned: _getTotalAssignedUnits(itemId),
      onAssign: (finalUnits) {
        _updateUnitAssignment(itemId, personId, finalUnits - initialUnits);
      },
    );
  }

  void _updateUnitAssignment(String itemId, String personId, int delta) {
    final item = _parsedBill?.items.firstWhere((i) => i.id == itemId);
    if (item == null) return;

    setState(() {
      // Initialize unit assignments if needed
      _unitAssignments[itemId] ??= {};
      
      final currentUnits = _unitAssignments[itemId]![personId] ?? 0;
      final totalAssigned = _getTotalAssignedUnits(itemId);
      final newUnits = (currentUnits + delta).clamp(0, item.quantity - totalAssigned + currentUnits);
      
      if (newUnits <= 0) {
        _unitAssignments[itemId]!.remove(personId);
      } else {
        _unitAssignments[itemId]![personId] = newUnits;
      }
      
      // Auto-assign remaining units to the last person
      _autoAssignRemainingUnits(itemId, personId);
      
      // Activate Unit Mode if any units are assigned
      if (_getTotalAssignedUnits(itemId) > 0) {
        _itemUnitModes[itemId] = true;
      } else {
        _itemUnitModes[itemId] = false;
      }
    });
    
    _updateSplitCalculations();
  }

  int _getTotalAssignedUnits(String itemId) {
    final assignments = _unitAssignments[itemId];
    if (assignments == null) return 0;
    return assignments.values.fold<int>(0, (sum, units) => sum + units);
  }

  void _autoAssignRemainingUnits(String itemId, String currentPersonId) {
    // Get effective items to use current quantity (including edits)
    final effectiveItems = _getEffectiveItems();
    final item = effectiveItems.firstWhere((i) => i.id == itemId);
    if (item == null) return;

    final totalQuantity = item.quantity;
    final currentAssignments = _unitAssignments[itemId] ?? {};
    final totalAssigned = _getTotalAssignedUnits(itemId);
    final remainingUnits = totalQuantity - totalAssigned;

    print('DEBUG: Auto-assign for item $itemId');
    print('DEBUG: Current person: $currentPersonId');
    print('DEBUG: Total quantity: $totalQuantity');
    print('DEBUG: Total assigned: $totalAssigned');
    print('DEBUG: Remaining units: $remainingUnits');
    print('DEBUG: Current assignments: $currentAssignments');
    print('DEBUG: People count: ${_people.length}');

    // Only auto-assign if there are remaining units and we have people
    if (remainingUnits > 0 && _people.isNotEmpty) {
      // Find people who have NOT been assigned any units yet
      final unassignedPeople = _people.where((person) => 
        (currentAssignments[person.id] ?? 0) == 0
      ).toList();
      
      print('DEBUG: Unassigned people: ${unassignedPeople.map((p) => p.name).toList()}');

      // Only auto-assign if exactly 1 person is left unassigned
      if (unassignedPeople.length == 1) {
        final lastUnassignedPersonId = unassignedPeople.first.id;
        print('DEBUG: Auto-assigning $remainingUnits units to last unassigned person: $lastUnassignedPersonId');
        
        // Assign remaining units to the last unassigned person
        _unitAssignments[itemId]![lastUnassignedPersonId] = remainingUnits;
      } else {
        print('DEBUG: No auto-assignment - ${unassignedPeople.length} people still unassigned');
      }
    } else {
      print('DEBUG: No auto-assignment needed - remaining: $remainingUnits, people: ${_people.length}');
    }
  }

  void _handleSelectAll(String itemId) {
    final item = _parsedBill?.items.firstWhere((i) => i.id == itemId);
    if (item == null) return;

    // If in Unit Mode, clear all unit assignments
    if (_itemUnitModes[itemId] == true) {
      setState(() {
        _unitAssignments[itemId] = {};
        _itemUnitModes[itemId] = false;
      });
    } else {
      // Otherwise, select all for cost split
      setState(() {
        _itemAssignments[itemId] = _people.map((p) => p.id).toList();
      });
    }
    
    _updateSplitCalculations();
  }

  void _handleClearAssignment(String itemId) {
    setState(() {
      _itemAssignments[itemId] = <String>[];
      _unitAssignments[itemId] = {};
      _itemUnitModes[itemId] = false;
      
      // Don't auto-assign when clearing - let user manually assign
      // This prevents hidden assignments that aren't visible in the UI
    });
    
    _updateSplitCalculations();
  }

  void _updateSplitCalculations() {
    if (_parsedBill != null) {
      // Combine cost assignments and unit assignments for split calculations
      final combinedAssignments = Map<String, dynamic>.from(_itemAssignments);
      
      // Add unit assignments to the combined assignments
      for (final itemId in _unitAssignments.keys) {
        if (_itemUnitModes[itemId] == true) {
          combinedAssignments[itemId] = _unitAssignments[itemId]!;
        }
      }
      
      // Create effective bill with edited items for split calculations
      final effectiveItems = _getEffectiveItems();
      final effectiveTotals = _calculateEffectiveBillTotals();
      
      final effectiveBill = ParsedBill(
        items: effectiveItems,
        currency: _parsedBill!.currency,
        subtotal: _parsedBill!.subtotal,
        discounts: _parsedBill!.discounts,
        taxes: _parsedBill!.taxes,
        serviceCharges: _parsedBill!.serviceCharges,
        otherCharges: _parsedBill!.otherCharges,
        grandTotal: effectiveTotals['grandTotal'],
      );
      
      final splits = BillProcessor.calculateSplits(effectiveBill, _people, combinedAssignments);
      
      setState(() {
        _splitCalculations = splits;
        _updateSummedTotal();
      });
    } else {
      setState(() {
        _splitCalculations = [];
      });
    }
  }

  void _handleReset() {
    setState(() {
      _imageFile = null;
      _parsedBill = null;
      _people = [];
      _personNameController.clear();
      _itemAssignments = {};
      _itemUnitModes = {};
      _unitAssignments = {};
      _hasShownLongPressTip = false;
      _splitCalculations = [];
      _selectedForSumming = [];
      _cachedSummedTotal = null;
      _error = null;
      _addPersonError = null;
      _uploadState = UploadState.idle;
    });
  }

  void _handleToggleSumSelection(String personId) {
    setState(() {
      if (_selectedForSumming.contains(personId)) {
        _selectedForSumming.remove(personId);
      } else {
        _selectedForSumming.add(personId);
      }
      _updateSummedTotal();
    });
  }

  void _showSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select People for Combined Total',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._people.map((person) {
              final isSelected = _selectedForSumming.contains(person.id);
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: PersonColors.getColorTheme(person.color)['unselected'],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: PersonColors.getColorTheme(person.color)['text'],
                      ),
                    ),
                  ),
                ),
                title: Text(person.name),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (value) => _handleToggleSumSelection(person.id),
                ),
                onTap: () => _handleToggleSumSelection(person.id),
              );
            }),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _selectedForSumming.clear();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateSummedTotal() {
    if (_selectedForSumming.isEmpty) {
      _cachedSummedTotal = null;
    } else {
      _cachedSummedTotal = _splitCalculations
          .where((split) => _selectedForSumming.contains(split.personId))
          .fold<double>(0.0, (sum, split) => sum + split.totalOwed);
    }
  }

  double? get _summedTotalForSelected {
    return _cachedSummedTotal;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Splitr',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () {
              // Dismiss keyboard when tapping outside text fields
              FocusScope.of(context).unfocus();
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                AlertMessage(
                  message: _error!,
                  type: AlertType.error,
                  onDismiss: () => setState(() => _error = null),
                  onRetry: _imageFile != null ? _retryScan : null,
                ),
              
              // Section 1: Add Bill
              _buildAddBillSection(),
              
              const SizedBox(height: 12),
              
              if (_parsedBill != null) ...[
                // Section 2: Add People
                _buildAddPeopleSection(),
                
                const SizedBox(height: 12),
                
                // Section 3: Assign Items
                _buildAssignItemsSection(),
                
                const SizedBox(height: 12),
                
                // Section 4: Split Results
                if (_splitCalculations.isNotEmpty) _buildSplitResultsSection(),
                
                const SizedBox(height: 12),
                
                // Reset Button
                _buildResetButton(),
              ],
            ],
          ),
        ),
          ),
        ),
    );
  }

  Widget _buildAddBillSection() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Bill',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImagePickerButton(
                  icon: Icons.upload_file,
                  label: 'Upload',
                  onPressed: () => _handleImageChange(ImageSource.gallery),
                ),
                const SizedBox(width: 12),
                _buildImagePickerButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onPressed: () => _handleImageChange(ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: UploadPanel(
                state: _uploadState,
                previewFile: _imageFile,
                onUploadTap: () => _handleImageChange(ImageSource.gallery),
                onCameraTap: () => _handleImageChange(ImageSource.camera),
                onRetryTap: _retryScan,
                onCancelTap: _cancelScanning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    const buttonSize = 70.0;
    const iconSize = 32.0;
    
    return Column(
      children: [
        Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _uploadState == UploadState.loading ? null : onPressed,
              borderRadius: BorderRadius.circular(20),
              splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              highlightColor: Colors.transparent,
              child: Icon(
                icon, 
                size: iconSize, 
                color: _uploadState == UploadState.loading 
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _uploadState == UploadState.loading 
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAddPeopleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add People',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _personNameController,
          focusNode: _personNameFocusNode,
          decoration: InputDecoration(
            hintText: "Enter person's name",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            errorText: _addPersonError,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleAddPerson(),
          onTap: () {
            // Clear error when user starts typing
            if (_addPersonError != null) {
              setState(() {
                _addPersonError = null;
              });
            }
          },
        ),
        if (_people.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _people.map((person) {
              final colorTheme = PersonColors.getColorTheme(person.color);
              return AppChip(
                label: person.name, // full name; let chip fit it
                isSelected: false,
                backgroundColor: colorTheme['unselected'],
                selectedBackgroundColor: colorTheme['selected'],
                ringColor: colorTheme['ring'],
                responsive: true, // enable smart fit
                leading: Icon(
                  Icons.close,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                semanticsLabel: 'Remove ${person.name}',
                onTap: () => _handleRemovePerson(person.id),
                onSelectionChanged: () {}, // No haptic for remove action
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAssignItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Assign Items',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_people.isEmpty && _parsedBill!.items.isNotEmpty)
          Center(
            child: Text(
              'Add people to start assigning items.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else if (_parsedBill!.items.isEmpty)
          Center(
            child: Text(
              'No items were found in the bill.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          ..._getEffectiveItems().map((item) => _buildItemCard(item)),
        
        // Bill Summary
        if (_parsedBill != null) _buildBillSummary(),
      ],
    );
  }

  Widget _buildItemCard(BillItem item) {
    final isMultiQuantity = item.quantity > 1;
    final isInUnitMode = _itemUnitModes[item.id] == true;
    final costAssignment = (_itemAssignments[item.id] as List<String>?) ?? <String>[];
    final unitAssignment = _unitAssignments[item.id] ?? <String, int>{};
    final isEdited = _editedItems.containsKey(item.id);
    final isDeleted = _deletedItems.contains(item.id);

    // Don't show deleted items
    if (isDeleted) return const SizedBox.shrink();

    return Dismissible(
      key: Key('item_${item.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.edit,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Delete action
          return await _showDeleteConfirmation(item);
        } else if (direction == DismissDirection.endToStart) {
          // Edit action
          _showEditItemModal(item);
          return false; // Don't dismiss, just show edit modal
        }
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Item name and price
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: _calculateDescriptionFontSize(item.description),
                            color: _isDescriptionEdited(item) ? Colors.orange : null,
                          ),
                        ),
                        Text(
                          '${item.quantity} x ${BillProcessor.formatCurrency(item.totalPrice / item.quantity, _parsedBill!.currency)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isUnitPriceEdited(item) ? Colors.orange : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    BillProcessor.formatCurrency(item.totalPrice, _parsedBill!.currency),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _isQuantityOrUnitEdited(item) ? Colors.orange : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Person chips
              _buildPersonChips(item, isInUnitMode, costAssignment, unitAssignment),
              
              // First-time tip for long press and EDITED badge
              if (isMultiQuantity && !isInUnitMode && !_hasShownLongPressTip) ...[
                const SizedBox(height: 12),
                _buildLongPressTipWithEditedBadge(isEdited),
              ],
              if (isEdited && (!isMultiQuantity || isInUnitMode || _hasShownLongPressTip)) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildEditedBadge(),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonChips(BillItem item, bool isInUnitMode, List<String> costAssignment, Map<String, int> unitAssignment) {
    final isAllSelected = _people.isNotEmpty && (
      isInUnitMode 
        ? _getTotalAssignedUnits(item.id) == item.quantity
        : costAssignment.length == _people.length
    );
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // All/None chip
        Semantics(
          button: true,
          toggled: isAllSelected,
          label: isAllSelected ? 'Deselect All' : 'Select All',
          child: AppChip(
            label: '', // no text
            isSelected: isAllSelected,
            variant: AppChipVariant.utility,
            leading: Icon(
              isAllSelected ? Icons.group : Icons.group_outlined,
              size: 20,
              color: isAllSelected
                  ? Theme.of(context).colorScheme.onSecondary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            onTap: () => isAllSelected
                ? _handleClearAssignment(item.id)   // None
                : _handleSelectAll(item.id),        // All
          ),
        ),
        
        // Person chips
        ..._people.map((person) {
          final isPersonSelected = isInUnitMode 
              ? (unitAssignment[person.id] ?? 0) > 0
              : costAssignment.contains(person.id);
          final colorTheme = PersonColors.getColorTheme(person.color);
          final unitCount = unitAssignment[person.id] ?? 0;
          
          return GestureDetector(
            onLongPress: () => _handlePersonChipLongPress(item.id, person.id),
            child: AppChip(
              label: isInUnitMode && unitCount > 0 
                  ? '${person.name} • $unitCount'
                  : person.name,
              isSelected: isPersonSelected,
              variant: AppChipVariant.tonal, // Use tonal variant with ringColor support
              backgroundColor: colorTheme['unselected'],
              selectedBackgroundColor: colorTheme['selected'],
              ringColor: colorTheme['ring'],
              onTap: () => _handlePersonChipTap(item.id, person.id),
              onSelectionChanged: () => _handlePersonChipTap(item.id, person.id),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLongPressTip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'Long press to assign units.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'EDITED',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLongPressTipWithEditedBadge(bool isEdited) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Long press to assign units.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isEdited) ...[
          const SizedBox(width: 8),
          _buildEditedBadge(),
        ],
      ],
    );
  }

  bool _isDescriptionEdited(BillItem item) {
    if (!_editedItems.containsKey(item.id)) return false;
    final editedItem = _editedItems[item.id]!;
    return editedItem.description != item.description;
  }

  bool _isQuantityOrUnitEdited(BillItem item) {
    if (!_editedItems.containsKey(item.id)) return false;
    final editedItem = _editedItems[item.id]!;
    return editedItem.quantity != item.quantity || 
           (editedItem.unitPrice ?? (editedItem.totalPrice / editedItem.quantity)) != 
           (item.unitPrice ?? (item.totalPrice / item.quantity));
  }

  bool _isUnitPriceEdited(BillItem item) {
    if (!_editedItems.containsKey(item.id)) return false;
    final editedItem = _editedItems[item.id]!;
    return (editedItem.unitPrice ?? (editedItem.totalPrice / editedItem.quantity)) != 
           (item.unitPrice ?? (item.totalPrice / item.quantity));
  }

  bool _hasAnyEditedItems() {
    return _editedItems.isNotEmpty;
  }

  Map<String, dynamic> _calculateEffectiveBillTotals() {
    final effectiveItems = _getEffectiveItems();
    final bill = _parsedBill!;
    
    // Calculate effective subtotal from edited items
    final effectiveSubtotal = effectiveItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    
    // Calculate effective grand total
    final effectiveGrandTotal = effectiveSubtotal +
        bill.taxes.fold<double>(0.0, (s, t) => s + t.amount) +
        bill.serviceCharges.fold<double>(0.0, (s, t) => s + t.amount) +
        bill.otherCharges.fold<double>(0.0, (s, t) => s + t.amount) -
        bill.discounts.fold<double>(0.0, (s, t) => s + t.amount);
    
    return {
      'subtotal': effectiveSubtotal,
      'grandTotal': effectiveGrandTotal,
      'itemsTotal': effectiveItems.fold<double>(0.0, (s, i) => s + i.totalPrice),
    };
  }

  Future<bool> _showDeleteConfirmation(BillItem item) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              _deleteItem(item);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _deleteItem(BillItem item) {
    setState(() {
      _deletedItems.add(item.id);
      // Remove any assignments for this item
      _itemAssignments.remove(item.id);
      _unitAssignments.remove(item.id);
      _itemUnitModes.remove(item.id);
    });
    HapticFeedback.lightImpact();
  }

  void _showEditItemModal(BillItem item) {
    final isEdited = _editedItems.containsKey(item.id);
    final editedItem = isEdited ? _editedItems[item.id]! : item;
    final originalScannedItem = _getOriginalScannedItem(item.id) ?? item;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditItemModal(
        item: editedItem,
        originalItem: originalScannedItem, // Pass the truly original scanned item
        currency: _parsedBill!.currency,
        onSave: (updatedItem) {
          setState(() {
            _editedItems[item.id] = updatedItem;
            
            // Clear unit assignments if new quantity is less than total assigned units
            final totalAssignedUnits = _getTotalAssignedUnits(item.id);
            if (updatedItem.quantity < totalAssignedUnits) {
              // Clear all unit assignments for this item
              _unitAssignments.remove(item.id);
              _itemUnitModes.remove(item.id);
            }
          });
          HapticFeedback.lightImpact();
        },
        onPreview: (previewItem) {
          setState(() {
            _editedItems[item.id] = previewItem;
            
            // Clear unit assignments if new quantity is less than total assigned units
            final totalAssignedUnits = _getTotalAssignedUnits(item.id);
            if (previewItem.quantity < totalAssignedUnits) {
              // Clear all unit assignments for this item
              _unitAssignments.remove(item.id);
              _itemUnitModes.remove(item.id);
            }
          });
          // Call _updateSplitCalculations after setState completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateSplitCalculations();
          });
        },
      ),
    );
  }

  /// Get the effective items list considering edits and deletions
  List<BillItem> _getEffectiveItems() {
    if (_parsedBill == null) return [];
    
    return _parsedBill!.items
        .where((item) => !_deletedItems.contains(item.id))
        .map((item) => _editedItems[item.id] ?? item)
        .toList();
  }

  Widget _buildBillSummary() {
    final bill = _parsedBill!;
    final effectiveTotals = _calculateEffectiveBillTotals();
    final hasEdits = _hasAnyEditedItems();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Show original subtotal if it exists, otherwise show effective subtotal
          if (bill.subtotal != null) ...[
            _buildSummaryRow('Original Subtotal:', BillProcessor.formatCurrency(bill.subtotal, bill.currency)),
            _buildSummaryRow('Effective Subtotal:', BillProcessor.formatCurrency(effectiveTotals['subtotal'], bill.currency), isOrange: hasEdits),
          ] else ...[
            _buildSummaryRow('Subtotal:', BillProcessor.formatCurrency(effectiveTotals['subtotal'], bill.currency), isOrange: hasEdits),
          ],
          // Additional Charges Section
          if (bill.discounts.isNotEmpty || bill.taxes.isNotEmpty || bill.serviceCharges.isNotEmpty || bill.otherCharges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Additional Charges',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Discounts
          if (bill.discounts.isNotEmpty) ...[
            ...bill.discounts.map((d) => _buildSummaryRow('${d.description}:', '- ${BillProcessor.formatCurrency(d.amount, bill.currency)}', isDiscount: true)),
          ],
          // Taxes
          if (bill.taxes.isNotEmpty) ...[
            ...bill.taxes.map((t) => _buildSummaryRow('${t.description}:', BillProcessor.formatCurrency(t.amount, bill.currency))),
          ],
          // Service Charges
          if (bill.serviceCharges.isNotEmpty) ...[
            ...bill.serviceCharges.map((sc) => _buildSummaryRow('${sc.description}:', BillProcessor.formatCurrency(sc.amount, bill.currency))),
          ],
          // Other Charges
          if (bill.otherCharges.isNotEmpty) ...[
            ...bill.otherCharges.map((oc) => _buildSummaryRow('${oc.description}:', BillProcessor.formatCurrency(oc.amount, bill.currency))),
          ],
          // Show message if no additional charges
          if (bill.discounts.isEmpty && bill.taxes.isEmpty && bill.serviceCharges.isEmpty && bill.otherCharges.isEmpty) ...[
            _buildSummaryRow('Additional Charges:', 'None', isLight: true),
          ],
          const Divider(),
          // Show original grand total and effective grand total
          _buildSummaryRow('Original Grand Total:', BillProcessor.formatCurrency(bill.grandTotal, bill.currency)),
          _buildSummaryRow('Effective Grand Total:', BillProcessor.formatCurrency(effectiveTotals['grandTotal'], bill.currency), isTotal: true, isOrange: hasEdits),
          _buildSummaryRow('Calculated Items Total:', BillProcessor.formatCurrency(effectiveTotals['itemsTotal'], bill.currency), isLight: true, isOrange: hasEdits),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isDiscount = false, bool isLight = false, bool isOrange = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isLight 
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isOrange
                  ? Colors.orange
                  : isDiscount 
                      ? Colors.green
                      : isTotal 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '4',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Split Results',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ..._splitCalculations.map((split) => _buildSplitCard(split)),
        
        // Combined total section - one-line row
        if (_splitCalculations.isNotEmpty) ...[
          const SizedBox(height: 24),
          CombinedTotalRow(
            amount: _summedTotalForSelected ?? 0.0,
            currency: _parsedBill!.currency,
            selectedCount: _selectedForSumming.length,
            totalCount: _people.length,
            onTap: () {
              // Open selection UI - could be a bottom sheet or dialog
              _showSelectionDialog();
            },
            isEnabled: _selectedForSumming.isNotEmpty,
          ),
        ],
      ],
    );
  }

  Widget _buildSplitCard(SplitCalculation split) {
    final person = _people.firstWhere((p) => p.id == split.personId);
    final isSelected = _selectedForSumming.contains(split.personId);
    final isExpanded = _expandedSplitCards.contains(split.personId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Main card content - no ripple effect
          GestureDetector(
            onTap: () => _handleToggleSumSelection(split.personId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PersonColors.getColorTheme(person.color)['unselected'],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        person.name[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: PersonColors.getColorTheme(person.color)['text'],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and price on same line
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                person.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              BillProcessor.formatCurrency(split.totalOwed, _parsedBill!.currency),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          
          // View Summary button - centered at bottom with tight padding
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedSplitCards.remove(split.personId);
                    } else {
                      _expandedSplitCards.add(split.personId);
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isExpanded ? 'Hide Summary' : 'View Summary',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          
          // Expandable summary section
          if (isExpanded) _buildSplitSummary(split),
        ],
      ),
    );
  }

  List<String> _getPeopleSharingItem(String itemDescription) {
    print('🔍 _getPeopleSharingItem DEBUG:');
    print('  Input description: "$itemDescription"');
    
    // Since we now have SharedItemContribution objects, we need to find people
    // who have this specific shared contribution in their breakdown
    final sharingPeople = <String>[];
    
    // Get all current split calculations using effective items
    final effectiveItems = _getEffectiveItems();
    final effectiveTotals = _calculateEffectiveBillTotals();
    final effectiveBill = ParsedBill(
      items: effectiveItems,
      currency: _parsedBill!.currency,
      subtotal: _parsedBill!.subtotal,
      discounts: _parsedBill!.discounts,
      taxes: _parsedBill!.taxes,
      serviceCharges: _parsedBill!.serviceCharges,
      otherCharges: _parsedBill!.otherCharges,
      grandTotal: effectiveTotals['grandTotal'],
    );
    
    // Combine cost assignments and unit assignments for split calculations
    final combinedAssignments = Map<String, dynamic>.from(_itemAssignments);
    
    // Add unit assignments to the combined assignments
    for (final itemId in _unitAssignments.keys) {
      if (_itemUnitModes[itemId] == true) {
        combinedAssignments[itemId] = _unitAssignments[itemId]!;
      }
    }
    
    final splits = BillProcessor.calculateSplits(effectiveBill, _people, combinedAssignments);
    
    for (final split in splits) {
      // Check if this person has a shared contribution with the same description
      final hasSharedContribution = split.breakdown.sharedItemContributions.any(
        (contribution) => contribution.description == itemDescription
      );
      
      if (hasSharedContribution) {
        sharingPeople.add(split.personName);
      }
    }
    
    print('  Found sharing people: $sharingPeople');
    return sharingPeople;
  }


  Widget _buildSplitSummary(SplitCalculation split) {
    final breakdown = split.breakdown;
    final currency = _parsedBill!.currency;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assigned Items Section
          if (breakdown.items.isNotEmpty) ...[
            Text(
              'Assigned Items',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...breakdown.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      BillProcessor.formatCurrency(item.totalPrice, currency),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          
          // When no items are assigned, show automatic assignment explanation
          if (breakdown.items.isEmpty) ...[
            Text(
              'Automatic Assignment',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No items manually assigned',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This person\'s share includes an equal portion of all bill items, taxes, service charges, and other fees. The amount is automatically calculated when no specific items are assigned.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Fees & Charges Section
          if (breakdown.taxShare > 0 || breakdown.serviceChargeShare > 0 || breakdown.otherChargesShare > 0 || breakdown.discountShare > 0) ...[
            Text(
              'Fees & Charges',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (breakdown.taxShare > 0)
              _buildFeeRow('Tax', breakdown.taxShare, currency),
            if (breakdown.serviceChargeShare > 0)
              _buildFeeRow('Service Fee', breakdown.serviceChargeShare, currency),
            if (breakdown.otherChargesShare > 0)
              _buildFeeRow('Other Charges', breakdown.otherChargesShare, currency),
            if (breakdown.discountShare > 0)
              _buildFeeRow('Discount', -breakdown.discountShare, currency, isDiscount: true),
            const SizedBox(height: 16),
          ],
          
          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _shareSplitDetails(split),
              icon: const Icon(Icons.share),
              label: const Text('Share Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFeeRow(String label, double amount, String currency, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}${BillProcessor.formatCurrency(amount.abs(), currency)}',
            style: TextStyle(
              fontSize: 12,
              color: isDiscount 
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _shareSplitDetails(SplitCalculation split) {
    final breakdown = split.breakdown;
    final currency = _parsedBill!.currency;
    
    // Build the share text
    final shareText = _buildShareText(split, breakdown, currency);
    
    // Share the text
    Share.share(
      shareText,
      subject: 'Bill Split Details - ${split.personName}',
    );
  }

  String _buildShareText(SplitCalculation split, SplitBreakdown breakdown, String currency) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('💰 Bill Split Details for ${split.personName}');
    buffer.writeln('=' * 40);
    buffer.writeln();
    
    // Total amount
    buffer.writeln('💵 Total Amount: ${BillProcessor.formatCurrency(split.totalOwed, currency)}');
    buffer.writeln();
    
    // Assigned Items
    if (breakdown.items.isNotEmpty) {
      buffer.writeln('📋 Assigned Items:');
      for (final item in breakdown.items) {
        buffer.writeln('• ${item.description} (${item.quantity}x) - ${BillProcessor.formatCurrency(item.totalPrice, currency)}');
      }
      buffer.writeln();
    }
    
    // Shared Items
    if (breakdown.sharedItemContributions.isNotEmpty) {
      buffer.writeln('🤝 Shared Items:');
      for (final contribution in breakdown.sharedItemContributions) {
        buffer.writeln('• ${contribution.description} - ${BillProcessor.formatCurrency(contribution.amount, currency)}');
      }
      buffer.writeln();
    }
    
    // Fees & Charges
    if (breakdown.taxShare > 0 || breakdown.serviceChargeShare > 0 || breakdown.otherChargesShare > 0 || breakdown.discountShare > 0) {
      buffer.writeln('💸 Fees & Charges:');
      if (breakdown.taxShare > 0) {
        buffer.writeln('• Tax: ${BillProcessor.formatCurrency(breakdown.taxShare, currency)}');
      }
      if (breakdown.serviceChargeShare > 0) {
        buffer.writeln('• Service Fee: ${BillProcessor.formatCurrency(breakdown.serviceChargeShare, currency)}');
      }
      if (breakdown.otherChargesShare > 0) {
        buffer.writeln('• Other Charges: ${BillProcessor.formatCurrency(breakdown.otherChargesShare, currency)}');
      }
      if (breakdown.discountShare > 0) {
        buffer.writeln('• Discount: -${BillProcessor.formatCurrency(breakdown.discountShare, currency)}');
      }
      buffer.writeln();
    }
    
    // Breakdown summary
    buffer.writeln('📊 Breakdown:');
    buffer.writeln('• Items Value: ${BillProcessor.formatCurrency(split.itemsValue, currency)}');
    buffer.writeln('• Shared Costs: ${BillProcessor.formatCurrency(split.sharedCostsAndDiscounts, currency)}');
    buffer.writeln('• Total: ${BillProcessor.formatCurrency(split.totalOwed, currency)}');
    buffer.writeln();
    
    // Footer
    buffer.writeln('Generated by Splitr 📱');
    
    return buffer.toString();
  }

  Widget _buildResetButton() {
    return Center(
      child: FilledButton(
        onPressed: _handleReset,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        child: const Text('Reset'),
      ),
    );
  }
}
class _UnitSelectorModal extends StatefulWidget {
  final BillItem item;
  final Person person;
  final int initialUnits;
  final int maxUnits;
  final int totalAssigned;
  final Function(int) onAssign;

  const _UnitSelectorModal({
    required this.item,
    required this.person,
    required this.initialUnits,
    required this.maxUnits,
    required this.totalAssigned,
    required this.onAssign,
  });

  @override
  State<_UnitSelectorModal> createState() => _UnitSelectorModalState();
}

class _UnitSelectorModalState extends State<_UnitSelectorModal> {
  late int localUnits;
  Timer? _holdTimer;
  int _holdDuration = 0;
  bool _isAccelerating = false;

  @override
  void initState() {
    super.initState();
    localUnits = widget.initialUnits;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void updateUnits(int delta) {
    setState(() {
      localUnits = (localUnits + delta).clamp(0, widget.maxUnits);
    });
    // Only provide haptic feedback for single taps, not during hold
    if (_holdTimer == null) {
      HapticFeedback.lightImpact();
    }
  }

  void _startHold(int delta) {
    _holdTimer?.cancel();
    _holdDuration = 0;
    _isAccelerating = false;
    
    // Initial update
    updateUnits(delta);
    
    // Start with slow updates, then accelerate
    _scheduleNextHoldUpdate(delta);
  }

  void _scheduleNextHoldUpdate(int delta) {
    if (_holdTimer?.isActive == true) return;
    
    // Calculate delay and units based on hold duration - 3 speeds only
    Duration delay;
    int unitsToUpdate;
    
    if (_holdDuration < 3) {
      // Slow phase: 500ms delay, 1 unit (500ms-1.5s)
      delay = const Duration(milliseconds: 500);
      unitsToUpdate = 1;
    } else if (_holdDuration < 7) {
      // Medium phase: 150ms delay, 2 units (1.5s-3.5s)
      delay = const Duration(milliseconds: 150);
      unitsToUpdate = 2;
    } else {
      // Fast phase: 50ms delay, 5 units (3.5s+)
      delay = const Duration(milliseconds: 50);
      unitsToUpdate = 5;
    }
    
    _holdTimer = Timer(delay, () {
      _holdDuration++;
      
      // Update acceleration state
      if (_holdDuration >= 5 && !_isAccelerating) {
        setState(() {
          _isAccelerating = true;
        });
      }
      
      // Update units
      for (int i = 0; i < unitsToUpdate; i++) {
        updateUnits(delta);
      }
      
      // Provide haptic feedback during acceleration
      if (_isAccelerating && _holdDuration % 5 == 0) {
        HapticFeedback.lightImpact();
      }
      
      // Schedule next update
      _scheduleNextHoldUpdate(delta);
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdDuration = 0;
    setState(() {
      _isAccelerating = false;
    });
  }

  void handleAssign() {
    widget.onAssign(localUnits);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final remainingUnits = widget.item.quantity - widget.totalAssigned + widget.initialUnits - localUnits;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // Spacer to center the title
              Text(
                'Assign Units',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Unassigned: $remainingUnits / ${widget.item.quantity}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          if (remainingUnits > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Remaining to assign: $remainingUnits units',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'All units assigned!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 24),
          
          // Person chip (matching main UI styling)
          Center(
            child: AppChip(
              label: widget.person.name,
              isSelected: true, // Always selected in modal to show it's the active person
              variant: AppChipVariant.tonal,
              backgroundColor: PersonColors.getColorTheme(widget.person.color)['unselected'],
              selectedBackgroundColor: PersonColors.getColorTheme(widget.person.color)['selected'],
              ringColor: PersonColors.getColorTheme(widget.person.color)['ring'],
              onTap: () {}, // No action needed in modal
              onSelectionChanged: () {}, // No action needed in modal
            ),
          ),
          const SizedBox(height: 32),
          
          // Unit counter with enhanced design
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _HoldableIconButton(
                  onPressed: localUnits > 0 ? () => updateUnits(-1) : null,
                  onHoldStart: localUnits > 0 ? () => _startHold(-1) : null,
                  onHoldEnd: _stopHold,
                  icon: const Icon(Icons.remove, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: localUnits > 0 
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: localUnits > 0 
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    localUnits.toString(),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(child: _HoldableIconButton(
                  onPressed: localUnits < widget.maxUnits ? () => updateUnits(1) : null,
                  onHoldStart: localUnits < widget.maxUnits ? () => _startHold(1) : null,
                  onHoldEnd: _stopHold,
                  icon: const Icon(Icons.add, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: localUnits < widget.maxUnits 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: localUnits < widget.maxUnits 
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Assign button (full width)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: handleAssign,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Assign'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldableIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final Widget icon;
  final ButtonStyle? style;

  const _HoldableIconButton({
    required this.onPressed,
    this.onHoldStart,
    this.onHoldEnd,
    required this.icon,
    this.style,
  });

  @override
  State<_HoldableIconButton> createState() => _HoldableIconButtonState();
}

class _HoldableIconButtonState extends State<_HoldableIconButton> {
  bool _isPressed = false;
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() {
        _isPressed = true;
      });
      
      // Start hold timer after 500ms
      _holdTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isPressed && widget.onHoldStart != null) {
          widget.onHoldStart!();
        }
      });
    }
  }

  void _onTapUp(TapUpDetails details) {
    _onTapEnd();
  }

  void _onTapCancel() {
    _onTapEnd();
  }

  void _onTapEnd() {
    _holdTimer?.cancel();
    
    if (_isPressed) {
      setState(() {
        _isPressed = false;
      });
      
      if (widget.onHoldEnd != null) {
        widget.onHoldEnd!();
      }
      
      // If we didn't hold long enough, trigger the tap
      if (widget.onPressed != null) {
        widget.onPressed!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scaleByDouble(_isPressed ? 0.95 : 1.0, _isPressed ? 0.95 : 1.0, _isPressed ? 0.95 : 1.0, 1.0),
        child: IconButton(
          onPressed: null, // Handled by GestureDetector
          icon: widget.icon,
          style: widget.style,
        ),
      ),
    );
  }
}

class _EditItemModal extends StatefulWidget {
  final BillItem item;
  final BillItem originalItem; // Original item before any edits
  final String currency;
  final Function(BillItem) onSave;
  final Function(BillItem)? onPreview; // New callback for real-time updates

  const _EditItemModal({
    required this.item,
    required this.originalItem,
    required this.currency,
    required this.onSave,
    this.onPreview,
  });

  @override
  State<_EditItemModal> createState() => _EditItemModalState();
}

class _EditItemModalState extends State<_EditItemModal> {
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.originalItem.description);
    _quantityController = TextEditingController(text: widget.originalItem.quantity.toString());
    _unitPriceController = TextEditingController(
      text: (widget.originalItem.unitPrice ?? (widget.originalItem.totalPrice / widget.originalItem.quantity)).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }


  void _previewChanges() {
    if (widget.onPreview != null) {
      final description = _descriptionController.text.trim();
      final quantity = int.tryParse(_quantityController.text) ?? 0;
      final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
      final totalPrice = quantity * unitPrice; // Calculate total automatically

      // Be more lenient - allow updates even with partial data
      if (description.isNotEmpty && quantity > 0) {
        final previewItem = BillItem(
          id: widget.item.id,
          description: description,
          quantity: quantity,
          unitPrice: unitPrice,
          totalPrice: totalPrice,
          assignedQuantity: widget.item.assignedQuantity,
        );
        widget.onPreview!(previewItem);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                const SizedBox(width: 48), // Spacer to center the title
                Text(
                  'Edit Item',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form fields
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Description
                  Text(
                    'Item Description',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                                      TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Enter item description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _previewChanges(),
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                  const SizedBox(height: 20),

                  // Quantity
                  Text(
                    'Quantity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                                      TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        hintText: 'Enter quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        // Use a small delay to ensure the text controllers are updated
                        Future.delayed(const Duration(milliseconds: 10), () {
                          _previewChanges();
                        });
                      },
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                  const SizedBox(height: 8),
                  // Original Quantity
                  Text(
                    'Original Quantity: ${widget.originalItem.quantity}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Unit Price
                  Text(
                    'Unit Price (${widget.currency})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                                      TextField(
                      controller: _unitPriceController,
                      decoration: const InputDecoration(
                        hintText: 'Enter unit price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        // Use a small delay to ensure the text controllers are updated
                        Future.delayed(const Duration(milliseconds: 10), () {
                          _previewChanges();
                        });
                      },
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        _saveChanges();
                      },
                    ),
                  const SizedBox(height: 8),
                  // Original Unit Price
                  Text(
                    'Original Unit Price: ${BillProcessor.formatCurrency(widget.originalItem.unitPrice ?? (widget.originalItem.totalPrice / widget.originalItem.quantity), widget.currency)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),

            // Save button (full width)
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save Changes'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    final description = _descriptionController.text.trim();
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    final totalPrice = quantity * unitPrice; // Calculate total automatically

    if (description.isEmpty || quantity <= 0 || unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields with valid values')),
      );
      return;
    }

    final updatedItem = BillItem(
      id: widget.item.id,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      assignedQuantity: widget.item.assignedQuantity,
    );

    widget.onSave(updatedItem);
    Navigator.pop(context);
  }
}

