import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CountryPicker extends StatelessWidget {
  final Nav nav;
  const CountryPicker(this.nav);
  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return BottomSheetShell(p: p, onClose: () => nav.close('country'), heightFactor: 0.62, child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Davlat kodi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: 14),
        Container(height: 40, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.centerLeft,
            child: Text('Qidirish', style: TextStyle(fontSize: 14, color: p.t5))),
        const SizedBox(height: 8),
        for (int i = 0; i < countries.length; i++) GestureDetector(
          onTap: () => nav.close('country'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(children: [
              Text(countries[i].flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(countries[i].name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: p.ink))),
              Text(countries[i].dial, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.t1)),
              if (i == 0) ...[const SizedBox(width: 8), Icon(Icons.check, size: 16, color: p.ink)],
            ]),
          ),
        ),
      ]),
    );
  }
}
