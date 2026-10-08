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
  bool ready = false;
  bool busy = true;

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
        setState(() {
          status = 'Preparing on-device demo…';
          busy = true;
        });
        await _activateWithCode(demoActivationKey);
      }
      if (saved != null) {
        try {
          template = FaceTemplate.fromJson(jsonDecode(saved));
        } catch (_) {
          await storage.delete(key: 'template');
        }
      }
      setState(() {
        ready = token != null || demoActivationKey.isNotEmpty;
        busy = false;
        status = ready
            ? template == null
                  ? 'Ready — enroll a face to begin'
                  : 'Ready — enrolled face loaded'
            : 'Activation required';
      });
    } catch (_) {
      if (demoActivationKey.isNotEmpty) {
        try {
          await _activateWithCode(demoActivationKey);
          setState(() {
            ready = true;
            busy = false;
            status = template == null
                ? 'Ready — enroll a face to begin'
                : 'Ready — enrolled face loaded';
          });
          return;
        } catch (_) {}
      }
      setState(() {
        ready = false;
        busy = false;
        status = 'Activation required';
      });
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
    if (busy) return;
    setState(() {
      busy = true;
      status = 'Activating licence and installing models…';
    });
    try {
      await _activateWithCode(code.text.trim());
      setState(() {
        ready = true;
        status = 'Licence activated — enroll a face to begin';
      });
    } catch (_) {
      setState(() => status = 'Activation failed');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<XFile?> _capture() => picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    imageQuality: 95,
  );
  Future<void> _enroll() async {
    if (!ready || busy) return;
    setState(() {
      busy = true;
      status = 'Capture a clear front-facing enrollment photo';
    });
    final file = await _capture();
    if (file == null) {
      setState(() {
        busy = false;
        status = template == null
            ? 'Enrollment cancelled — enroll a face to begin'
            : 'Enrollment cancelled — existing face kept';
      });
      return;
    }
    try {
      setState(() => status = 'Creating local face template…');
      final enrolled = await sdk!.createTemplate(await file.readAsBytes());
      await storage.write(key: 'template', value: jsonEncode(enrolled));
      setState(() {
        template = enrolled;
        status = 'Enrollment complete — recognition is ready';
      });
    } on FaceSdkException catch (e) {
      setState(() => status = 'Enrollment failed: ${_friendlyError(e.code)}');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _compare(bool live) async {
    if (!ready || busy || template == null) return;
    setState(() {
      busy = true;
      status = live ? 'Capture liveness sample' : 'Capture recognition photo';
    });
    final file = await _capture();
    if (file == null) {
      setState(() {
        busy = false;
        status = 'Capture cancelled — enrollment is still ready';
      });
      return;
    }
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
      setState(() => status = _friendlyError(e.code));
    } finally {
      setState(() => busy = false);
    }
  }

  String _friendlyError(FaceSdkError error) => switch (error) {
    FaceSdkError.noFace => 'No face detected. Try again in good light.',
    FaceSdkError.multipleFaces => 'Keep only one face in the frame.',
    FaceSdkError.faceTooSmall => 'Move closer to the camera.',
    FaceSdkError.faceNotFrontal => 'Look directly at the camera.',
    FaceSdkError.poorQuality => 'Image quality is too low. Try again.',
    FaceSdkError.licenseInvalid => 'The SDK is not ready yet.',
    _ => error.name,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MML Face SDK')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (busy) const SizedBox(height: 12),
          Text(status, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          if (demoActivationKey.isEmpty) ...[
            TextField(
              controller: code,
              decoration: const InputDecoration(
                labelText: 'Customer app licence key',
              ),
            ),
            FilledButton(
              onPressed: busy ? null : _activate,
              child: const Text('Activate'),
            ),
          ] else
            const Text(
              'Demo access is configured automatically. Face images and templates stay on this device.',
            ),
          const Divider(),
          Text(
            template == null
                ? 'Step 1 of 2 · No face enrolled'
                : 'Step 1 complete · Face enrolled on this device',
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: ready && !busy ? _enroll : null,
            child: Text(
              template == null ? '1. Enroll face' : 'Replace enrolled face',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Step 2 · Compare with the enrolled face'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: ready && !busy && template != null
                ? () => _compare(false)
                : null,
            child: const Text('2. Recognition only'),
          ),
          OutlinedButton(
            onPressed: ready && !busy && template != null
                ? () => _compare(true)
                : null,
            child: const Text('2. Liveness + verification'),
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
