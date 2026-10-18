import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Stylised route map from the Visit day design (pickup → hospital).
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.origin,
    required this.originArea,
    required this.dest,
    required this.destArea,
    required this.semanticLabel,
  });

  final String origin;
  final String originArea;
  final String dest;
  final String destArea;
  final String semanticLabel;

  static const _svg = '<svg width="390" height="300" viewBox="0 0 390 300" xmlns="http://www.w3.org/2000/svg"> <rect width="390" height="300" fill="#F1F3F4"></rect> <path d="M0 0H140C120 40 150 70 120 110C95 140 40 130 0 150Z" fill="#CEEAD6"></path> <path d="M300 300C300 260 340 240 390 236V300Z" fill="#CEEAD6"></path> <path d="M210 210C230 196 262 200 270 220C278 242 252 262 228 256C206 250 196 224 210 210Z" fill="#AECBFA"></path> <g fill="#E8EAED"> <rect x="160" y="20" width="60" height="40" rx="3"></rect><rect x="236" y="20" width="44" height="40" rx="3"></rect> <rect x="160" y="120" width="44" height="50" rx="3"></rect><rect x="300" y="120" width="70" height="40" rx="3"></rect> <rect x="40" y="200" width="70" height="36" rx="3"></rect><rect x="130" y="230" width="50" height="40" rx="3"></rect> </g> <g fill="none" stroke-linecap="round"> <path d="M-10 186C80 176 150 120 230 100C290 86 340 90 400 70" stroke="#F9AB00" stroke-width="11"></path> <path d="M-10 186C80 176 150 120 230 100C290 86 340 90 400 70" stroke="#FDE293" stroke-width="8"></path> <path d="M150 -10V310M290 -10V310M-10 100H400M-10 270H400" stroke="#DADCE0" stroke-width="7"></path> <path d="M150 -10V310M290 -10V310M-10 100H400M-10 270H400" stroke="#FFFFFF" stroke-width="5"></path> <path d="M70 160V300M230 0V100M330 160V300" stroke="#FFFFFF" stroke-width="3.5"></path> </g> <g fill="none" stroke-linecap="round" stroke-linejoin="round"> <path d="M70 248V186C110 180 150 150 190 124C230 100 290 88 290 70V52" stroke="#1967D2" stroke-width="8"></path> <path d="M70 248V186C110 180 150 150 190 124C230 100 290 88 290 70V52" stroke="#4285F4" stroke-width="5.5"></path> </g> <circle cx="70" cy="248" r="11" fill="#FFFFFF"></circle> <circle cx="70" cy="248" r="7" fill="#1A73E8"></circle> <circle cx="190" cy="124" r="13" fill="#FFFFFF" stroke="#1A73E8" stroke-width="2"></circle> <path d="M183 127v-4l2-4h10l2 4v4zM185 127v2M195 127v2" stroke="#1A73E8" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-linejoin="round"></path> <path d="M290 14c-11 0-19 8-19 19 0 14 19 31 19 31s19-17 19-31c0-11-8-19-19-19z" fill="#EA4335"></path> <circle cx="290" cy="33" r="7" fill="#B31412"></circle> <g font-family="PlusJakartaSans" font-size="10" fill="#5F6368" font-weight="500"> <text x="20" y="40">{originArea}</text> <text x="300" y="134" font-size="9">{destArea}</text> <text x="236" y="84" font-size="9" fill="#3C4043" font-weight="700">{dest}</text> <text x="20" y="172" font-size="8.5" transform="rotate(-6 20 172)">Guthrie Corridor Expy</text> <text x="80" y="262" font-size="9" fill="#3C4043" font-weight="700">{origin}</text> </g> </svg>';

  @override
  Widget build(BuildContext context) {
    final svg = _svg
        .replaceAll('{origin}', _esc(origin))
        .replaceAll('{originArea}', _esc(originArea))
        .replaceAll('{dest}', _esc(dest))
        .replaceAll('{destArea}', _esc(destArea));
    return SvgPicture.string(svg, fit: BoxFit.cover, alignment: Alignment.topCenter, semanticsLabel: semanticLabel);
  }
}
