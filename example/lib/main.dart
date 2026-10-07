import 'dart:convert';

import 'package:everif_face_sdk/everif_face_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const MaterialApp(home: Demo()));

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const publicKeyB64 = String.fromEnvironment(
    'EVERIF_LICENSE_PUBLIC_KEY',
  );
  static const activationUrl = String.fromEnvironment('EVERIF_ACTIVATION_URL');
  final code = TextEditingController();
  final picker = ImagePicker();
  EverifFaceSdk? sdk;
  FaceTemplate? template;
  String status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (publicKeyB64.isEmpty) {
      setState(() => status = 'Set EVERIF_LICENSE_PUBLIC_KEY.');
      return;
    }
    sdk = EverifFaceSdk(
      publicLicenseKey: SimplePublicKey(
        base64Url.decode(base64Url.normalize(publicKeyB64)),
        type: KeyPairType.ed25519,
      ),
    );
    final token = await storage.read(key: 'license');
    final saved = await storage.read(key: 'template');
    try {
      if (token != null) await sdk!.initialize(license: token);
      if (saved != null) template = FaceTemplate.fromJson(jsonDecode(saved));
      setState(() => status = token == null ? 'Activation required' : 'Ready');
    } catch (_) {
      setState(() => status = 'Activation required');
    }
  }

  Future<void> _activate() async {
    try {
      final token = await sdk!.activate(
        endpoint: Uri.parse(activationUrl),
        activationCode: code.text.trim(),
      );
      await storage.write(key: 'license', value: token);
      setState(() => status = 'Activated for seven days');
    } catch (_) {
      setState(() => status = 'Activation failed');
    }
  }

  Future<XFile?> _capture() => picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    imageQuality: 95,
  );
  Future<void> _enroll() async {
    final file = await _capture();
    if (file == null) return;
    try {
      template = await sdk!.createTemplate(await file.readAsBytes());
      await storage.write(key: 'template', value: jsonEncode(template));
      setState(() => status = 'Template enrolled locally');
    } on FaceSdkException catch (e) {
      setState(() => status = e.code.name);
    }
  }

  Future<void> _compare(bool live) async {
    if (template == null) {
      setState(() => status = 'Enroll first');
      return;
    }
    final file = await _capture();
    if (file == null) return;
    try {
      final r = live
          ? await sdk!.verify(
              encodedImage: await file.readAsBytes(),
              template: template!,
            )
          : await sdk!.recognize(
              encodedImage: await file.readAsBytes(),
              template: template!,
            );
      setState(
        () => status = live && r.livenessPassed != true
            ? 'Liveness needs 4 good frames/captures (${r.livenessScore?.toStringAsFixed(3) ?? '-'})'
            : '${r.matched ? 'MATCH' : 'NO MATCH'} similarity=${r.similarity?.toStringAsFixed(3)}',
      );
    } on FaceSdkException catch (e) {
      setState(() => status = e.code.name);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('eVerif Face SDK')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Text(status),
          const SizedBox(height: 20),
          TextField(
            controller: code,
            decoration: const InputDecoration(
              labelText: 'One-time activation code',
            ),
          ),
          FilledButton(onPressed: _activate, child: const Text('Activate')),
          const Divider(),
          FilledButton(
            onPressed: _enroll,
            child: const Text('Enroll / replace template'),
          ),
          OutlinedButton(
            onPressed: () => _compare(false),
            child: const Text('Recognition only'),
          ),
          OutlinedButton(
            onPressed: () => _compare(true),
            child: const Text('Liveness + verification'),
          ),
          const Text(
            'For liveness, capture four consecutive samples. Production apps should use a guided native frame stream.',
          ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    code.dispose();
    sdk?.dispose();
    super.dispose();
  }
}
