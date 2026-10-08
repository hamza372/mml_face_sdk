import 'dart:convert';

import 'package:mml_face_sdk/mml_face_sdk.dart';
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
    'MML_LICENSE_PUBLIC_KEY',
    defaultValue: 'vJZyhTYJIS4JWop8tIlY1Juyzpyv434M_BUQhgHzgDY',
  );
  static const activationUrl = String.fromEnvironment(
    'MML_ACTIVATION_URL',
    defaultValue:
        'https://mml-face-license.hamzaasif19974-69b.workers.dev/v1/activate',
  );
  static const demoActivationKey = String.fromEnvironment(
    'MML_DEMO_ACTIVATION_KEY',
  );
  final code = TextEditingController();
  final picker = ImagePicker();
  MmlFaceSdk? sdk;
  FaceTemplate? template;
  String status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    sdk = MmlFaceSdk(
      publicLicenseKey: SimplePublicKey(
        base64Url.decode(base64Url.normalize(publicKeyB64)),
        type: KeyPairType.ed25519,
      ),
    );
    final token = await storage.read(key: 'license');
    final saved = await storage.read(key: 'template');
    try {
      if (token != null) {
        await sdk!.initialize(license: token);
      } else if (demoActivationKey.isNotEmpty) {
        setState(() => status = 'Preparing on-device demo…');
        await _activateWithCode(demoActivationKey);
      }
      if (saved != null) template = FaceTemplate.fromJson(jsonDecode(saved));
      setState(
        () => status = token == null && demoActivationKey.isEmpty
            ? 'Activation required'
            : 'Ready',
      );
    } catch (_) {
      if (demoActivationKey.isNotEmpty) {
        try {
          await _activateWithCode(demoActivationKey);
          setState(() => status = 'Ready');
          return;
        } catch (_) {}
      }
      setState(() => status = 'Activation required');
    }
  }

  Future<String> _activateWithCode(String activationCode) async {
    final token = await sdk!.activate(
      endpoint: Uri.parse(activationUrl),
      activationCode: activationCode,
    );
    await storage.write(key: 'license', value: token);
    return token;
  }

  Future<void> _activate() async {
    try {
      await _activateWithCode(code.text.trim());
      setState(() => status = 'Lifetime licence activated');
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
    appBar: AppBar(title: const Text('MML Face SDK')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Text(status),
          const SizedBox(height: 20),
          if (demoActivationKey.isEmpty) ...[
            TextField(
              controller: code,
              decoration: const InputDecoration(
                labelText: 'Customer app licence key',
              ),
            ),
            FilledButton(onPressed: _activate, child: const Text('Activate')),
          ] else
            const Text(
              'Demo access is configured automatically. Face images and templates stay on this device.',
            ),
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
