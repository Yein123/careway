import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../icons.dart';
import '../theme.dart';
import 'cw_sheet.dart';
import 'cw_top_bar.dart';

const emergencyNumber = '999';
const coordinatorNumber = '+60 3-0000 0000';

Future<void> _call(BuildContext context, String number) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', '')));
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call $number')));
  }
}

/// Shield button that opens the Help and safety sheet.
class SafetyButton extends StatelessWidget {
  const SafetyButton({super.key});

  @override
  Widget build(BuildContext context) => SquareIconButton(
    svg: CwIcons.shield,
    label: 'Help and safety',
    color: CwColors.pink,
    onTap: () => showHelpSheet(context),
  );
}

/// Help and safety sheet (Home.dc.html).
Future<void> showHelpSheet(BuildContext context) => showCwSheet<void>(
  context,
  builder: (ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text('Help and safety', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          SheetCloseButton(label: 'Close help and safety', onTap: () => Navigator.pop(ctx)),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CwColors.white,
          border: Border.all(color: CwColors.pink, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Emergency at home?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFA02A4C))),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hospital Sungai Buloh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('Nearest ER · 24 hours · ~10 km', style: TextStyle(fontSize: 12, color: CwColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _PillCall(
                  label: 'Call ER',
                  background: CwColors.pink,
                  foreground: CwColors.white,
                  onTap: () => _call(ctx, emergencyNumber),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PillCall(
              label: 'Call for urgent escort',
              background: CwColors.pinkSoft,
              foreground: const Color(0xFFA02A4C),
              expand: true,
              onTap: () => _call(ctx, coordinatorNumber),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Material(
        color: CwColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _call(ctx, coordinatorNumber),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: CwIcon(CwIcons.phone, size: 16, strokeWidth: 2.4, color: CwColors.primary)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Call CareWay coordinator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      SizedBox(height: 1),
                      Text('[Support hours]', style: TextStyle(fontSize: 12, color: CwColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: () {
            Navigator.pop(ctx);
            GoRouter.of(context).go('/account?section=safety');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: CwColors.primaryDark,
            side: const BorderSide(color: CwColors.line, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontFamily: cwFont, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          child: const Text('Safety promise and questions'),
        ),
      ),
    ],
  ),
);

class _PillCall extends StatelessWidget {
  const _PillCall({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CwIcon(CwIcons.phone, size: 16, strokeWidth: 2.4, color: foreground),
              SizedBox(width: expand ? 8 : 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: foreground))),
            ],
          ),
        ),
      ),
    ),
  );
}
