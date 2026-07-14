import 'package:flutter/material.dart';
import '../nav.dart';

class PushScreen extends StatelessWidget {
  final Nav nav;
  const PushScreen(this.nav);
  @override
  Widget build(BuildContext c) {
    return GestureDetector(
      onTap: () => nav.close('push'),
      child: Container(color: const Color(0xFF0A0A0C), child: SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 30),
          const Text('9:41', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w300, color: Colors.white)),
          const Text('Chorshanba, 14-iyul', style: TextStyle(fontSize: 15, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center, child: const Text('T', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Trust', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('hozir', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                ]),
                SizedBox(height: 4),
                Text('Akmal Karimov tasdiq so’radi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                SizedBox(height: 2),
                Text('+500 000 so’m · Mol savdosi uchun', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB))),
              ])),
            ]),
          ),
          const Spacer(),
          const Text('Yopish uchun bosing', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
          const SizedBox(height: 10),
        ]),
      ))),
    );
  }
}
