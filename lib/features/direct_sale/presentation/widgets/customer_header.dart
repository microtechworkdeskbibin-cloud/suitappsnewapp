import 'package:flutter/material.dart';

class CustomerHeader extends StatelessWidget {
  const CustomerHeader({required this.name, super.key, this.subtitle});

  final String name;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(name),
        subtitle: subtitle == null ? null : Text(subtitle!),
      );
}
