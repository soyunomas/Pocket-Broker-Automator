import 'package:flutter/material.dart';

class BrokerScreen extends StatelessWidget {
  const BrokerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'Broker Local',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Próximamente - Broker MQTT embebido\n(Requiere integración nativa con Moquette)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
