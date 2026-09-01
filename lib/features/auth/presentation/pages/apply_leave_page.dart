import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/features/auth/data/datasources/leave_api_datasource.dart';

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'package:suitapps/features/auth/data/datasources/leave_api_datasource.dart';

// class ApplyLeavePage extends StatefulWidget {
//   const ApplyLeavePage({super.key});

//   @override
//   State<ApplyLeavePage> createState() => _ApplyLeavePageState();
// }

// class _ApplyLeavePageState extends State<ApplyLeavePage> {
//   // â”€â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   List<dynamic> leaveTypes = [];
//   Map<String, dynamic>? selectedLeaveType;

//   bool isHalfDay = false;

//   // Full Day
//   DateTime? fromDate;
//   DateTime? toDate;

//   // Half Day
//   DateTime? halfDayDate;
//   TimeOfDay? halfDayFromTime;
//   TimeOfDay? halfDayToTime;

//   int? employeeId;
//   int? companyId;

//   bool isLoading = false;
//   bool isSubmitting = false;

//   final TextEditingController reasonController = TextEditingController();

//   // â”€â”€â”€ Design Tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   static const _primary = Color(0xFF1A73E8);
//   static const _primaryLight = Color(0xFFE8F0FE);
//   static const _surface = Color(0xFFFFFFFF);
//   static const _background = Color(0xFFF6F8FB);
//   static const _border = Color(0xFFDDE3ED);
//   static const _textPrimary = Color(0xFF1C2B4A);
//   static const _textSecondary = Color(0xFF6B7A99);
//   static const _error = Color(0xFFD93025);
//   static const _success = Color(0xFF1E8E3E);

//   // â”€â”€â”€ Init â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   @override
//   void initState() {
//     super.initState();
//     _initData();
//   }

//   @override
//   void dispose() {
//     reasonController.dispose();
//     super.dispose();
//   }

//   Future<void> _initData() async {
//     setState(() => isLoading = true);
//     final prefs = await SharedPreferences.getInstance();
//     employeeId = int.tryParse(prefs.get('UserId').toString());
//     companyId = int.tryParse(prefs.get('CompanyID').toString()) ?? 8;
//     leaveTypes = await LeaveService.getLeaveTypes(companyId!);
//     setState(() => isLoading = false);
//   }

//   // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
//   String _fmtTime(TimeOfDay t) => t.format(context);

//   bool get _halfDayAllowed =>
//       selectedLeaveType?['IsHalfDayAllowed'] == 1 ||
//       selectedLeaveType?['IsHalfDayAllowed'] == true;

//   // â”€â”€â”€ Pickers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Future<void> _pickFromDate() async {
//     final now = DateTime.now();
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: fromDate ?? now,
//       firstDate: now, // only upcoming dates
//       lastDate: DateTime(now.year + 2),
//       builder: _datepickerTheme,
//     );
//     if (picked == null) return;
//     setState(() {
//       fromDate = picked;
//       // Reset toDate if it's before new fromDate
//       if (toDate != null && toDate!.isBefore(picked)) toDate = null;
//     });
//   }

//   Future<void> _pickToDate() async {
//     final now = DateTime.now();
//     final initial = fromDate ?? now;
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: toDate ?? initial,
//       firstDate: initial, // can't pick before fromDate
//       lastDate: DateTime(now.year + 2),
//       builder: _datepickerTheme,
//     );
//     if (picked != null) setState(() => toDate = picked);
//   }

//   Future<void> _pickHalfDayDate() async {
//     final now = DateTime.now();
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: halfDayDate ?? now,
//       firstDate: now,
//       lastDate: DateTime(now.year + 2),
//       builder: _datepickerTheme,
//     );
//     if (picked != null) setState(() => halfDayDate = picked);
//   }

//   Future<void> _pickFromTime() async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: halfDayFromTime ?? const TimeOfDay(hour: 9, minute: 0),
//       builder: _timepickerTheme,
//     );
//     if (picked == null) return;
//     // Validate: fromTime must be before toTime if toTime is set
//     if (halfDayToTime != null) {
//       final fromMinutes = picked.hour * 60 + picked.minute;
//       final toMinutes = halfDayToTime!.hour * 60 + halfDayToTime!.minute;
//       if (fromMinutes >= toMinutes) {
//         _showError('Start time must be before end time.');
//         return;
//       }
//     }
//       print("FROM PICKED: ${picked.hour}:${picked.minute}");
//     setState(() => halfDayFromTime = picked);
//   }

//   Future<void> _pickToTime() async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: halfDayToTime ?? const TimeOfDay(hour: 13, minute: 0),
//       builder: _timepickerTheme,
//     );
//     if (picked == null) return;
//     // Validate: toTime must be after fromTime if fromTime is set
//     if (halfDayFromTime != null) {
//       final fromMinutes = halfDayFromTime!.hour * 60 + halfDayFromTime!.minute;
//       final toMinutes = picked.hour * 60 + picked.minute;
//       if (toMinutes <= fromMinutes) {
//         _showError('End time must be after start time.');
//         return;
//       }
//     }
//     print("TO PICKED: ${picked.hour}:${picked.minute}");
//     setState(() => halfDayToTime = picked);
//   }

//   Widget _datepickerTheme(BuildContext ctx, Widget? child) {
//     return Theme(
//       data: Theme.of(ctx).copyWith(
//         colorScheme: const ColorScheme.light(
//           primary: _primary,
//           onPrimary: Colors.white,
//           surface: _surface,
//           onSurface: _textPrimary,
//         ),
//       ),
//       child: child!,
//     );
//   }

//   Widget _timepickerTheme(BuildContext ctx, Widget? child) {
//     return Theme(
//       data: Theme.of(ctx).copyWith(
//         colorScheme: const ColorScheme.light(
//           primary: _primary,
//           onPrimary: Colors.white,
//           surface: _surface,
//           onSurface: _textPrimary,
//         ),
//       ),
//       child: child!,
//     );
//   }

//   // â”€â”€â”€ Validation & Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   void _showError(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: _error,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   void _showSuccess(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: _success,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   Future<void> _submit() async {
//     // Validation
//     if (selectedLeaveType == null) {
//       _showError('Please select a leave type.');
//       return;
//     }
//     if (reasonController.text.trim().isEmpty) {
//       _showError('Please enter a reason.');
//       return;
//     }

//     DateTime from, to;

//     if (!isHalfDay) {
//       if (fromDate == null || toDate == null) {
//         _showError('Please select from and to dates.');
//         return;
//       }
//       from = DateTime(fromDate!.year, fromDate!.month, fromDate!.day, 0, 0);
//       to = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59);
//     } else {
//       if (halfDayDate == null) {
//         _showError('Please select a date.');
//         return;
//       }
//       if (halfDayFromTime == null || halfDayToTime == null) {
//         _showError('Please select start and end times.');
//         return;
//       }
//       from = DateTime(
//         halfDayDate!.year,
//         halfDayDate!.month,
//         halfDayDate!.day,
//         halfDayFromTime!.hour,
//         halfDayFromTime!.minute,
//       );

//       to = DateTime(
//         halfDayDate!.year,
//         halfDayDate!.month,
//         halfDayDate!.day,
//         halfDayToTime!.hour,
//         halfDayToTime!.minute,
//       );
//     }

//     setState(() => isSubmitting = true);

//     final body = {
//       "LeaveID": null,
//       "CompanyID": companyId,
//       "EmployeeID": employeeId,
//       "LeaveTypeID": selectedLeaveType!["LeaveTypeID"],
//       "FromDate": DateFormat("yyyy-MM-dd HH:mm:ss").format(from),
//       "ToDate": DateFormat("yyyy-MM-dd HH:mm:ss").format(to),
//       "DurationType": isHalfDay ? "Half Day" : "Full Day",
//       "HalfDaySession": isHalfDay ? "Custom" : null,
//       "Reason": reasonController.text.trim(),
//       "Status": "pending",
//       "IsDeleted": 0,
//     };
//     print("FROM => $from");
//     print("TO   => $to");
//     print("BODY => $body");

//     final success = await LeaveService.applyLeave(body);

//     setState(() => isSubmitting = false);

//     if (success) {
//       _showSuccess('Leave applied successfully!');
//       if (mounted) Navigator.pop(context);
//     } else {
//       _showError('Failed to apply leave. Please try again.');
//     }
//   }

//   // â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _background,
//       appBar: AppBar(
//         backgroundColor: _surface,
//         foregroundColor: _textPrimary,
//         elevation: 0,
//         surfaceTintColor: Colors.transparent,
//         title: const Text(
//           'Apply Leave',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             color: _textPrimary,
//           ),
//         ),
//         centerTitle: false,
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(1),
//           child: Container(height: 1, color: _border),
//         ),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator(color: _primary))
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildLeaveTypeCard(),
//                   const SizedBox(height: 12),
//                   _buildDurationToggle(),
//                   const SizedBox(height: 12),
//                   isHalfDay ? _buildHalfDayCard() : _buildFullDayCard(),
//                   const SizedBox(height: 12),
//                   _buildReasonCard(),
//                   const SizedBox(height: 24),
//                   _buildSubmitButton(),
//                   const SizedBox(height: 24),
//                 ],
//               ),
//             ),
//     );
//   }

//   // â”€â”€â”€ Leave Type Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Widget _buildLeaveTypeCard() {
//     return _card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _label('Leave Type'),
//           const SizedBox(height: 8),
//           Container(
//             decoration: BoxDecoration(
//               border: Border.all(color: _border),
//               borderRadius: BorderRadius.circular(10),
//               color: _surface,
//             ),
//             padding: const EdgeInsets.symmetric(horizontal: 14),
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<int>(
//                 isExpanded: true,
//                 hint: const Text(
//                   'Select leave type',
//                   style: TextStyle(color: _textSecondary, fontSize: 14),
//                 ),
//                 value: selectedLeaveType?['LeaveTypeID'] as int?,
//                 icon: const Icon(
//                   Icons.keyboard_arrow_down_rounded,
//                   color: _textSecondary,
//                 ),
//                 style: const TextStyle(color: _textPrimary, fontSize: 14),
//                 items: leaveTypes.map<DropdownMenuItem<int>>((e) {
//                   return DropdownMenuItem<int>(
//                     value: e['LeaveTypeID'] as int,
//                     child: Text(e['LeaveTypeName']),
//                   );
//                 }).toList(),
//                 onChanged: (val) {
//                   setState(() {
//                     selectedLeaveType = leaveTypes.firstWhere(
//                       (e) => e['LeaveTypeID'] == val,
//                     );
//                     // If half day was on but new type doesn't support it, reset
//                     if (isHalfDay && !_halfDayAllowed) isHalfDay = false;
//                   });
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // â”€â”€â”€ Duration Toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Widget _buildDurationToggle() {
//     final canToggle = _halfDayAllowed;

//     return _card(
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Half Day',
//                   style: TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w500,
//                     color: _textPrimary,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   canToggle
//                       ? 'Select a custom time window'
//                       : 'Not available for this leave type',
//                   style: const TextStyle(fontSize: 12, color: _textSecondary),
//                 ),
//               ],
//             ),
//           ),
//           Switch(
//             value: isHalfDay,
//             onChanged: canToggle ? (v) => setState(() => isHalfDay = v) : null,
//             activeColor: _primary,
//           ),
//         ],
//       ),
//     );
//   }

//   // â”€â”€â”€ Full Day Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Widget _buildFullDayCard() {
//     return _card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _label('Duration'),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(child: _dateTile('From', fromDate, _pickFromDate)),
//               const SizedBox(width: 12),
//               Expanded(child: _dateTile('To', toDate, _pickToDate)),
//             ],
//           ),
//           if (fromDate != null && toDate != null) ...[
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: _primaryLight,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(
//                     Icons.info_outline_rounded,
//                     size: 16,
//                     color: _primary,
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     '${toDate!.difference(fromDate!).inDays + 1} day(s) selected',
//                     style: const TextStyle(
//                       fontSize: 13,
//                       color: _primary,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   // â”€â”€â”€ Half Day Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Widget _buildHalfDayCard() {
//     return _card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _label('Date & Time'),
//           const SizedBox(height: 12),

//           // Date picker
//           _dateTile('Date', halfDayDate, _pickHalfDayDate, fullWidth: true),

//           const SizedBox(height: 12),

//           // Time pickers
//           Row(
//             children: [
//               Expanded(
//                 child: _timeTile('Start Time', halfDayFromTime, _pickFromTime),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: _timeTile('End Time', halfDayToTime, _pickToTime),
//               ),
//             ],
//           ),

//           if (halfDayFromTime != null && halfDayToTime != null) ...[
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: _primaryLight,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.timer_outlined, size: 16, color: _primary),
//                   const SizedBox(width: 8),
//                   Text(
//                     '${_durationText(halfDayFromTime!, halfDayToTime!)} duration',
//                     style: const TextStyle(
//                       fontSize: 13,
//                       color: _primary,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   String _durationText(TimeOfDay from, TimeOfDay to) {
//     final totalMins =
//         (to.hour * 60 + to.minute) - (from.hour * 60 + from.minute);
//     final h = totalMins ~/ 60;
//     final m = totalMins % 60;
//     if (h == 0) return '${m}m';
//     if (m == 0) return '${h}h';
//     return '${h}h ${m}m';
//   }

//   // â”€â”€â”€ Reason Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Widget _buildReasonCard() {
//     return _card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _label('Reason'),
//           const SizedBox(height: 8),
//           TextField(
//             controller: reasonController,
//             maxLines: 3,
//             style: const TextStyle(fontSize: 14, color: _textPrimary),
//             decoration: InputDecoration(
//               hintText: 'Describe your reason for leave...',
//               hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
//               filled: true,
//               fillColor: _background,
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 12,
//                 vertical: 12,
//               ),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide: const BorderSide(color: _border),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide: const BorderSide(color: _border),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide: const BorderSide(color: _primary, width: 1.5),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // â”€â”€â”€ Submit Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Widget _buildSubmitButton() {
//     return SizedBox(
//       width: double.infinity,
//       height: 50,
//       child: ElevatedButton(
//         onPressed: isSubmitting ? null : _submit,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _primary,
//           foregroundColor: Colors.white,
//           disabledBackgroundColor: _primary.withOpacity(0.6),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           elevation: 0,
//         ),
//         child: isSubmitting
//             ? const SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   color: Colors.white,
//                 ),
//               )
//             : const Text(
//                 'Submit Leave Request',
//                 style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
//               ),
//       ),
//     );
//   }

//   // â”€â”€â”€ Reusable Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   Widget _card({required Widget child}) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _surface,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _border),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x08000000),
//             blurRadius: 6,
//             offset: Offset(0, 2),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }

//   Widget _label(String text) {
//     return Text(
//       text,
//       style: const TextStyle(
//         fontSize: 13,
//         fontWeight: FontWeight.w600,
//         color: _textSecondary,
//         letterSpacing: 0.3,
//       ),
//     );
//   }

//   Widget _dateTile(
//     String label,
//     DateTime? value,
//     VoidCallback onTap, {
//     bool fullWidth = false,
//   }) {
//     final tile = GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//         decoration: BoxDecoration(
//           border: Border.all(color: value != null ? _primary : _border),
//           borderRadius: BorderRadius.circular(10),
//           color: value != null ? _primaryLight : _background,
//         ),
//         child: Row(
//           children: [
//             Icon(
//               Icons.calendar_today_rounded,
//               size: 16,
//               color: value != null ? _primary : _textSecondary,
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 value != null ? _fmtDate(value) : label,
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
//                   color: value != null ? _primary : _textSecondary,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );

//     return fullWidth ? SizedBox(width: double.infinity, child: tile) : tile;
//   }

//   Widget _timeTile(String label, TimeOfDay? value, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//         decoration: BoxDecoration(
//           border: Border.all(color: value != null ? _primary : _border),
//           borderRadius: BorderRadius.circular(10),
//           color: value != null ? _primaryLight : _background,
//         ),
//         child: Row(
//           children: [
//             Icon(
//               Icons.access_time_rounded,
//               size: 16,
//               color: value != null ? _primary : _textSecondary,
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 value != null ? _fmtTime(value) : label,
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: value != null ? FontWeight.w500 : FontWeight.w400,
//                   color: value != null ? _primary : _textSecondary,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  // â”€â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<dynamic> leaveTypes = [];
  Map<String, dynamic>? selectedLeaveType;

  bool isHalfDay = false;

  DateTime? fromDate;
  DateTime? toDate;

  DateTime? halfDayDate;
  TimeOfDay? halfDayFromTime;
  TimeOfDay? halfDayToTime;

  int? employeeId;
  int? companyId;

  bool isLoading = false;
  bool isSubmitting = false;

  final TextEditingController reasonController = TextEditingController();

  // â”€â”€â”€ Design Tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _primary        = Color(0xFF1433C3);
  static const _primaryLight   = Color(0xFFEEF1FC);
  static const _secondary      = Color(0xFF6F7FDB);
  static const _surface        = Color(0xFFFFFFFF);
  static const _background     = Color(0xFFF5F7FB);
  static const _border         = Color(0xFFE5E7EB);
  static const _textPrimary    = Color(0xFF111827);
  static const _textSecondary  = Color(0xFF6B7280);
  static const _error          = Color(0xFFDC2626);
  static const _success        = Color(0xFF16A34A);

  // â”€â”€â”€ Init â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    employeeId = int.tryParse(prefs.get('UserId').toString());
    companyId  = int.tryParse(prefs.get('CompanyID').toString()) ?? 8;
    leaveTypes = await LeaveService.getLeaveTypes(companyId!);
    setState(() => isLoading = false);
  }

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  String _fmtTime(TimeOfDay t) => t.format(context);

  bool get _halfDayAllowed =>
      selectedLeaveType?['IsHalfDayAllowed'] == 1 ||
      selectedLeaveType?['IsHalfDayAllowed'] == true;

  // â”€â”€â”€ Pickers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: _datePickerTheme,
    );
    if (picked == null) return;
    setState(() {
      fromDate = picked;
      if (toDate != null && toDate!.isBefore(picked)) toDate = null;
    });
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final initial = fromDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? initial,
      firstDate: initial,
      lastDate: DateTime(now.year + 2),
      builder: _datePickerTheme,
    );
    if (picked != null) setState(() => toDate = picked);
  }

  Future<void> _pickHalfDayDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: halfDayDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: _datePickerTheme,
    );
    if (picked != null) setState(() => halfDayDate = picked);
  }

  Future<void> _pickFromTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: halfDayFromTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: _timePickerTheme,
    );
    if (picked == null) return;
    if (halfDayToTime != null) {
      final fromMins = picked.hour * 60 + picked.minute;
      final toMins   = halfDayToTime!.hour * 60 + halfDayToTime!.minute;
      if (fromMins >= toMins) {
        _showError('Start time must be before end time.');
        return;
      }
    }
    setState(() => halfDayFromTime = picked);
  }

  Future<void> _pickToTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: halfDayToTime ?? const TimeOfDay(hour: 13, minute: 0),
      builder: _timePickerTheme,
    );
    if (picked == null) return;
    if (halfDayFromTime != null) {
      final fromMins = halfDayFromTime!.hour * 60 + halfDayFromTime!.minute;
      final toMins   = picked.hour * 60 + picked.minute;
      if (toMins <= fromMins) {
        _showError('End time must be after start time.');
        return;
      }
    }
    setState(() => halfDayToTime = picked);
  }

  Widget _datePickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: _surface,
            onSurface: _textPrimary,
          ),
        ),
        child: child!,
      );

  Widget _timePickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: _surface,
            onSurface: _textPrimary,
          ),
        ),
        child: child!,
      );

  // â”€â”€â”€ Feedback â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
      backgroundColor: _error,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
      backgroundColor: _success,
   behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // margin: const EdgeInsets.all(16),
    ));
  }

  // â”€â”€â”€ Validation & Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _submit() async {
    if (selectedLeaveType == null) { _showError('Please select a leave type.'); return; }
    if (reasonController.text.trim().isEmpty) { _showError('Please enter a reason.'); return; }

    DateTime from, to;

    if (!isHalfDay) {
      if (fromDate == null || toDate == null) {
        _showError('Please select from and to dates.');
        return;
      }
      from = DateTime(fromDate!.year, fromDate!.month, fromDate!.day, 0, 0);
      to   = DateTime(toDate!.year,   toDate!.month,   toDate!.day,   23, 59);
    } else {
      if (halfDayDate == null) { _showError('Please select a date.'); return; }
      if (halfDayFromTime == null || halfDayToTime == null) {
        _showError('Please select start and end times.');
        return;
      }
      from = DateTime(halfDayDate!.year, halfDayDate!.month, halfDayDate!.day,
          halfDayFromTime!.hour, halfDayFromTime!.minute);
      to   = DateTime(halfDayDate!.year, halfDayDate!.month, halfDayDate!.day,
          halfDayToTime!.hour,  halfDayToTime!.minute);
    }

    setState(() => isSubmitting = true);

    final body = {
      "LeaveID":        null,
      "CompanyID":      companyId,
      "EmployeeID":     employeeId,
      "LeaveTypeID":    selectedLeaveType!["LeaveTypeID"],
      "FromDate":       DateFormat("yyyy-MM-dd HH:mm:ss").format(from),
      "ToDate":         DateFormat("yyyy-MM-dd HH:mm:ss").format(to),
      "DurationType":   isHalfDay ? "Half Day" : "Full Day",
      "HalfDaySession": isHalfDay ? "Custom" : null,
      "Reason":         reasonController.text.trim(),
      "Status":         "pending",
      "IsDeleted":      0,
    };

    final success = await LeaveService.applyLeave(body);
    setState(() => isSubmitting = false);

    if (success) {
      _showSuccess('Leave applied successfully!');
      if (mounted) Navigator.pop(context);
    } else {
      _showError('Failed to apply leave. Please try again.');
    }
  }

  // â”€â”€â”€ Duration Text â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _durationText(TimeOfDay from, TimeOfDay to) {
    final totalMins = (to.hour * 60 + to.minute) - (from.hour * 60 + from.minute);
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  // â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLeaveTypeCard(),
                  const SizedBox(height: 8),
                  _buildDurationToggle(),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)),
                    child: isHalfDay
                        ? _buildHalfDayCard()
                        : _buildFullDayCard(),
                  ),
                  const SizedBox(height: 8),
                  _buildReasonCard(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  // â”€â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Apply Leave',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  // â”€â”€â”€ Leave Type Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildLeaveTypeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Leave Type'),
          const SizedBox(height: 8),
          _styledDropdown(),
        ],
      ),
    );
  }

  Widget _styledDropdown() {
    final bool hasValue = selectedLeaveType != null;
    return Container(
      decoration: BoxDecoration(
        color: hasValue ? _primaryLight : _background,
        border: Border.all(
          color: hasValue ? _primary : _border,
          width: hasValue ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          hint: Text(
            'Select leave type',
            style: GoogleFonts.inter(color: _textSecondary, fontSize: 14),
          ),
          value: selectedLeaveType?['LeaveTypeID'] as int?,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: hasValue ? _primary : _textSecondary,
          ),
          style: GoogleFonts.inter(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          dropdownColor: _surface,
          borderRadius: BorderRadius.circular(12),
          items: leaveTypes.map<DropdownMenuItem<int>>((e) {
            return DropdownMenuItem<int>(
              value: e['LeaveTypeID'] as int,
              child: Text(e['LeaveTypeName']),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedLeaveType = leaveTypes.firstWhere((e) => e['LeaveTypeID'] == val);
              if (isHalfDay && !_halfDayAllowed) isHalfDay = false;
            });
          },
        ),
      ),
    );
  }

  // â”€â”€â”€ Duration Toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDurationToggle() {
    final canToggle = _halfDayAllowed;
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHalfDay ? _primaryLight : _background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.timelapse_rounded,
              size: 20,
              color: isHalfDay ? _primary : _textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Half Day',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canToggle
                      ? 'Select a custom time window'
                      : 'Not available for this leave type',
                  style: GoogleFonts.inter(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Switch(
            value: isHalfDay,
            onChanged: canToggle ? (v) => setState(() => isHalfDay = v) : null,
            activeColor: _primary,
            activeTrackColor: _primaryLight,
            inactiveThumbColor: _textSecondary,
            inactiveTrackColor: _border,
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Full Day Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFullDayCard() {
    return _card(
      key: const ValueKey('fullDay'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Select Duration'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateTile('From Date', fromDate, _pickFromDate)),
              const SizedBox(width: 8),
              Expanded(child: _dateTile('To Date',   toDate,   _pickToDate)),
            ],
          ),
          if (fromDate != null && toDate != null) ...[
            const SizedBox(height: 12),
            _infoBanner(
              icon: Icons.event_available_rounded,
              text: '${toDate!.difference(fromDate!).inDays + 1} day(s) selected',
            ),
          ],
        ],
      ),
    );
  }

  // â”€â”€â”€ Half Day Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHalfDayCard() {
    return _card(
      key: const ValueKey('halfDay'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Date & Time'),
          const SizedBox(height: 12),
          _dateTile('Select Date', halfDayDate, _pickHalfDayDate, fullWidth: true),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _timeTile('Start Time', halfDayFromTime, _pickFromTime)),
              const SizedBox(width: 8),
              Expanded(child: _timeTile('End Time',   halfDayToTime,   _pickToTime)),
            ],
          ),
          if (halfDayFromTime != null && halfDayToTime != null) ...[
            const SizedBox(height: 12),
            _infoBanner(
              icon: Icons.timer_outlined,
              text: '${_durationText(halfDayFromTime!, halfDayToTime!)} duration selected',
            ),
          ],
        ],
      ),
    );
  }

  // â”€â”€â”€ Reason Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildReasonCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Reason for Leave'),
          const SizedBox(height: 8),
          TextField(
            controller: reasonController,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'Describe your reason for leave...',
              hintStyle: GoogleFonts.inter(color: _textSecondary, fontSize: 14),
              filled: true,
              fillColor: _background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Submit Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Submit Leave Request',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // â”€â”€â”€ Shared Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _card({required Widget child, Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // 0.05 opacity
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _infoBanner({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap, {bool fullWidth = false}) {
    final bool selected = value != null;
    final tile = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _primaryLight : _background,
          border: Border.all(
            color: selected ? _primary : _border,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: selected ? _primary : _textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: selected ? _primary.withOpacity(0.7) : _textSecondary,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtDate(value),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: tile) : tile;
  }

  Widget _timeTile(String label, TimeOfDay? value, VoidCallback onTap) {
    final bool selected = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _primaryLight : _background,
          border: Border.all(
            color: selected ? _primary : _border,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: selected ? _primary : _textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: selected ? _primary.withOpacity(0.7) : _textSecondary,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtTime(value),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
